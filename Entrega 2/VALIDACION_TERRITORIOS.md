# Validación de nombres de territorio

Fecha local: 3 de octubre de 2026 (America/Santiago).

Se ejecutó `ejecutar-etl.ps1 -SkipContainerStart` sobre AdventureWorks2022
hacia AdventureWorksDW. Ejecución 2: `SUCCEEDED`; validador: `VALIDATION_OK`.

La comparación antes/después confirmó:

- Ventas: 121.317 filas, importe 109.846.381,4250 y 274.914 unidades.
- Compras: 8.845 filas; importe, unidades recibidas y rechazadas iguales.
- Producción: 72.591 filas; cantidades, finalización y atrasos iguales.
- Inventario: 1.069 filas y 335.974 unidades; la fecha de corte se actualizó
  por la recarga completa habitual.
- Rutas: 67.131 filas; horas y costos iguales.
- Las 15 vistas conservan sus cantidades de filas, nombres y tipos de columnas.
  Los totales de Ventas de las vistas que exponen ese campo coinciden.
- No hay nombres de territorio nulos ni vacíos en las siete vistas afectadas.

La fuente actual no tiene territorios sin nombre ni clientes sin territorio;
las etiquetas de respaldo quedan disponibles para esos casos en futuras cargas.
La comparación no constituye una prueba visual ni una actualización del PBIX.
Para ver la base actualizada, usar Actualizar en Power BI Desktop y revisar
los filtros que dependan de valores en blanco.

Capturas de comparación: `../tmp/validacion-territorios/antes.txt` y
`../tmp/validacion-territorios/despues.txt`.

## Extensión a la geografía de clientes

La captura de Power BI mostraba blancos en `CountryName`, no en territorio.
Se extendió la limpieza a país, región y ciudad en `DimCustomer`.
La ejecución 3 terminó con `SUCCEEDED` y `VALIDATION_OK`.

La comparación `antes-geografia.txt` / `despues-geografia.txt` confirmó los
mismos totales, cantidades de filas y columnas/tipos de las 15 vistas.
Los 635 clientes cuyo país era NULL ahora aparecen bajo `Sin país`, conservando
ventas de 80.487.704,2043. No quedan etiquetas geográficas vacías o nulas en
`rpt.C04_GeografiaClientes`. No se modificó ni actualizó el PBIX.
