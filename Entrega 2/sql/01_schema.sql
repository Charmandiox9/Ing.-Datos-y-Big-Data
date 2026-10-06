USE [$(TargetDb)];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dw')
BEGIN
    EXEC(N'CREATE SCHEMA dw');
END;
GO

IF OBJECT_ID(N'dw.EtlRun', N'U') IS NULL
CREATE TABLE dw.EtlRun (
    RunId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SourceDatabase sysname NOT NULL,
    StartedAt datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    FinishedAt datetime2(0) NULL,
    Status varchar(20) NOT NULL,
    ErrorMessage nvarchar(4000) NULL
);

IF OBJECT_ID(N'dw.DimDate', N'U') IS NULL
CREATE TABLE dw.DimDate (
    DateKey int NOT NULL PRIMARY KEY,
    CalendarDate date NOT NULL UNIQUE,
    CalendarYear smallint NOT NULL,
    CalendarQuarter tinyint NOT NULL,
    CalendarMonth tinyint NOT NULL,
    MonthNameSpanish nvarchar(20) NOT NULL,
    YearMonth char(7) NOT NULL
);

IF OBJECT_ID(N'dw.DimTerritory', N'U') IS NULL
CREATE TABLE dw.DimTerritory (
    TerritoryKey int NOT NULL PRIMARY KEY,
    TerritoryName nvarchar(50) NOT NULL,
    TerritoryGroup nvarchar(50) NULL,
    CountryRegionCode nvarchar(3) NULL
);

IF OBJECT_ID(N'dw.DimCustomer', N'U') IS NULL
CREATE TABLE dw.DimCustomer (
    CustomerKey int NOT NULL PRIMARY KEY,
    CustomerName nvarchar(200) NOT NULL,
    CustomerType varchar(20) NOT NULL,
    TerritoryKey int NULL,
    CountryName nvarchar(50) NULL,
    StateProvinceName nvarchar(50) NULL,
    City nvarchar(30) NULL
);

IF OBJECT_ID(N'dw.DimProduct', N'U') IS NULL
CREATE TABLE dw.DimProduct (
    ProductKey int NOT NULL PRIMARY KEY,
    ProductName nvarchar(50) NOT NULL,
    ProductNumber nvarchar(25) NOT NULL,
    CategoryName nvarchar(50) NULL,
    SubcategoryName nvarchar(50) NULL,
    MakeFlag bit NOT NULL,
    ListPrice money NOT NULL
);

IF OBJECT_ID(N'dw.DimLocation', N'U') IS NULL
CREATE TABLE dw.DimLocation (
    LocationKey smallint NOT NULL PRIMARY KEY,
    LocationName nvarchar(50) NOT NULL
);

IF OBJECT_ID(N'dw.DimVendor', N'U') IS NULL
CREATE TABLE dw.DimVendor (
    VendorKey int NOT NULL PRIMARY KEY,
    VendorName nvarchar(50) NOT NULL
);

IF OBJECT_ID(N'dw.DimSalesPerson', N'U') IS NULL
CREATE TABLE dw.DimSalesPerson (
    SalesPersonKey int NOT NULL PRIMARY KEY,
    SalesPersonName nvarchar(200) NOT NULL,
    TerritoryKey int NULL
);

IF OBJECT_ID(N'dw.FactSales', N'U') IS NULL
CREATE TABLE dw.FactSales (
    SalesOrderId int NOT NULL,
    SalesOrderDetailId int NOT NULL,
    OrderDateKey int NOT NULL,
    CustomerKey int NOT NULL,
    ProductKey int NOT NULL,
    TerritoryKey int NULL,
    SalesPersonKey int NULL,
    ShipToAddressId int NULL,
    OnlineOrderFlag bit NOT NULL,
    OrderQty smallint NOT NULL,
    UnitPrice money NOT NULL,
    UnitPriceDiscount money NOT NULL,
    SalesAmount money NOT NULL,
    DiscountAmount money NOT NULL,
    CONSTRAINT PK_FactSales PRIMARY KEY (SalesOrderId, SalesOrderDetailId)
);

IF OBJECT_ID(N'dw.FactWorkOrder', N'U') IS NULL
CREATE TABLE dw.FactWorkOrder (
    WorkOrderId int NOT NULL PRIMARY KEY,
    ProductKey int NOT NULL,
    StartDateKey int NOT NULL,
    EndDateKey int NULL,
    DueDateKey int NOT NULL,
    ScrapReasonId smallint NULL,
    OrderQty int NOT NULL,
    ScrappedQty smallint NOT NULL,
    CompletedFlag bit NOT NULL,
    LateFlag bit NOT NULL
);

IF OBJECT_ID(N'dw.FactInventory', N'U') IS NULL
CREATE TABLE dw.FactInventory (
    SnapshotDateKey int NOT NULL,
    ProductKey int NOT NULL,
    LocationKey smallint NOT NULL,
    Shelf nvarchar(10) NOT NULL,
    Bin tinyint NOT NULL,
    Quantity smallint NOT NULL,
    CONSTRAINT PK_FactInventory PRIMARY KEY
        (SnapshotDateKey, ProductKey, LocationKey, Shelf, Bin)
);

IF OBJECT_ID(N'dw.FactRouting', N'U') IS NULL
CREATE TABLE dw.FactRouting (
    WorkOrderId int NOT NULL,
    OperationSequence smallint NOT NULL,
    ProductKey int NOT NULL,
    LocationKey smallint NOT NULL,
    ScheduledStartDateKey int NOT NULL,
    PlannedHours decimal(18,2) NOT NULL,
    ActualHours decimal(18,2) NOT NULL,
    PlannedCost money NOT NULL,
    ActualCost money NOT NULL,
    CONSTRAINT PK_FactRouting PRIMARY KEY (WorkOrderId, OperationSequence)
);

IF OBJECT_ID(N'dw.FactPurchase', N'U') IS NULL
CREATE TABLE dw.FactPurchase (
    PurchaseOrderId int NOT NULL,
    PurchaseOrderDetailId int NOT NULL,
    OrderDateKey int NOT NULL,
    VendorKey int NOT NULL,
    ProductKey int NOT NULL,
    OrderQty smallint NOT NULL,
    ReceivedQty decimal(8,2) NOT NULL,
    RejectedQty decimal(8,2) NOT NULL,
    PurchaseAmount money NOT NULL,
    CONSTRAINT PK_FactPurchase PRIMARY KEY
        (PurchaseOrderId, PurchaseOrderDetailId)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_Date'
    AND object_id = OBJECT_ID(N'dw.FactSales'))
    CREATE INDEX IX_FactSales_Date ON dw.FactSales(OrderDateKey)
        INCLUDE (SalesAmount, OrderQty, CustomerKey, ProductKey, TerritoryKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_Customer'
    AND object_id = OBJECT_ID(N'dw.FactSales'))
    CREATE INDEX IX_FactSales_Customer ON dw.FactSales(CustomerKey)
        INCLUDE (SalesAmount, SalesOrderId, OrderDateKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_Product'
    AND object_id = OBJECT_ID(N'dw.FactSales'))
    CREATE INDEX IX_FactSales_Product ON dw.FactSales(ProductKey)
        INCLUDE (SalesAmount, OrderQty, OrderDateKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactWorkOrder_Date'
    AND object_id = OBJECT_ID(N'dw.FactWorkOrder'))
    CREATE INDEX IX_FactWorkOrder_Date ON dw.FactWorkOrder(StartDateKey, ProductKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactPurchase_Date'
    AND object_id = OBJECT_ID(N'dw.FactPurchase'))
    CREATE INDEX IX_FactPurchase_Date ON dw.FactPurchase(OrderDateKey, VendorKey);
GO
