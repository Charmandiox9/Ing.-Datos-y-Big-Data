USE [$(TargetDb)];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_ID(N'$(SourceDb)') IS NULL
    THROW 51000, 'La base fuente no existe en esta instancia.', 1;
IF DB_ID(N'$(SourceDb)') = DB_ID()
    THROW 51001, 'La base fuente y el Data Warehouse deben ser distintas.', 1;
IF OBJECT_ID(N'$(SourceDb).Sales.SalesOrderHeader', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Sales.SalesOrderDetail', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Sales.Customer', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Production.Product', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Production.WorkOrder', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Production.ProductInventory', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Production.WorkOrderRouting', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Purchasing.PurchaseOrderHeader', N'U') IS NULL
    OR OBJECT_ID(N'$(SourceDb).Purchasing.PurchaseOrderDetail', N'U') IS NULL
    THROW 51002, 'La fuente no contiene el esquema AdventureWorks requerido.', 1;

DECLARE @RunId bigint;
INSERT INTO dw.EtlRun(SourceDatabase, Status)
VALUES (N'$(SourceDb)', 'RUNNING');
SET @RunId = SCOPE_IDENTITY();

BEGIN TRY
    BEGIN TRANSACTION;

    -- Limpieza previa en orden para no chocar con dependencias
    DELETE FROM dw.FactSales;
    DELETE FROM dw.FactWorkOrder;
    DELETE FROM dw.FactInventory;
    DELETE FROM dw.FactRouting;
    DELETE FROM dw.FactPurchase;
    DELETE FROM dw.DimDate;
    DELETE FROM dw.DimTerritory;
    DELETE FROM dw.DimCustomer;
    DELETE FROM dw.DimProduct;
    DELETE FROM dw.DimLocation;
    DELETE FROM dw.DimVendor;
    DELETE FROM dw.DimSalesPerson;

    -- Fila por defecto si no hay fecha o viene nula
    INSERT INTO dw.DimDate
        (DateKey, CalendarDate, CalendarYear, CalendarQuarter,
         CalendarMonth, MonthNameSpanish, YearMonth)
    VALUES
        (-1, CONVERT(date, '1900-01-01', 120), 1900, 0, 0, N'Sin fecha', '1900-00');

    -- Calendario continuo del 2000 al 2050
    ;WITH N AS (
        SELECT TOP (18628)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS Number
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    D AS (
        SELECT DATEADD(day, Number, CONVERT(date, '20000101', 112)) AS CalendarDate
        FROM N
    )
    INSERT INTO dw.DimDate
        (DateKey, CalendarDate, CalendarYear, CalendarQuarter,
         CalendarMonth, MonthNameSpanish, YearMonth)
    SELECT CONVERT(int, CONVERT(char(8), CalendarDate, 112)),
           CalendarDate, YEAR(CalendarDate), DATEPART(quarter, CalendarDate),
           MONTH(CalendarDate),
           CHOOSE(MONTH(CalendarDate), N'enero', N'febrero', N'marzo',
                  N'abril', N'mayo', N'junio', N'julio', N'agosto',
                  N'septiembre', N'octubre', N'noviembre', N'diciembre'),
           CONVERT(char(7), CalendarDate, 126)
    FROM D
    WHERE CalendarDate < '20510101';

    -- Fila por defecto para ventas sin territorio
    INSERT INTO dw.DimTerritory
        (TerritoryKey, TerritoryName, TerritoryGroup, CountryRegionCode)
    VALUES
        (-1, N'Sin territorio', N'Sin grupo', N'N/A');

    -- Carga territorios limpiando espacios y caracteres raros
    ;WITH CleanTerritory AS (
        SELECT t.TerritoryID,
               COALESCE(
                   NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(
                       REPLACE(t.Name, NCHAR(9), N' '), NCHAR(10), N' '),
                       NCHAR(13), N' '), NCHAR(160), N' '))), N''),
                   CONCAT(N'Territorio ', t.TerritoryID)
               ) AS CleanName,
               COALESCE(NULLIF(LTRIM(RTRIM(t.[Group])), N''), N'Sin grupo') AS CleanGroup,
               COALESCE(NULLIF(LTRIM(RTRIM(t.CountryRegionCode)), N''), N'N/A') AS CleanCountry,
               ROW_NUMBER() OVER (PARTITION BY t.TerritoryID ORDER BY (SELECT NULL)) AS rn
        FROM [$(SourceDb)].Sales.SalesTerritory t
        WHERE t.TerritoryID IS NOT NULL
    )
    INSERT INTO dw.DimTerritory
        (TerritoryKey, TerritoryName, TerritoryGroup, CountryRegionCode)
    SELECT TerritoryID,
           LEFT(CleanName, 50),
           LEFT(CleanGroup, 50),
           LEFT(CleanCountry, 3)
    FROM CleanTerritory
    WHERE rn = 1;

    -- Fila por defecto para cliente no identificado
    INSERT INTO dw.DimCustomer
        (CustomerKey, CustomerName, CustomerType, TerritoryKey,
         CountryName, StateProvinceName, City)
    VALUES
        (-1, N'Cliente no registrado', 'Desconocido', -1,
         N'Sin país', N'Sin región', N'Sin ciudad');

    -- Resuelve nombres de clientes y completa ubicaciones si faltan datos
    ;WITH RawCustomer AS (
        SELECT c.CustomerID,
               COALESCE(
                   NULLIF(LTRIM(RTRIM(st.Name)), N''),
                   NULLIF(LTRIM(RTRIM(CONCAT(p.FirstName, N' ', p.LastName))), N''),
                   CONCAT(N'Cliente ', c.CustomerID)
               ) AS RawCustomerName,
               CASE WHEN c.StoreID IS NOT NULL THEN 'Tienda' ELSE 'Persona' END AS CustomerType,
               CASE WHEN st_terr.TerritoryID IS NOT NULL THEN c.TerritoryID ELSE -1 END AS CleanTerritoryKey,
               COALESCE(NULLIF(LTRIM(RTRIM(cr.Name)), N''), N'Sin país') AS CleanCountryName,
               COALESCE(NULLIF(LTRIM(RTRIM(sp.Name)), N''), N'Sin región') AS CleanStateName,
               COALESCE(NULLIF(LTRIM(RTRIM(a.City)), N''), N'Sin ciudad') AS CleanCityName,
               ROW_NUMBER() OVER (PARTITION BY c.CustomerID ORDER BY (SELECT NULL)) AS rn
        FROM [$(SourceDb)].Sales.Customer c
        LEFT JOIN [$(SourceDb)].Sales.SalesTerritory st_terr
          ON st_terr.TerritoryID = c.TerritoryID
        LEFT JOIN [$(SourceDb)].Sales.Store st
          ON st.BusinessEntityID = c.StoreID
        LEFT JOIN [$(SourceDb)].Person.Person p
          ON p.BusinessEntityID = c.PersonID
        OUTER APPLY (
            SELECT TOP (1) bea.AddressID
            FROM [$(SourceDb)].Person.BusinessEntityAddress bea
            WHERE bea.BusinessEntityID = COALESCE(c.PersonID, c.StoreID)
            ORDER BY bea.AddressID
        ) ca
        LEFT JOIN [$(SourceDb)].Person.Address a
          ON a.AddressID = ca.AddressID
        LEFT JOIN [$(SourceDb)].Person.StateProvince sp
          ON sp.StateProvinceID = a.StateProvinceID
        LEFT JOIN [$(SourceDb)].Person.CountryRegion cr
          ON cr.CountryRegionCode = sp.CountryRegionCode
        WHERE c.CustomerID IS NOT NULL
    )
    INSERT INTO dw.DimCustomer
        (CustomerKey, CustomerName, CustomerType, TerritoryKey,
         CountryName, StateProvinceName, City)
    SELECT CustomerID,
           LEFT(RawCustomerName, 200),
           CustomerType,
           CleanTerritoryKey,
           LEFT(CleanCountryName, 50),
           LEFT(CleanStateName, 50),
           LEFT(CleanCityName, 30)
    FROM RawCustomer
    WHERE rn = 1;

    -- Fila por defecto si el producto no existe
    INSERT INTO dw.DimProduct
        (ProductKey, ProductName, ProductNumber,
         CategoryName, SubcategoryName, MakeFlag, ListPrice)
    VALUES
        (-1, N'Producto no registrado', N'DESCONOCIDO',
         N'Sin categoría', N'Sin subcategoría', 0, 0.00);

    -- Carga productos y pone etiquetas si faltan categorias o subcategorias
    ;WITH RawProduct AS (
        SELECT p.ProductID,
               COALESCE(NULLIF(LTRIM(RTRIM(p.Name)), N''), CONCAT(N'Producto ', p.ProductID)) AS CleanProductName,
               COALESCE(NULLIF(LTRIM(RTRIM(p.ProductNumber)), N''), CONCAT(N'PRD-', p.ProductID)) AS CleanProductNumber,
               COALESCE(NULLIF(LTRIM(RTRIM(cat.Name)), N''), N'Sin categoría') AS CleanCategoryName,
               COALESCE(NULLIF(LTRIM(RTRIM(sub.Name)), N''), N'Sin subcategoría') AS CleanSubcategoryName,
               ISNULL(p.MakeFlag, 0) AS CleanMakeFlag,
               CASE WHEN p.ListPrice IS NULL OR p.ListPrice < 0 THEN 0.00 ELSE p.ListPrice END AS CleanListPrice,
               ROW_NUMBER() OVER (PARTITION BY p.ProductID ORDER BY (SELECT NULL)) AS rn
        FROM [$(SourceDb)].Production.Product p
        LEFT JOIN [$(SourceDb)].Production.ProductSubcategory sub
          ON sub.ProductSubcategoryID = p.ProductSubcategoryID
        LEFT JOIN [$(SourceDb)].Production.ProductCategory cat
          ON cat.ProductCategoryID = sub.ProductCategoryID
        WHERE p.ProductID IS NOT NULL
    )
    INSERT INTO dw.DimProduct
        (ProductKey, ProductName, ProductNumber,
         CategoryName, SubcategoryName, MakeFlag, ListPrice)
    SELECT ProductID,
           LEFT(CleanProductName, 50),
           LEFT(CleanProductNumber, 25),
           LEFT(CleanCategoryName, 50),
           LEFT(CleanSubcategoryName, 50),
           CleanMakeFlag,
           CleanListPrice
    FROM RawProduct
    WHERE rn = 1;

    -- Fila por defecto para ubicacion no registrada
    INSERT INTO dw.DimLocation (LocationKey, LocationName)
    VALUES (-1, N'Ubicación no registrada');

    INSERT INTO dw.DimLocation (LocationKey, LocationName)
    SELECT LocationID,
           LEFT(COALESCE(NULLIF(LTRIM(RTRIM(Name)), N''), CONCAT(N'Ubicación ', LocationID)), 50)
    FROM [$(SourceDb)].Production.Location
    WHERE LocationID IS NOT NULL;

    -- Fila por defecto para proveedor no registrado
    INSERT INTO dw.DimVendor (VendorKey, VendorName)
    VALUES (-1, N'Proveedor no registrado');

    INSERT INTO dw.DimVendor (VendorKey, VendorName)
    SELECT BusinessEntityID,
           LEFT(COALESCE(NULLIF(LTRIM(RTRIM(Name)), N''), CONCAT(N'Proveedor ', BusinessEntityID)), 50)
    FROM [$(SourceDb)].Purchasing.Vendor
    WHERE BusinessEntityID IS NOT NULL;

    -- Fila por defecto para ventas sin vendedor
    INSERT INTO dw.DimSalesPerson (SalesPersonKey, SalesPersonName, TerritoryKey)
    VALUES (-1, N'Sin vendedor asignado', -1);

    -- Carga vendedores con LEFT JOIN por si alguno no tiene persona asociada
    ;WITH RawSalesPerson AS (
        SELECT s.BusinessEntityID,
               COALESCE(
                   NULLIF(LTRIM(RTRIM(CONCAT(p.FirstName, N' ', p.LastName))), N''),
                   CONCAT(N'Vendedor ', s.BusinessEntityID)
               ) AS CleanSalesPersonName,
               CASE WHEN st_terr.TerritoryID IS NOT NULL THEN s.TerritoryID ELSE -1 END AS CleanTerritoryKey,
               ROW_NUMBER() OVER (PARTITION BY s.BusinessEntityID ORDER BY (SELECT NULL)) AS rn
        FROM [$(SourceDb)].Sales.SalesPerson s
        LEFT JOIN [$(SourceDb)].Person.Person p
          ON p.BusinessEntityID = s.BusinessEntityID
        LEFT JOIN [$(SourceDb)].Sales.SalesTerritory st_terr
          ON st_terr.TerritoryID = s.TerritoryID
        WHERE s.BusinessEntityID IS NOT NULL
    )
    INSERT INTO dw.DimSalesPerson (SalesPersonKey, SalesPersonName, TerritoryKey)
    SELECT BusinessEntityID, LEFT(CleanSalesPersonName, 200), CleanTerritoryKey
    FROM RawSalesPerson
    WHERE rn = 1;

    -- Carga ventas con LEFT JOIN a cabecera para no perder detalles si falta la orden
    INSERT INTO dw.FactSales
        (SalesOrderId, SalesOrderDetailId, OrderDateKey,
         CustomerKey, ProductKey, TerritoryKey, SalesPersonKey,
         ShipToAddressId, OnlineOrderFlag, OrderQty, UnitPrice,
         UnitPriceDiscount, SalesAmount, DiscountAmount)
    SELECT d.SalesOrderID,
           d.SalesOrderDetailID,
           COALESCE(dt.DateKey, -1) AS OrderDateKey,
           COALESCE(c.CustomerKey, -1) AS CustomerKey,
           COALESCE(p.ProductKey, -1) AS ProductKey,
           COALESCE(t.TerritoryKey, -1) AS TerritoryKey,
           CASE WHEN h.SalesPersonID IS NOT NULL
                THEN COALESCE(sp.SalesPersonKey, -1)
                ELSE NULL END AS SalesPersonKey,
           h.ShipToAddressID,
           ISNULL(h.OnlineOrderFlag, 0) AS OnlineOrderFlag,
           ISNULL(d.OrderQty, 0) AS OrderQty,
           ISNULL(d.UnitPrice, 0.00) AS UnitPrice,
           ISNULL(d.UnitPriceDiscount, 0.00) AS UnitPriceDiscount,
           ISNULL(d.LineTotal,
                  CONVERT(money, ISNULL(d.OrderQty, 0) * ISNULL(d.UnitPrice, 0.00)
                          * (1.0 - ISNULL(d.UnitPriceDiscount, 0.00)))) AS SalesAmount,
           CONVERT(money, ISNULL(d.UnitPrice, 0.00) * ISNULL(d.OrderQty, 0)
                          * ISNULL(d.UnitPriceDiscount, 0.00)) AS DiscountAmount
    FROM [$(SourceDb)].Sales.SalesOrderDetail d
    LEFT JOIN [$(SourceDb)].Sales.SalesOrderHeader h
      ON h.SalesOrderID = d.SalesOrderID
    LEFT JOIN dw.DimDate dt
      ON dt.CalendarDate = TRY_CONVERT(date, h.OrderDate)
    LEFT JOIN dw.DimCustomer c
      ON c.CustomerKey = h.CustomerID
    LEFT JOIN dw.DimProduct p
      ON p.ProductKey = d.ProductID
    LEFT JOIN dw.DimTerritory t
      ON t.TerritoryKey = h.TerritoryID
    LEFT JOIN dw.DimSalesPerson sp
      ON sp.SalesPersonKey = h.SalesPersonID;

    -- Carga ordenes de trabajo protegiendo fechas y producto con -1
    INSERT INTO dw.FactWorkOrder
        (WorkOrderId, ProductKey, StartDateKey, EndDateKey, DueDateKey,
         ScrapReasonId, OrderQty, ScrappedQty, CompletedFlag, LateFlag)
    SELECT w.WorkOrderID,
           COALESCE(p.ProductKey, -1) AS ProductKey,
           COALESCE(dtStart.DateKey, -1) AS StartDateKey,
           dtEnd.DateKey AS EndDateKey,
           COALESCE(dtDue.DateKey, -1) AS DueDateKey,
           w.ScrapReasonID,
           ISNULL(w.OrderQty, 0) AS OrderQty,
           ISNULL(w.ScrappedQty, 0) AS ScrappedQty,
           CASE WHEN w.EndDate IS NULL THEN 0 ELSE 1 END AS CompletedFlag,
           CASE WHEN w.EndDate IS NOT NULL AND w.DueDate IS NOT NULL AND w.EndDate > w.DueDate
                THEN 1 ELSE 0 END AS LateFlag
    FROM [$(SourceDb)].Production.WorkOrder w
    LEFT JOIN dw.DimProduct p
      ON p.ProductKey = w.ProductID
    LEFT JOIN dw.DimDate dtStart
      ON dtStart.CalendarDate = TRY_CONVERT(date, w.StartDate)
    LEFT JOIN dw.DimDate dtEnd
      ON dtEnd.CalendarDate = TRY_CONVERT(date, w.EndDate)
    LEFT JOIN dw.DimDate dtDue
      ON dtDue.CalendarDate = TRY_CONVERT(date, w.DueDate);

    -- Carga inventario actual
    INSERT INTO dw.FactInventory
        (SnapshotDateKey, ProductKey, LocationKey, Shelf, Bin, Quantity)
    SELECT CONVERT(int, CONVERT(char(8), SYSUTCDATETIME(), 112)) AS SnapshotDateKey,
           COALESCE(p.ProductKey, -1) AS ProductKey,
           COALESCE(l.LocationKey, -1) AS LocationKey,
           LEFT(COALESCE(NULLIF(LTRIM(RTRIM(i.Shelf)), N''), N'N/A'), 10) AS Shelf,
           ISNULL(i.Bin, 0) AS Bin,
           ISNULL(i.Quantity, 0) AS Quantity
    FROM [$(SourceDb)].Production.ProductInventory i
    LEFT JOIN dw.DimProduct p
      ON p.ProductKey = i.ProductID
    LEFT JOIN dw.DimLocation l
      ON l.LocationKey = i.LocationID;

    -- Carga tiempos y costos por ruta
    INSERT INTO dw.FactRouting
        (WorkOrderId, OperationSequence, ProductKey, LocationKey,
         ScheduledStartDateKey, PlannedHours, ActualHours,
         PlannedCost, ActualCost)
    SELECT r.WorkOrderID,
           r.OperationSequence,
           COALESCE(p.ProductKey, -1) AS ProductKey,
           COALESCE(l.LocationKey, -1) AS LocationKey,
           COALESCE(dtSched.DateKey, -1) AS ScheduledStartDateKey,
           CONVERT(decimal(18,2),
               ISNULL(DATEDIFF(minute, r.ScheduledStartDate, r.ScheduledEndDate) / 60.0, 0.0))
               AS PlannedHours,
           CONVERT(decimal(18,2), ISNULL(r.ActualResourceHrs, 0.0)) AS ActualHours,
           ISNULL(r.PlannedCost, 0.00) AS PlannedCost,
           ISNULL(r.ActualCost, 0.00) AS ActualCost
    FROM [$(SourceDb)].Production.WorkOrderRouting r
    LEFT JOIN dw.DimProduct p
      ON p.ProductKey = r.ProductID
    LEFT JOIN dw.DimLocation l
      ON l.LocationKey = r.LocationID
    LEFT JOIN dw.DimDate dtSched
      ON dtSched.CalendarDate = TRY_CONVERT(date, r.ScheduledStartDate);

    -- Carga ordenes de compra con LEFT JOIN a cabecera
    INSERT INTO dw.FactPurchase
        (PurchaseOrderId, PurchaseOrderDetailId, OrderDateKey,
         VendorKey, ProductKey, OrderQty, ReceivedQty,
         RejectedQty, PurchaseAmount)
    SELECT d.PurchaseOrderID,
           d.PurchaseOrderDetailID,
           COALESCE(dt.DateKey, -1) AS OrderDateKey,
           COALESCE(v.VendorKey, -1) AS VendorKey,
           COALESCE(p.ProductKey, -1) AS ProductKey,
           ISNULL(d.OrderQty, 0) AS OrderQty,
           ISNULL(d.ReceivedQty, 0.00) AS ReceivedQty,
           ISNULL(d.RejectedQty, 0.00) AS RejectedQty,
           ISNULL(d.LineTotal,
                  CONVERT(money, ISNULL(d.OrderQty, 0) * ISNULL(d.UnitPrice, 0.00)))
                  AS PurchaseAmount
    FROM [$(SourceDb)].Purchasing.PurchaseOrderDetail d
    LEFT JOIN [$(SourceDb)].Purchasing.PurchaseOrderHeader h
      ON h.PurchaseOrderID = d.PurchaseOrderID
    LEFT JOIN dw.DimDate dt
      ON dt.CalendarDate = TRY_CONVERT(date, h.OrderDate)
    LEFT JOIN dw.DimVendor v
      ON v.VendorKey = h.VendorID
    LEFT JOIN dw.DimProduct p
      ON p.ProductKey = d.ProductID;

    COMMIT TRANSACTION;

    UPDATE dw.EtlRun
       SET FinishedAt = SYSUTCDATETIME(), Status = 'SUCCEEDED'
     WHERE RunId = @RunId;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    UPDATE dw.EtlRun
       SET FinishedAt = SYSUTCDATETIME(), Status = 'FAILED',
           ErrorMessage = ERROR_MESSAGE()
     WHERE RunId = @RunId;
    THROW;
END CATCH;
GO
