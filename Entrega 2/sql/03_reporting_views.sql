USE [$(TargetDb)];
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'rpt')
    EXEC(N'CREATE SCHEMA rpt');
GO

-- Una vista por cada mockup. Las vistas son tablas listas para Power BI;
-- los gráficos se construyen con visuales nativos sobre estos campos.

CREATE OR ALTER VIEW rpt.C01_PerfilClientes AS
SELECT c.CustomerType, ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName,
       COUNT_BIG(*) AS Clientes
FROM dw.DimCustomer c
LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = c.TerritoryKey
GROUP BY c.CustomerType, t.TerritoryName;
GO

CREATE OR ALTER VIEW rpt.C02_VentasPorCliente AS
SELECT c.CustomerKey, c.CustomerName, c.CustomerType,
       ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       COALESCE(SUM(s.SalesAmount), 0) AS Ventas,
       CONVERT(decimal(19,2), COALESCE(SUM(s.SalesAmount), 0)
           / NULLIF(COUNT(DISTINCT s.SalesOrderId), 0)) AS TicketPromedio
FROM dw.DimCustomer c
LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = c.TerritoryKey
LEFT JOIN dw.FactSales s ON s.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey, c.CustomerName, c.CustomerType, t.TerritoryName;
GO

CREATE OR ALTER VIEW rpt.C03_FrecuenciaClientes AS
SELECT c.CustomerKey, c.CustomerName, ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       CASE WHEN COUNT(DISTINCT s.SalesOrderId) = 0 THEN 'Sin compras'
            WHEN COUNT(DISTINCT s.SalesOrderId) = 1 THEN 'Una compra'
            ELSE 'Recurrente' END AS Segmento
FROM dw.DimCustomer c
LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = c.TerritoryKey
LEFT JOIN dw.FactSales s ON s.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey, c.CustomerName, t.TerritoryName;
GO

CREATE OR ALTER VIEW rpt.C04_GeografiaClientes AS
SELECT c.CountryName, c.StateProvinceName, c.City,
       ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName,
       COUNT(DISTINCT c.CustomerKey) AS Clientes,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       COALESCE(SUM(s.SalesAmount), 0) AS Ventas
FROM dw.DimCustomer c
LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = c.TerritoryKey
LEFT JOIN dw.FactSales s ON s.CustomerKey = c.CustomerKey
GROUP BY c.CountryName, c.StateProvinceName, c.City, t.TerritoryName;
GO

CREATE OR ALTER VIEW rpt.C05_ClientesInactivos AS
WITH Ultima AS (
    SELECT c.CustomerKey, c.CustomerName, ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName,
           MAX(d.CalendarDate) AS UltimaCompra,
           COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
           COALESCE(SUM(s.SalesAmount), 0) AS VentasHistoricas
    FROM dw.DimCustomer c
    LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = c.TerritoryKey
    LEFT JOIN dw.FactSales s ON s.CustomerKey = c.CustomerKey
    LEFT JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
    GROUP BY c.CustomerKey, c.CustomerName, t.TerritoryName
)
SELECT u.*,
       DATEDIFF(day, u.UltimaCompra, ref.FechaReferencia) AS DiasSinCompra,
       ref.FechaReferencia,
       CASE WHEN u.Ordenes = 0 THEN 'Sin compras'
            WHEN DATEDIFF(day, u.UltimaCompra, ref.FechaReferencia) >= 180
                THEN 'Inactivo 180+'
            ELSE 'Activo' END AS EstadoActividad
FROM Ultima u
CROSS JOIN (
    SELECT MAX(d.CalendarDate) AS FechaReferencia
    FROM dw.FactSales s
    INNER JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
) ref;
GO

CREATE OR ALTER VIEW rpt.P01_ProduccionProducto AS
SELECT p.CategoryName, p.SubcategoryName, p.ProductKey, p.ProductName,
       d.CalendarYear, d.CalendarMonth,
       COUNT_BIG(*) AS OrdenesTrabajo,
       SUM(CONVERT(bigint, w.OrderQty)) AS UnidadesOrdenadas,
       SUM(CONVERT(bigint, w.ScrappedQty)) AS UnidadesRechazadas,
       CONVERT(decimal(9,4),
           SUM(CONVERT(decimal(19,4), w.ScrappedQty))
           / NULLIF(SUM(CONVERT(decimal(19,4), w.OrderQty)), 0))
           AS TasaRechazo
FROM dw.FactWorkOrder w
INNER JOIN dw.DimProduct p ON p.ProductKey = w.ProductKey
INNER JOIN dw.DimDate d ON d.DateKey = w.StartDateKey
GROUP BY p.CategoryName, p.SubcategoryName, p.ProductKey, p.ProductName,
         d.CalendarYear, d.CalendarMonth;
GO

CREATE OR ALTER VIEW rpt.P02_InventarioUbicacion AS
SELECT d.CalendarDate AS FechaCorte, l.LocationName,
       p.CategoryName, p.ProductKey, p.ProductName,
       SUM(CONVERT(bigint, i.Quantity)) AS Unidades,
       COUNT_BIG(*) AS Posiciones
FROM dw.FactInventory i
INNER JOIN dw.DimDate d ON d.DateKey = i.SnapshotDateKey
INNER JOIN dw.DimLocation l ON l.LocationKey = i.LocationKey
INNER JOIN dw.DimProduct p ON p.ProductKey = i.ProductKey
GROUP BY d.CalendarDate, l.LocationName,
         p.CategoryName, p.ProductKey, p.ProductName;
GO

CREATE OR ALTER VIEW rpt.P03_CumplimientoOT AS
SELECT w.WorkOrderId, p.ProductName, p.CategoryName,
       startDate.CalendarDate AS FechaInicio,
       endDate.CalendarDate AS FechaFin,
       dueDate.CalendarDate AS FechaCompromiso,
       w.OrderQty, w.ScrappedQty,
       CASE WHEN w.CompletedFlag = 0 THEN 'En curso'
            WHEN w.LateFlag = 1 THEN 'Atrasada'
            ELSE 'A tiempo' END AS Estado,
       DATEDIFF(day, startDate.CalendarDate, endDate.CalendarDate)
           AS DiasEjecucion
FROM dw.FactWorkOrder w
INNER JOIN dw.DimProduct p ON p.ProductKey = w.ProductKey
INNER JOIN dw.DimDate startDate ON startDate.DateKey = w.StartDateKey
LEFT JOIN dw.DimDate endDate ON endDate.DateKey = w.EndDateKey
INNER JOIN dw.DimDate dueDate ON dueDate.DateKey = w.DueDateKey;
GO

CREATE OR ALTER VIEW rpt.P04_EficienciaRutas AS
SELECT r.WorkOrderId, r.OperationSequence,
       l.LocationName, p.ProductName,
       d.CalendarDate AS FechaProgramada,
       r.PlannedHours, r.ActualHours,
       r.ActualHours - r.PlannedHours AS DesviacionHoras,
       r.PlannedCost, r.ActualCost,
       r.ActualCost - r.PlannedCost AS DesviacionCosto
FROM dw.FactRouting r
INNER JOIN dw.DimLocation l ON l.LocationKey = r.LocationKey
INNER JOIN dw.DimProduct p ON p.ProductKey = r.ProductKey
INNER JOIN dw.DimDate d ON d.DateKey = r.ScheduledStartDateKey;
GO

CREATE OR ALTER VIEW rpt.P05_Abastecimiento AS
SELECT d.CalendarYear, d.CalendarMonth,
       v.VendorKey, v.VendorName,
       p.CategoryName, p.ProductKey, p.ProductName,
       COUNT(DISTINCT f.PurchaseOrderId) AS OrdenesCompra,
       SUM(CONVERT(bigint, f.OrderQty)) AS UnidadesOrdenadas,
       SUM(f.ReceivedQty) AS UnidadesRecibidas,
       SUM(f.RejectedQty) AS UnidadesRechazadas,
       SUM(f.PurchaseAmount) AS MontoComprado
FROM dw.FactPurchase f
INNER JOIN dw.DimDate d ON d.DateKey = f.OrderDateKey
INNER JOIN dw.DimVendor v ON v.VendorKey = f.VendorKey
INNER JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
GROUP BY d.CalendarYear, d.CalendarMonth,
         v.VendorKey, v.VendorName,
         p.CategoryName, p.ProductKey, p.ProductName;
GO

CREATE OR ALTER VIEW rpt.V01_ResumenVentas AS
SELECT d.CalendarYear, d.CalendarQuarter, d.CalendarMonth,
       d.YearMonth,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       SUM(CONVERT(bigint, s.OrderQty)) AS Unidades,
       SUM(s.SalesAmount) AS Ventas,
       CONVERT(decimal(19,2),
           SUM(s.SalesAmount) / NULLIF(COUNT(DISTINCT s.SalesOrderId), 0))
           AS TicketPromedio
FROM dw.FactSales s
INNER JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
GROUP BY d.CalendarYear, d.CalendarQuarter, d.CalendarMonth, d.YearMonth;
GO

CREATE OR ALTER VIEW rpt.V02_VentasTerritorio AS
SELECT d.CalendarYear, d.YearMonth,
       t.TerritoryGroup, ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName, t.CountryRegionCode,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       SUM(CONVERT(bigint, s.OrderQty)) AS Unidades,
       SUM(s.SalesAmount) AS Ventas
FROM dw.FactSales s
INNER JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = s.TerritoryKey
GROUP BY d.CalendarYear, d.YearMonth,
         t.TerritoryGroup, t.TerritoryName, t.CountryRegionCode;
GO

CREATE OR ALTER VIEW rpt.V03_VentasProducto AS
SELECT d.CalendarYear, p.CategoryName, p.SubcategoryName,
       p.ProductKey, p.ProductName,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       SUM(CONVERT(bigint, s.OrderQty)) AS Unidades,
       SUM(s.SalesAmount) AS Ventas,
       SUM(s.DiscountAmount) AS Descuento,
       CONVERT(decimal(19,2),
           SUM(s.SalesAmount) / NULLIF(SUM(CONVERT(bigint, s.OrderQty)), 0))
           AS PrecioPromedio
FROM dw.FactSales s
INNER JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
INNER JOIN dw.DimProduct p ON p.ProductKey = s.ProductKey
GROUP BY d.CalendarYear, p.CategoryName, p.SubcategoryName,
         p.ProductKey, p.ProductName;
GO

CREATE OR ALTER VIEW rpt.V04_VentasCanal AS
SELECT d.CalendarYear, d.YearMonth,
       CASE WHEN s.OnlineOrderFlag = 1
            THEN 'Online' ELSE 'Distribuidor' END AS Canal,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       SUM(CONVERT(bigint, s.OrderQty)) AS Unidades,
       SUM(s.SalesAmount) AS Ventas,
       CONVERT(decimal(19,2),
           SUM(s.SalesAmount) / NULLIF(COUNT(DISTINCT s.SalesOrderId), 0))
           AS TicketPromedio
FROM dw.FactSales s
INNER JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
GROUP BY d.CalendarYear, d.YearMonth, s.OnlineOrderFlag;
GO

CREATE OR ALTER VIEW rpt.V05_DesempenoVendedores AS
SELECT d.CalendarYear, d.YearMonth,
       sp.SalesPersonKey, sp.SalesPersonName,
       ISNULL(t.TerritoryName, N'Sin territorio') AS TerritoryName,
       COUNT(DISTINCT s.SalesOrderId) AS Ordenes,
       COUNT(DISTINCT s.CustomerKey) AS ClientesAtendidos,
       SUM(s.SalesAmount) AS Ventas
FROM dw.FactSales s
INNER JOIN dw.DimDate d ON d.DateKey = s.OrderDateKey
INNER JOIN dw.DimSalesPerson sp
  ON sp.SalesPersonKey = s.SalesPersonKey
LEFT JOIN dw.DimTerritory t ON t.TerritoryKey = s.TerritoryKey
GROUP BY d.CalendarYear, d.YearMonth,
         sp.SalesPersonKey, sp.SalesPersonName, t.TerritoryName;
GO
