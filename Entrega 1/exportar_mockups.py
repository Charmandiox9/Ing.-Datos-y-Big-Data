"""
exportar_mockups.py
===================
Script de automatización para convertir mockups HTML locales de Power BI
en imágenes PNG de alta resolución listas para documentos en LaTeX.

Requisitos:
    pip install playwright
    (En Windows se conecta automáticamente con Microsoft Edge preinstalado,
     o con Chromium si se ejecuta 'playwright install chromium').

Uso:
    python exportar_mockups.py
    python exportar_mockups.py --scale 2 --output-dir ./img
"""

import argparse
import os
import pathlib
import sys
import time
from playwright.sync_api import sync_playwright, Error as PlaywrightError

# Subcarpetas esperadas
PERSPECTIVAS = ["clientes", "produccion", "ventas"]

def get_browser(p):
    """
    Intenta lanzar el navegador más conveniente disponible:
    1. Microsoft Edge (canal nativo en Windows, sin descargas adicionales).
    2. Google Chrome (si está instalado).
    3. Chromium empaquetado por Playwright.
    """
    channels = ["msedge", "chrome", None]
    last_err = None
    for channel in channels:
        try:
            if channel:
                return p.chromium.launch(channel=channel, headless=True)
            else:
                return p.chromium.launch(headless=True)
        except Exception as e:
            last_err = e
            continue
    raise RuntimeError(f"No se pudo iniciar ningún navegador compatible con Playwright: {last_err}")

def export_mockups_to_png(
    mockups_dir: pathlib.Path,
    output_dir: pathlib.Path,
    viewport_width: int = 1920,
    viewport_height: int = 1080,
    scale: int = 2,
    workspace_only: bool = False
):
    """
    Recorre las subcarpetas de mockups y genera las capturas de pantalla PNG.
    """
    mockups_dir = mockups_dir.resolve()
    output_dir = output_dir.resolve()

    if not mockups_dir.exists():
        print(f"[ERROR] El directorio de mockups no existe: {mockups_dir}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print(" AUTOMATIZACIÓN DE CAPTURAS DE MOCKUPS A PNG (ALTA CALIDAD)")
    print("=" * 70)
    print(f"Directorio origen : {mockups_dir}")
    print(f"Directorio salida : {output_dir}")
    print(f"Viewport base     : {viewport_width}x{viewport_height} px")
    print(f"Factor de escala  : {scale}x (Resolución efectiva: {viewport_width * scale}px de ancho)")
    print(f"Modo de captura   : {'Solo Workspace (.workspace)' if workspace_only else 'Página completa'}")
    print("-" * 70)

    # Recopilar todos los archivos HTML en las subcarpetas
    html_tasks = []
    for perspectiva in PERSPECTIVAS:
        subfolder = mockups_dir / perspectiva
        if not subfolder.is_dir():
            print(f"[AVISO] Subcarpeta no encontrada: {subfolder}")
            continue
        files = sorted(subfolder.glob("*.html"))
        for file in files:
            html_tasks.append((perspectiva, file))

    if not html_tasks:
        print("[ERROR] No se encontraron archivos .html en las subcarpetas especificadas.")
        sys.exit(1)

    print(f"Se encontraron {len(html_tasks)} mockups para procesar.\n")

    start_total = time.time()
    generated_files = []

    with sync_playwright() as p:
        print("[1/3] Iniciando motor de renderizado de navegador...")
        browser = get_browser(p)
        
        # Crear contexto con viewport de escritorio y escala de alta densidad (DPI)
        context = browser.new_context(
            viewport={"width": viewport_width, "height": viewport_height},
            device_scale_factor=scale
        )
        page = context.new_page()

        print("[2/3] Procesando y renderizando mockups...\n")

        for idx, (perspectiva, html_path) in enumerate(html_tasks, 1):
            file_stem = html_path.stem
            out_filename = f"mockup_{perspectiva}_{file_stem}.png"
            out_path = output_dir / out_filename

            file_url = html_path.as_uri()
            t0 = time.time()

            try:
                # 1. Navegar al archivo local esperando a que la red esté inactiva
                page.goto(file_url, wait_until="networkidle")

                # 2. Asegurar que las fuentes tipográficas terminen de renderizar
                page.evaluate("() => document.fonts.ready")

                # 3. Inyectar corrección CSS para evitar cortes visuales en la barra lateral fija
                # durante la captura de página completa
                page.add_style_tag(content="""
                    .sidebar {
                        height: 100% !important;
                        min-height: 100% !important;
                    }
                    /* Ocultar el 'Contrato de implementación' (ficha técnica) y la navegación web */
                    .powerbi-spec, .page-nav {
                        display: none !important;
                    }
                    html, body {
                        scroll-behavior: auto !important;
                    }
                """)

                # Breve pausa para asegurar estabilidad de microanimaciones CSS
                page.wait_for_timeout(200)

                # 4. Captura de pantalla
                if workspace_only:
                    workspace_elem = page.locator(".workspace")
                    if workspace_elem.count() > 0:
                        workspace_elem.screenshot(path=str(out_path))
                    else:
                        page.screenshot(path=str(out_path), full_page=True)
                else:
                    page.screenshot(path=str(out_path), full_page=True)

                elapsed = time.time() - t0
                size_kb = out_path.stat().st_size / 1024
                print(f"  [{idx:02d}/{len(html_tasks):02d}] {perspectiva.upper():<10} -> {out_filename} ({size_kb:.1f} KB, {elapsed:.2f}s)")
                generated_files.append((perspectiva, out_filename, out_path))

            except PlaywrightError as pe:
                print(f"  [ERROR] Falló al capturar {html_path.name}: {pe}")

        browser.close()

    total_time = time.time() - start_total
    print("\n" + "-" * 70)
    print(f"[3/3] ¡Completado exitosamente!")
    print(f"Total imágenes generadas: {len(generated_files)} / {len(html_tasks)}")
    print(f"Tiempo total empleado   : {total_time:.2f} segundos")
    print(f"Ubicación de salida     : {output_dir}")
    print("=" * 70)

    # Imprimir sugerencia de código LaTeX listo para copiar y pegar
    print("\n" + "=" * 70)
    print(" EJEMPLO DE CÓDIGO LATEX LISTO PARA COPIAR Y PEGAR")
    print("=" * 70)
    print(r"""
% Configuración recomendada en el preámbulo:
% \usepackage{graphicx}
% \usepackage{float}

% Ejemplo de inserción de figura en LaTeX:
\begin{figure}[H]
    \centering
    \includegraphics[width=0.95\textwidth]{img/""" + (generated_files[0][1] if generated_files else "mockup.png") + r"""}
    \caption{Boceto de reporte Power BI: """ + (generated_files[0][0].capitalize() if generated_files else "Vista") + r"""}
    \label{fig:""" + (generated_files[0][1].replace('.png', '') if generated_files else "mockup") + r"""}
\end{figure}
""")

def main():
    parser = argparse.ArgumentParser(
        description="Convierte mockups HTML en imágenes PNG de alta resolución para LaTeX."
    )
    base_dir = pathlib.Path(__file__).resolve().parent
    default_mockups = base_dir / "mockups"
    default_output = base_dir / "img"

    parser.add_argument(
        "--mockups-dir",
        type=pathlib.Path,
        default=default_mockups,
        help="Ruta al directorio 'mockups' que contiene 'clientes', 'produccion' y 'ventas'."
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=default_output,
        help="Ruta a la carpeta donde se guardarán las imágenes PNG (por defecto: ./img)."
    )
    parser.add_argument(
        "--scale",
        type=int,
        default=2,
        help="Factor de escala para DPI alto / calidad Retina (por defecto: 2 para LaTeX nítido)."
    )
    parser.add_argument(
        "--width",
        type=int,
        default=1920,
        help="Ancho del viewport de escritorio (por defecto: 1920)."
    )
    parser.add_argument(
        "--height",
        type=int,
        default=1080,
        help="Alto del viewport de escritorio (por defecto: 1080)."
    )
    parser.add_argument(
        "--workspace-only",
        action="store_true",
        help="Capturar únicamente el panel de contenido (.workspace) omitiendo el sidebar."
    )

    args = parser.parse_args()
    export_mockups_to_png(
        mockups_dir=args.mockups_dir,
        output_dir=args.output_dir,
        viewport_width=args.width,
        viewport_height=args.height,
        scale=args.scale,
        workspace_only=args.workspace_only
    )

if __name__ == "__main__":
    main()
