# Mapeo de mockups a Power BI

## Propósito

Los mockups HTML son bocetos de la capa de presentación. Este documento define el contrato mínimo para reproducir cada página en Power BI conectado a `AdventureWorks2022`.

Los números visibles en los mockups son referenciales. En Power BI deben reemplazarse por medidas calculadas desde las tablas indicadas.

## Equivalencias visuales

| Elemento del mockup | Implementación en Power BI |
|---|---|
| Tarjeta KPI | Visual **Card** con una medida DAX |
| Gráfico de barras | **Clustered bar chart** o **Clustered column chart** |
| Gráfico de línea | **Line chart** |
| Dona | **Donut chart** |
| Tabla de apoyo | **Table** o **Matrix** |
| Filtro | **Slicer** |
| Ruta categoría → producto | Jerarquía con **Drill Down** |
| Valores referenciales | Se reemplazan por medidas conectadas al modelo |

## Medidas base sugeridas

Adaptar los nombres de tabla al nombre que Power BI muestre después de importar los esquemas.

### Ventas

```DAX
Ventas Totales =
SUM ( 'SalesOrderDetail'[LineTotal] )

Órdenes =
DISTINCTCOUNT ( 'SalesOrderHeader'[SalesOrderID] )

Unidades Vendidas =
SUM ( 'SalesOrderDetail'[OrderQty] )

Ticket Promedio =
DIVIDE ( [Ventas Totales], [Órdenes] )

Descuento Total =
SUMX (
    'SalesOrderDetail',
    'SalesOrderDetail'[UnitPrice]
        * 'SalesOrderDetail'[OrderQty]
        * 'SalesOrderDetail'[UnitPriceDiscount]
)
```

### Clientes

```DAX
Clientes Totales =
DISTINCTCOUNT ( 'Customer'[CustomerID] )

Clientes Recurrentes =
COUNTROWS (
    FILTER (
        VALUES ( 'Customer'[CustomerID] ),
        [Órdenes] > 1
    )
)

Clientes Una Compra =
COUNTROWS (
    FILTER (
        VALUES ( 'Customer'[CustomerID] ),
        [Órdenes] = 1
    )
)

Ventas por Cliente =
[Ventas Totales]
```

### Producción

```DAX
Órdenes OT =
COUNTROWS ( 'WorkOrder' )

Unidades a Producir =
SUM ( 'WorkOrder'[OrderQty] )

Unidades Rechazadas =
SUM ( 'WorkOrder'[ScrappedQty] )

Tasa de Rechazo =
DIVIDE ( [Unidades Rechazadas], [Unidades a Producir] )

Stock Actual =
SUM ( 'ProductInventory'[Quantity] )

Horas Planificadas =
SUM ( 'WorkOrderRouting'[PlannedResourceHrs] )

Horas Reales =
SUM ( 'WorkOrderRouting'[ActualResourceHrs] )

Costo Real =
SUM ( 'WorkOrderRouting'[ActualCost] )

Monto Comprado =
SUM ( 'PurchaseOrderDetail'[LineTotal] )
```

### Calendario

Crear una tabla calendario para que los filtros de fecha y las tendencias mensuales tengan una dimensión común:

```DAX
Calendario =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2011, 1, 1 ), DATE ( 2014, 12, 31 ) ),
    "Año", YEAR ( [Date] ),
    "Mes", FORMAT ( [Date], "MMM" ),
    "NúmeroMes", MONTH ( [Date] ),
    "Trimestre", "T" & FORMAT ( [Date], "Q" )
)
```

Ordenar `Calendario[Mes]` por `Calendario[NúmeroMes]` y usar `Calendario[Año] → Calendario[Trimestre] → Calendario[Mes]` como jerarquía temporal.

## Relaciones principales del modelo

Crear o validar estas relaciones después de importar las tablas:

| Tabla origen | Cardinalidad | Tabla destino |
|---|---|---|
| `SalesOrderHeader[SalesOrderID]` | 1 a muchos | `SalesOrderDetail[SalesOrderID]` |
| `Customer[CustomerID]` | 1 a muchos | `SalesOrderHeader[CustomerID]` |
| `Product[ProductID]` | 1 a muchos | `SalesOrderDetail[ProductID]` |
| `Product[ProductID]` | 1 a muchos | `WorkOrder[ProductID]` |
| `Product[ProductID]` | 1 a muchos | `ProductInventory[ProductID]` |
| `Product[ProductID]` | 1 a muchos | `PurchaseOrderDetail[ProductID]` |
| `ProductCategory[ProductCategoryID]` | 1 a muchos | `ProductSubcategory[ProductCategoryID]` |
| `ProductSubcategory[ProductSubcategoryID]` | 1 a muchos | `Product[ProductSubcategoryID]` |
| `SalesTerritory[TerritoryID]` | 1 a muchos | `Customer[TerritoryID]` |
| `SalesTerritory[TerritoryID]` | 1 a muchos | `SalesOrderHeader[TerritoryID]` |
| `WorkOrder[WorkOrderID]` | 1 a muchos | `WorkOrderRouting[WorkOrderID]` |
| `PurchaseOrderHeader[PurchaseOrderID]` | 1 a muchos | `PurchaseOrderDetail[PurchaseOrderID]` |
| `Vendor[BusinessEntityID]` | 1 a muchos | `PurchaseOrderHeader[VendorID]` |
| `Calendario[Date]` | 1 a muchos | `SalesOrderHeader[OrderDate]` |
| `Calendario[Date]` | 1 a muchos | `WorkOrder[StartDate]` |
| `Calendario[Date]` | 1 a muchos | `PurchaseOrderHeader[OrderDate]` |

## Contrato de las 15 páginas

| Código | Visual principal | Medidas clave | Dimensiones | Drill Down |
|---|---|---|---|---|
| C01 | Dona + barras | Clientes Totales, Clientes por Tipo, % Clientes | CustomerType, Territory | Territorio → país → estado |
| C02 | Top N + tabla | Ventas Totales, Órdenes, Ticket Promedio | Cliente, Territorio, Año | Cliente → orden → detalle |
| C03 | Heatmap + columnas | Clientes Recurrentes, Clientes Una Compra, Órdenes Promedio | Cliente, Mes, Territorio | Año → mes |
| C04 | Barras + mapa | Clientes, Órdenes, Ventas Totales | Territorio, país, estado | Territorio → país → estado → ciudad |
| C05 | Línea + tabla | Clientes Sin Orden, Última Compra, Días Inactividad | Cliente, Fecha de orden, Territorio | Territorio → cliente |
| P01 | Barras + dona | Órdenes OT, Unidades a Producir, Tasa Rechazo | Categoría, subcategoría, producto | Categoría → subcategoría → producto |
| P02 | Matrix heatmap | Stock Actual, Productos con Stock | Ubicación, producto, categoría | Ubicación → producto |
| P03 | Línea + dona | OT Terminadas, OT Atrasadas, % Cumplimiento | Fecha, producto, estado derivado | Año → mes |
| P04 | Columnas agrupadas | Horas Planificadas, Horas Reales, Desviación | Ubicación, operación, OT | Ubicación → operación → OT |
| P05 | Línea + dona | Órdenes Compra, Monto Comprado, Proveedores Activos | Proveedor, producto, fecha | Proveedor → orden → producto |
| V01 | Línea + dona | Ventas Totales, Órdenes, Unidades Vendidas | Fecha, categoría, territorio | Año → trimestre → mes |
| V02 | Barras + mapa | Ventas Totales, Órdenes, Variación | Grupo, territorio, país, estado | Grupo → territorio → país/estado |
| V03 | Top N + treemap | Ventas, Unidades, Precio Promedio, Descuento | Categoría, subcategoría, producto | Categoría → subcategoría → producto |
| V04 | Dona + columnas | Ventas Online, Ventas Distribuidor, % Canal | OnlineOrderFlag, fecha, territorio | Año → mes → canal |
| V05 | Ranking + línea | Ventas por Vendedor, Clientes Atendidos, Variación | Vendedor, territorio, fecha | Vendedor → cliente → orden |

## Regla para cada página

Cada página Power BI debe conservar:

1. El título y objetivo del mockup.
2. Las cuatro tarjetas KPI principales.
3. El visual principal equivalente.
4. La tabla de detalle.
5. Los filtros indicados.
6. La jerarquía de Drill Down cuando esté definida.
7. Una nota de período y fuente de datos.

## Validación de replicabilidad

Antes de entregar el informe final:

- Cada KPI debe ser una medida, no un número escrito manualmente.
- Cada gráfico debe usar campos reales del modelo.
- Los filtros deben actuar sobre los mismos campos definidos en el mockup.
- Las tablas fuente deben existir en `AdventureWorks2022`.
- Las jerarquías deben probarse con Drill Down.
- Los datos referenciales deben desaparecer de la versión final.
