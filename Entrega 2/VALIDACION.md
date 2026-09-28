# Evidencia de validación · Entrega 2

Fecha de ejecución: 28 de septiembre de 2026 (UTC). Instancia: SQL Server 2022 Developer en Docker.

- Fuente: `AdventureWorks2022`.
- Almacén: `AdventureWorksDW`.
- Estado en `dw.EtlRun`: `SUCCEEDED`.
- Resultado de `04_validate.sql`: `VALIDATION_OK`.

| Control | Resultado |
|---|---:|
| Filas de ventas | 121.317 |
| Órdenes de trabajo | 72.591 |
| Posiciones de inventario | 1.069 |
| Operaciones de ruta | 67.131 |
| Líneas de compra | 8.845 |
| Vistas `rpt` | 15 |

El validador comparó las filas de hechos con las tablas de la fuente, el importe total de `SalesOrderDetail.LineTotal` con `FactSales.SalesAmount`, las dimensiones de clientes y productos, y las claves de dimensiones usadas por los hechos.

También se consultó cada una de las 15 vistas `rpt`. Todas devolvieron filas:

| Vista | Filas |
|---|---:|
| C01_PerfilClientes | 20 |
| C02_VentasPorCliente | 19.820 |
| C03_FrecuenciaClientes | 19.820 |
| C04_GeografiaClientes | 597 |
| C05_ClientesInactivos | 19.820 |
| P01_ProduccionProducto | 4.975 |
| P02_InventarioUbicacion | 1.069 |
| P03_CumplimientoOT | 72.591 |
| P04_EficienciaRutas | 67.131 |
| P05_Abastecimiento | 5.149 |
| V01_ResumenVentas | 38 |
| V02_VentasTerritorio | 364 |
| V03_VentasProducto | 610 |
| V04_VentasCanal | 72 |
| V05_DesempenoVendedores | 635 |

La prueba se hizo con el respaldo incluido en el proyecto. Para otras bases compatibles, el ejecutor acepta `-SourceDb`; cada fuente adicional debe ejecutarse y validarse por separado.
