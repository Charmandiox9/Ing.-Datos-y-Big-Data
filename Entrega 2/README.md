# Entrega 2 · ETL y almacén analítico

## Qué se entrega

- Un ejecutor PowerShell: [ejecutar-etl.ps1](ejecutar-etl.ps1).
- Scripts SQL de creación, carga, vistas y validación en [sql/](sql/).
- Un Data Warehouse independiente: `AdventureWorksDW`.
- Cinco tablas de hechos, siete dimensiones y 15 vistas `rpt`.
- El [diseño final de reportes](Diseno_Final_Reportes.md), las [medidas DAX](powerbi-medidas.dax) y un [tema de Power BI](powerbi-tema.json) de referencia.
- La [evidencia de validación](VALIDACION.md) de la ejecución sobre el respaldo del proyecto.

La carga se probó con `AdventureWorks2022` restaurada desde el respaldo del proyecto. También acepta otra base en **la misma instancia SQL Server** si conserva las tablas y columnas AdventureWorks utilizadas por los scripts. No adapta automáticamente esquemas con nombres diferentes.

## Orden de ejecución

1. Iniciar Docker Desktop.
2. Levantar SQL Server con `docker compose up -d`.
3. Restaurar la base fuente. Para la base incluida, ejecutar `.\restaurar-adventureworks.ps1` desde la raíz.
4. Ejecutar el ETL desde la raíz:

```powershell
& '.\Entrega 2\ejecutar-etl.ps1'
```

Para una fuente compatible llamada, por ejemplo, `AdventureWorks2019`:

```powershell
& '.\Entrega 2\ejecutar-etl.ps1' -SourceDb AdventureWorks2019
```

Para cambiar el nombre del almacén:

```powershell
& '.\Entrega 2\ejecutar-etl.ps1' -SourceDb AdventureWorks2019 -TargetDb AdventureWorksDW2019
```

El ejecutor usa la contraseña `MSSQL_SA_PASSWORD` del entorno si existe; en caso contrario utiliza la contraseña de demostración del `docker-compose.yml`. También admite `-Password`.

## Qué hace la carga

1. Crea la base destino si no existe.
2. Crea dimensiones y hechos si faltan.
3. Comprueba la existencia de la fuente y sus tablas principales.
4. Recarga todas las dimensiones y hechos **dentro de una transacción**.
5. Registra inicio, éxito o error en `dw.EtlRun`.
6. Crea o actualiza las 15 vistas de reportabilidad.
7. Compara las cantidades de filas y el importe total de ventas entre fuente y almacén.

La carga es **completa**: al ejecutarla de nuevo, reemplaza el contenido de las tablas `dw` del destino seleccionado. El ETL no modifica las tablas de la base fuente. Si falla la carga, SQL Server revierte la transacción y conserva la carga anterior. Los historiales de `dw.EtlRun` permanecen.

El inventario se carga como una **foto del estado actual**, con fecha UTC de ejecución. Cada recarga reemplaza la foto anterior; no existe historia de inventario en la fuente usada.

## Modelo analítico

| Capa | Tablas | Grano |
|---|---|---|
| Dimensiones | `DimDate`, `DimTerritory`, `DimCustomer`, `DimProduct`, `DimLocation`, `DimVendor`, `DimSalesPerson` | Una fila por entidad o fecha |
| Ventas | `FactSales` | Una línea de pedido de venta |
| Producción | `FactWorkOrder` | Una orden de trabajo |
| Inventario | `FactInventory` | Producto, ubicación, estante y bin en la fecha de corte |
| Rutas | `FactRouting` | Una operación de una orden de trabajo |
| Compras | `FactPurchase` | Una línea de pedido de compra |

El importe de ventas corresponde a `SalesOrderDetail.LineTotal`. Así se evita duplicar los totales de la cabecera al analizar productos. Las horas planificadas en rutas se derivan de `ScheduledStartDate` y `ScheduledEndDate`; las horas reales vienen de `ActualResourceHrs`.

## Verificación en SSMS

Conectarse a `localhost,1433` con usuario `sa` y abrir `AdventureWorksDW`. Ejecutar:

```sql
USE AdventureWorksDW;

SELECT TOP (5) RunId, SourceDatabase, Status, StartedAt, FinishedAt
FROM dw.EtlRun
ORDER BY RunId DESC;

SELECT COUNT(*) AS VistasReportabilidad
FROM sys.views
WHERE schema_id = SCHEMA_ID(N'rpt');

SELECT TOP (10) * FROM rpt.V01_ResumenVentas ORDER BY YearMonth;
SELECT TOP (10) * FROM rpt.P02_InventarioUbicacion;
```

La ejecución validada sobre el respaldo del proyecto produjo:

| Hecho | Filas |
|---|---:|
| Ventas | 121.317 |
| Órdenes de trabajo | 72.591 |
| Inventario | 1.069 |
| Rutas | 67.131 |
| Compras | 8.845 |
| Vistas `rpt` | 15 |

## Conexión desde Power BI Desktop

1. **Obtener datos → SQL Server**.
2. Servidor: `localhost,1433`. Base: `AdventureWorksDW`.
3. Elegir **Import**.
4. Autenticación: **Base de datos**, usuario `sa` y la contraseña configurada.
5. Si aparece una advertencia de certificado del servidor local, configurar la confianza del certificado para esta conexión.
6. Importar las vistas `rpt` de los reportes que se quieran construir. Para Drill Down a nivel de pedido, importar también las tablas `dw` relevantes y crear sus relaciones.
7. Usar [Diseno_Final_Reportes.md](Diseno_Final_Reportes.md) para asignar ejes, valores y filtros. Las medidas reutilizables están en [powerbi-medidas.dax](powerbi-medidas.dax).

Para conservar la paleta de los mockups: **Vista → Temas → Examinar temas** y seleccionar [powerbi-tema.json](powerbi-tema.json). Los gráficos se crean con visuales nativos de Power BI; el HTML no se importa como reporte.

Las vistas son útiles para construir los gráficos rápidamente. Las tablas `dw` conservan el detalle necesario para jerarquías y medidas como `DISTINCTCOUNT`. No sumar recuentos de órdenes de varias categorías/productos: un mismo pedido puede aparecer en más de un grupo.

## Archivos SQL

| Archivo | Propósito |
|---|---|
| `00_create_database.sql` | Crea el almacén si falta |
| `01_schema.sql` | Crea dimensiones, hechos e índices |
| `02_load.sql` | ETL transaccional desde la fuente |
| `03_reporting_views.sql` | 15 vistas para clientes, producción y ventas |
| `04_validate.sql` | Reconciliación automática |
