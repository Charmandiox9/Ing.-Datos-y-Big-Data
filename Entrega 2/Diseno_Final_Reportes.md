# Diseño final de los 15 reportes

Esta versión conecta los mockups de Entrega 1 con las vistas reales del almacén `AdventureWorksDW`. Las tarjetas y gráficos HTML siguen siendo bocetos con valores referenciales; en Power BI se reemplazan por los campos indicados aquí.

## Reglas comunes

- Fecha de ventas: `dw.DimDate` relacionada con `dw.FactSales[OrderDateKey]`. En vistas se usa `CalendarYear` y `YearMonth`.
- Para recuentos de pedidos globales, utilizar `DISTINCTCOUNT(FactSales[SalesOrderId])`. El recuento de una vista por producto/territorio describe el grupo y no siempre puede sumarse entre grupos.
- El importe comercial es la suma de `FactSales[SalesAmount]`, derivada de `SalesOrderDetail.LineTotal`.
- En inventario, mostrar la fecha de corte `FechaCorte`. La fuente solo proporciona estado actual.
- Para producción, `PlannedHours` es la duración programada; `ActualHours` son horas de recurso reales.
- Las vistas `rpt` alimentan rápidamente los gráficos. Para Drill Down hasta orden o línea, usar la tabla `dw` de detalle correspondiente.

## Clientes

| Código | Vista SQL | Visual Power BI | Eje / leyenda | Valor | Filtros | Drill Down factible |
|---|---|---|---|---|---|---|
| C01 Perfil | `rpt.C01_PerfilClientes` | Dona + barras | `CustomerType`; `TerritoryName` | `Clientes` | Tipo, territorio | Tipo → territorio |
| C02 Ventas por cliente | `rpt.C02_VentasPorCliente` | Barras Top N + tabla | `CustomerName` | `Ventas`, `Ordenes`, `TicketPromedio` | Territorio, tipo | Cliente → pedidos con `FactSales` |
| C03 Frecuencia | `rpt.C03_FrecuenciaClientes` | Columnas + matriz | `Segmento`, `TerritoryName` | Recuento de `CustomerKey` | Segmento, territorio | Territorio → cliente |
| C04 Geografía | `rpt.C04_GeografiaClientes` | Mapa o barras + matriz | `CountryName`, `StateProvinceName`, `City` | `Clientes`, `Ventas` | País, territorio | País → estado → ciudad |
| C05 Inactividad | `rpt.C05_ClientesInactivos` | Barras + tabla | `EstadoActividad` | Recuento de `CustomerKey` | Estado, territorio, `DiasSinCompra` | Territorio → cliente |

**C05:** la inactividad se calcula respecto de la **última fecha de venta presente en la fuente**, no respecto del día actual. Así los datos históricos 2011–2014 se interpretan correctamente.

## Procesos / producción

| Código | Vista SQL | Visual Power BI | Eje / leyenda | Valor | Filtros | Drill Down factible |
|---|---|---|---|---|---|---|
| P01 Producción | `rpt.P01_ProduccionProducto` | Barras + línea | `CategoryName` → `SubcategoryName` → `ProductName`; año/mes | `UnidadesOrdenadas`, `UnidadesRechazadas`, `TasaRechazo` | Fecha, categoría | Categoría → subcategoría → producto |
| P02 Inventario | `rpt.P02_InventarioUbicacion` | Matriz con formato condicional | `LocationName` × `CategoryName` | `Unidades` | Fecha de corte, ubicación, categoría | Ubicación → producto |
| P03 Cumplimiento | `rpt.P03_CumplimientoOT` | Dona + línea | `Estado`, `FechaInicio` | Recuento de `WorkOrderId`, `DiasEjecucion` | Fecha, estado, producto | Año → mes → orden |
| P04 Rutas | `rpt.P04_EficienciaRutas` | Columnas agrupadas + tabla | `LocationName`, `OperationSequence` | `PlannedHours` vs. `ActualHours`; `PlannedCost` vs. `ActualCost` | Ubicación, operación | Ubicación → operación → orden |
| P05 Abastecimiento | `rpt.P05_Abastecimiento` | Línea + barras | Año/mes; `VendorName` | `MontoComprado`, `UnidadesOrdenadas` | Fecha, proveedor, categoría | Proveedor → producto |

**P02:** el origen no tiene movimientos históricos de inventario. La matriz cruza ubicación y categoría en una sola fecha; no muestra tendencia mensual.

## Ventas

| Código | Vista SQL | Visual Power BI | Eje / leyenda | Valor | Filtros | Drill Down factible |
|---|---|---|---|---|---|---|
| V01 Resumen | `rpt.V01_ResumenVentas` | Línea + tarjetas | `YearMonth` | `Ventas`, `Ordenes`, `Unidades`, `TicketPromedio` | Año, mes | Año → trimestre → mes |
| V02 Territorio | `rpt.V02_VentasTerritorio` | Barras + mapa | `TerritoryGroup` → `TerritoryName` | `Ventas`, `Ordenes`, `Unidades` | Año, grupo | Grupo → territorio |
| V03 Producto | `rpt.V03_VentasProducto` | Barras Top N + treemap | `CategoryName` → `SubcategoryName` → `ProductName` | `Ventas`, `Unidades`, `Descuento` | Año, categoría, producto | Categoría → subcategoría → producto |
| V04 Canal | `rpt.V04_VentasCanal` | Dona + columnas | `Canal`; `YearMonth` | `Ventas`, `Ordenes`, `TicketPromedio` | Año, canal | Año → mes → canal |
| V05 Vendedores | `rpt.V05_DesempenoVendedores` | Barras ranking + línea | `SalesPersonName`; `YearMonth` | `Ventas`, `Ordenes`, `ClientesAtendidos` | Año, vendedor, territorio | Vendedor → cliente y orden con `FactSales` |

## Cómo armar una página en Power BI

1. Importar la vista indicada.
2. Añadir los segmentadores de la columna «Filtros».
3. Crear tarjetas con los valores principales.
4. Crear el visual principal con el eje y valor de la tabla.
5. Añadir una tabla o matriz con los campos de detalle.
6. Si se necesita Drill Down al nivel de una orden, importar además las dimensiones y hechos `dw` relevantes, crear relaciones por claves y usar sus campos granulares.
7. Revisar que los valores cambien al filtrar y que las cifras globales concilien con `04_validate.sql`.

Los 15 mockups están en [Entrega 1/mockups](../Entrega%201/mockups/index.html). Las medidas DAX reutilizables están en [powerbi-medidas.dax](powerbi-medidas.dax).

