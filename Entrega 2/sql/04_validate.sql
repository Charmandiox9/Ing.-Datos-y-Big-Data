USE [$(TargetDb)];
GO
SET NOCOUNT ON;

-- Revisa que la ultima ejecucion haya terminado bien
IF NOT EXISTS (
    SELECT 1 FROM dw.EtlRun
    WHERE RunId = (SELECT MAX(RunId) FROM dw.EtlRun)
      AND Status = 'SUCCEEDED'
)
    THROW 52000, 'La última ejecución ETL no terminó correctamente.', 1;

-- Compara cantidad de filas en tablas de hechos
IF (SELECT COUNT_BIG(*) FROM dw.FactSales)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Sales.SalesOrderDetail)
    THROW 52001, 'Diferencia de filas en ventas.', 1;

IF (SELECT COUNT_BIG(*) FROM dw.FactWorkOrder)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Production.WorkOrder)
    THROW 52002, 'Diferencia de filas en órdenes de trabajo.', 1;

IF (SELECT COUNT_BIG(*) FROM dw.FactInventory)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Production.ProductInventory)
    THROW 52003, 'Diferencia de filas en inventario.', 1;

IF (SELECT COUNT_BIG(*) FROM dw.FactRouting)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Production.WorkOrderRouting)
    THROW 52004, 'Diferencia de filas en rutas de producción.', 1;

IF (SELECT COUNT_BIG(*) FROM dw.FactPurchase)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Purchasing.PurchaseOrderDetail)
    THROW 52005, 'Diferencia de filas en compras.', 1;

-- Compara cantidad de filas en dimensiones (sin contar la fila por defecto -1)
IF (SELECT COUNT_BIG(*) FROM dw.DimCustomer WHERE CustomerKey <> -1)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Sales.Customer)
    THROW 52006, 'Diferencia de filas en clientes.', 1;

IF (SELECT COUNT_BIG(*) FROM dw.DimProduct WHERE ProductKey <> -1)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Production.Product)
    THROW 52007, 'Diferencia de filas en productos.', 1;

IF (SELECT COUNT_BIG(*) FROM dw.DimTerritory WHERE TerritoryKey <> -1)
    <> (SELECT COUNT_BIG(*) FROM [$(SourceDb)].Sales.SalesTerritory)
    THROW 52016, 'Diferencia de filas en territorios.', 1;

IF EXISTS (
    SELECT TerritoryKey FROM dw.DimTerritory WHERE TerritoryKey <> -1
    EXCEPT
    SELECT TerritoryID FROM [$(SourceDb)].Sales.SalesTerritory
)
    THROW 52017, 'Las claves de territorios difieren de la fuente.', 1;

-- Revisa que el monto total de ventas coincida con la fuente
IF (
    SELECT ABS(
        SUM(CONVERT(decimal(19,4), SalesAmount))
        - (SELECT SUM(CONVERT(decimal(19,4),
               ISNULL(LineTotal, CONVERT(money, ISNULL(OrderQty, 0) * ISNULL(UnitPrice, 0.00)
                       * (1.0 - ISNULL(UnitPriceDiscount, 0.00))))
           ))
           FROM [$(SourceDb)].Sales.SalesOrderDetail)
    )
    FROM dw.FactSales
) > 0.01
    THROW 52008, 'Diferencia en el importe de ventas.', 1;

-- Revisa que existan las 15 vistas de reportabilidad
IF (SELECT COUNT(*) FROM sys.views
    WHERE schema_id = SCHEMA_ID(N'rpt')) <> 15
    THROW 52009, 'No existen las 15 vistas de reportabilidad.', 1;

-- Revisa que ninguna venta u orden quede con claves que no existan
IF EXISTS (
    SELECT 1 FROM dw.FactSales s
    LEFT JOIN dw.DimCustomer c ON c.CustomerKey = s.CustomerKey
    LEFT JOIN dw.DimProduct p ON p.ProductKey = s.ProductKey
    LEFT JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
    WHERE c.CustomerKey IS NULL OR p.ProductKey IS NULL OR d.DateKey IS NULL
)
    THROW 52010, 'Hay ventas con claves sin dimensión.', 1;

IF EXISTS (
    SELECT 1 FROM dw.FactWorkOrder w
    LEFT JOIN dw.DimProduct p ON p.ProductKey = w.ProductKey
    LEFT JOIN dw.DimDate d ON d.DateKey = w.StartDateKey
    WHERE p.ProductKey IS NULL OR d.DateKey IS NULL
)
    THROW 52011, 'Hay órdenes de trabajo con claves sin dimensión.', 1;

IF EXISTS (
    SELECT 1 FROM dw.FactInventory i
    LEFT JOIN dw.DimProduct p ON p.ProductKey = i.ProductKey
    LEFT JOIN dw.DimLocation l ON l.LocationKey = i.LocationKey
    WHERE p.ProductKey IS NULL OR l.LocationKey IS NULL
)
    THROW 52012, 'Hay inventario con claves sin dimensión.', 1;

IF EXISTS (
    SELECT 1 FROM dw.FactRouting r
    LEFT JOIN dw.DimProduct p ON p.ProductKey = r.ProductKey
    LEFT JOIN dw.DimLocation l ON l.LocationKey = r.LocationKey
    WHERE p.ProductKey IS NULL OR l.LocationKey IS NULL
)
    THROW 52013, 'Hay rutas con claves sin dimensión.', 1;

IF EXISTS (
    SELECT 1 FROM dw.FactPurchase f
    LEFT JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
    LEFT JOIN dw.DimVendor v ON v.VendorKey = f.VendorKey
    WHERE p.ProductKey IS NULL OR v.VendorKey IS NULL
)
    THROW 52014, 'Hay compras con claves sin dimensión.', 1;

-- Revisa que no haya territorios sin nombre
IF EXISTS (
    SELECT 1 FROM dw.DimTerritory
    WHERE NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(
              REPLACE(TerritoryName, NCHAR(9), N' '), NCHAR(10), N' '),
              NCHAR(13), N' '), NCHAR(160), N' '))), N'') IS NULL
)
    THROW 52015, 'Hay territorios con nombre nulo o vacío.', 1;

-- Revisa que los clientes tengan pais, region y ciudad
IF EXISTS (
    SELECT 1 FROM dw.DimCustomer
    WHERE NULLIF(LTRIM(RTRIM(CountryName)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(StateProvinceName)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(City)), N'') IS NULL
)
    THROW 52018, 'Hay clientes con etiquetas geográficas nulas o vacías.', 1;

-- Revisa que existan las filas por defecto (-1) en las dimensiones
IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE DateKey = -1)
    OR NOT EXISTS (SELECT 1 FROM dw.DimTerritory WHERE TerritoryKey = -1)
    OR NOT EXISTS (SELECT 1 FROM dw.DimCustomer WHERE CustomerKey = -1)
    OR NOT EXISTS (SELECT 1 FROM dw.DimProduct WHERE ProductKey = -1)
    OR NOT EXISTS (SELECT 1 FROM dw.DimLocation WHERE LocationKey = -1)
    OR NOT EXISTS (SELECT 1 FROM dw.DimVendor WHERE VendorKey = -1)
    OR NOT EXISTS (SELECT 1 FROM dw.DimSalesPerson WHERE SalesPersonKey = -1)
    THROW 52019, 'Falta la fila por defecto (-1) en las dimensiones.', 1;

SELECT 'VALIDATION_OK' AS Result,
       (SELECT COUNT_BIG(*) FROM dw.FactSales) AS SalesRows,
       (SELECT COUNT_BIG(*) FROM dw.FactWorkOrder) AS WorkOrderRows,
       (SELECT COUNT_BIG(*) FROM dw.FactInventory) AS InventoryRows,
       (SELECT COUNT_BIG(*) FROM dw.FactRouting) AS RoutingRows,
       (SELECT COUNT_BIG(*) FROM dw.FactPurchase) AS PurchaseRows,
       (SELECT COUNT(*) FROM sys.views
         WHERE schema_id = SCHEMA_ID(N'rpt')) AS ReportingViews;

SELECT TOP (5) RunId, SourceDatabase, StartedAt, FinishedAt, Status,
       ErrorMessage
FROM dw.EtlRun ORDER BY RunId DESC;
GO
