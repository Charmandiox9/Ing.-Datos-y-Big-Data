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

    INSERT INTO dw.DimTerritory
        (TerritoryKey, TerritoryName, TerritoryGroup, CountryRegionCode)
    SELECT TerritoryID, Name, [Group], CountryRegionCode
    FROM [$(SourceDb)].Sales.SalesTerritory;

    INSERT INTO dw.DimCustomer
        (CustomerKey, CustomerName, CustomerType, TerritoryKey,
         CountryName, StateProvinceName, City)
    SELECT c.CustomerID,
           COALESCE(st.Name,
                    NULLIF(CONCAT(p.FirstName, N' ', p.LastName), N' '),
                    CONCAT(N'Cliente ', c.CustomerID)),
           CASE WHEN c.StoreID IS NOT NULL THEN 'Tienda' ELSE 'Persona' END,
           c.TerritoryID,
           cr.Name, sp.Name, a.City
    FROM [$(SourceDb)].Sales.Customer c
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
      ON cr.CountryRegionCode = sp.CountryRegionCode;

    INSERT INTO dw.DimProduct
        (ProductKey, ProductName, ProductNumber,
         CategoryName, SubcategoryName, MakeFlag, ListPrice)
    SELECT p.ProductID, p.Name, p.ProductNumber, cat.Name, sub.Name,
           p.MakeFlag, p.ListPrice
    FROM [$(SourceDb)].Production.Product p
    LEFT JOIN [$(SourceDb)].Production.ProductSubcategory sub
      ON sub.ProductSubcategoryID = p.ProductSubcategoryID
    LEFT JOIN [$(SourceDb)].Production.ProductCategory cat
      ON cat.ProductCategoryID = sub.ProductCategoryID;

    INSERT INTO dw.DimLocation(LocationKey, LocationName)
    SELECT LocationID, Name
    FROM [$(SourceDb)].Production.Location;

    INSERT INTO dw.DimVendor(VendorKey, VendorName)
    SELECT BusinessEntityID, Name
    FROM [$(SourceDb)].Purchasing.Vendor;

    INSERT INTO dw.DimSalesPerson
        (SalesPersonKey, SalesPersonName, TerritoryKey)
    SELECT s.BusinessEntityID,
           CONCAT(p.FirstName, N' ', p.LastName),
           s.TerritoryID
    FROM [$(SourceDb)].Sales.SalesPerson s
    INNER JOIN [$(SourceDb)].Person.Person p
      ON p.BusinessEntityID = s.BusinessEntityID;

    INSERT INTO dw.FactSales
        (SalesOrderId, SalesOrderDetailId, OrderDateKey,
         CustomerKey, ProductKey, TerritoryKey, SalesPersonKey,
         ShipToAddressId, OnlineOrderFlag, OrderQty, UnitPrice,
         UnitPriceDiscount, SalesAmount, DiscountAmount)
    SELECT h.SalesOrderID, d.SalesOrderDetailID,
           CONVERT(int, CONVERT(char(8), h.OrderDate, 112)),
           h.CustomerID, d.ProductID, h.TerritoryID, h.SalesPersonID,
           h.ShipToAddressID, h.OnlineOrderFlag, d.OrderQty,
           d.UnitPrice, d.UnitPriceDiscount, d.LineTotal,
           CONVERT(money, d.UnitPrice * d.OrderQty * d.UnitPriceDiscount)
    FROM [$(SourceDb)].Sales.SalesOrderDetail d
    INNER JOIN [$(SourceDb)].Sales.SalesOrderHeader h
      ON h.SalesOrderID = d.SalesOrderID;

    INSERT INTO dw.FactWorkOrder
        (WorkOrderId, ProductKey, StartDateKey, EndDateKey, DueDateKey,
         ScrapReasonId, OrderQty, ScrappedQty, CompletedFlag, LateFlag)
    SELECT w.WorkOrderID, w.ProductID,
           CONVERT(int, CONVERT(char(8), w.StartDate, 112)),
           CASE WHEN w.EndDate IS NOT NULL
                THEN CONVERT(int, CONVERT(char(8), w.EndDate, 112)) END,
           CONVERT(int, CONVERT(char(8), w.DueDate, 112)),
           w.ScrapReasonID, w.OrderQty, w.ScrappedQty,
           CASE WHEN w.EndDate IS NULL THEN 0 ELSE 1 END,
           CASE WHEN w.EndDate > w.DueDate THEN 1 ELSE 0 END
    FROM [$(SourceDb)].Production.WorkOrder w;

    INSERT INTO dw.FactInventory
        (SnapshotDateKey, ProductKey, LocationKey, Shelf, Bin, Quantity)
    SELECT CONVERT(int, CONVERT(char(8), SYSUTCDATETIME(), 112)),
           i.ProductID, i.LocationID, i.Shelf, i.Bin, i.Quantity
    FROM [$(SourceDb)].Production.ProductInventory i;

    INSERT INTO dw.FactRouting
        (WorkOrderId, OperationSequence, ProductKey, LocationKey,
         ScheduledStartDateKey, PlannedHours, ActualHours,
         PlannedCost, ActualCost)
    SELECT r.WorkOrderID, r.OperationSequence, r.ProductID, r.LocationID,
           CONVERT(int, CONVERT(char(8), r.ScheduledStartDate, 112)),
           CONVERT(decimal(18,2),
               DATEDIFF(minute, r.ScheduledStartDate, r.ScheduledEndDate) / 60.0),
           CONVERT(decimal(18,2), r.ActualResourceHrs),
           r.PlannedCost, r.ActualCost
    FROM [$(SourceDb)].Production.WorkOrderRouting r;

    INSERT INTO dw.FactPurchase
        (PurchaseOrderId, PurchaseOrderDetailId, OrderDateKey,
         VendorKey, ProductKey, OrderQty, ReceivedQty,
         RejectedQty, PurchaseAmount)
    SELECT h.PurchaseOrderID, d.PurchaseOrderDetailID,
           CONVERT(int, CONVERT(char(8), h.OrderDate, 112)),
           h.VendorID, d.ProductID, d.OrderQty, d.ReceivedQty,
           d.RejectedQty, d.LineTotal
    FROM [$(SourceDb)].Purchasing.PurchaseOrderDetail d
    INNER JOIN [$(SourceDb)].Purchasing.PurchaseOrderHeader h
      ON h.PurchaseOrderID = d.PurchaseOrderID;

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
