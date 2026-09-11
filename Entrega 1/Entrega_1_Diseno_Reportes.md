# Entrega 1 - Diseño de reportes

## Alcance

Este documento cubre el diseño de los reportes solicitados para el proyecto de reportabilidad de Adventure Works Cycles. La arquitectura de la solución se toma desde el PDF entregado por el curso y no se modifica en este documento.

La propuesta contempla 15 reportes: cinco de clientes, cinco de procesos/producción y cinco de ventas.

## Requisito de cumplimiento

| Perspectiva | Cantidad solicitada | Cantidad propuesta |
|---|---:|---:|
| Clientes | Al menos 5 | 5 |
| Procesos / producción | Al menos 5 | 5 |
| Ventas | Al menos 5 | 5 |
| **Total** | **Al menos 15** | **15** |

## Criterio visual común

Cada reporte se implementará posteriormente como una página sencilla de Power BI con:

- Tres o cuatro tarjetas KPI en la parte superior.
- Un gráfico principal para identificar tendencias o comparaciones.
- Una tabla de detalle para poder revisar el dato detrás del indicador.
- Filtros por fecha, territorio, categoría y producto cuando corresponda.
- Navegación entre perspectivas y, cuando sea posible, Drill Down desde categoría a subcategoría y producto.

El período disponible en ventas es de mayo de 2011 a junio de 2014. Las fechas deben mostrarse explícitamente para evitar interpretar los datos como información actual.

---

## Perspectiva 1: Clientes

### C1. Perfil de clientes

**Objetivo:** conocer la composición de la cartera de clientes.

**KPI:** clientes totales, clientes individuales, clientes empresa/tienda y porcentaje de cada tipo.

**Visuales:** tarjeta de clientes totales, gráfico de dona por tipo de cliente, barras por territorio y tabla de clientes.

**Fuentes principales:** `Sales.Customer`, `Person.Person`, `Sales.Store`, `Sales.SalesTerritory`.

### C2. Ventas por cliente

**Objetivo:** identificar los clientes que generan más ingresos.

**KPI:** ventas totales, cantidad de órdenes, ticket promedio y participación del Top 10.

**Visuales:** barras Top 10 clientes, tabla con cliente/órdenes/ventas/ticket promedio y segmentadores por año y territorio.

**Fuentes principales:** `Sales.Customer`, `Sales.SalesOrderHeader`, `Sales.SalesOrderDetail`, `Person.Person`.

### C3. Frecuencia y fidelidad

**Objetivo:** distinguir clientes frecuentes de clientes ocasionales.

**KPI:** órdenes promedio por cliente, clientes recurrentes, clientes de una sola compra y días promedio entre compras.

**Visuales:** distribución de clientes por cantidad de órdenes, barras de frecuencia por territorio y tabla de clientes recurrentes.

**Fuentes principales:** `Sales.Customer`, `Sales.SalesOrderHeader`.

### C4. Distribución geográfica de clientes

**Objetivo:** comparar la presencia de clientes y su aporte por ubicación.

**KPI:** clientes, órdenes y ventas por país, estado/provincia y territorio.

**Visuales:** mapa o matriz geográfica, barras por territorio y tabla país/estado/ventas/clientes.

**Fuentes principales:** `Sales.Customer`, `Person.Address`, `Person.StateProvince`, `Person.CountryRegion`, `Sales.SalesTerritory`.

### C5. Clientes sin actividad reciente

**Objetivo:** detectar clientes que requieren acciones comerciales o de retención.

**KPI:** clientes sin órdenes, clientes con última compra antigua y ventas históricas de esos clientes.

**Visuales:** tabla priorizada por fecha de última compra, barras por territorio y filtros por período de inactividad.

**Fuentes principales:** `Sales.Customer`, `Sales.SalesOrderHeader`, `Person.Person`, `Sales.SalesTerritory`.

---

## Perspectiva 2: Procesos / producción

### P1. Producción por producto y categoría

**Objetivo:** observar qué productos concentran la actividad productiva.

**KPI:** órdenes de trabajo, unidades a producir, unidades rechazadas y tasa de rechazo.

**Visuales:** barras por categoría/subcategoría, línea mensual de unidades producidas y tabla por producto.

**Fuentes principales:** `Production.WorkOrder`, `Production.Product`, `Production.ProductSubcategory`, `Production.ProductCategory`.

### P2. Inventario por ubicación

**Objetivo:** conocer la disponibilidad de productos y detectar concentraciones de inventario.

**KPI:** unidades en inventario, productos con inventario y cantidad por ubicación.

**Visuales:** barras por ubicación, matriz producto/ubicación y tabla de productos con menor stock.

**Fuentes principales:** `Production.ProductInventory`, `Production.Product`, `Production.Location`.

### P3. Cumplimiento de órdenes de trabajo

**Objetivo:** medir si las órdenes de producción se terminan dentro del plazo.

**KPI:** órdenes terminadas, órdenes atrasadas, días promedio de ejecución y porcentaje de cumplimiento.

**Visuales:** tarjetas de cumplimiento, columnas a tiempo/atrasadas, tendencia mensual y tabla de órdenes atrasadas.

**Fuentes principales:** `Production.WorkOrder`, `Production.Product`.

### P4. Eficiencia de las rutas productivas

**Objetivo:** comparar horas y costos planificados contra los valores reales.

**KPI:** horas planificadas, horas reales, desviación de horas, costo planificado, costo real y desviación porcentual.

**Visuales:** gráfico planificado versus real por ubicación, barras de desviación y tabla de operaciones críticas.

**Fuentes principales:** `Production.WorkOrderRouting`, `Production.WorkOrder`, `Production.Location`.

### P5. Abastecimiento y proveedores

**Objetivo:** controlar las compras que apoyan la operación productiva.

**KPI:** órdenes de compra, monto comprado, unidades adquiridas y proveedores activos.

**Visuales:** compras por proveedor, tendencia mensual de compras, barras por producto y tabla de proveedores.

**Fuentes principales:** `Purchasing.PurchaseOrderHeader`, `Purchasing.PurchaseOrderDetail`, `Purchasing.Vendor`, `Production.Product`.

---

## Perspectiva 3: Ventas

### V1. Resumen ejecutivo de ventas

**Objetivo:** entregar una vista general del desempeño comercial.

**KPI:** ventas totales, órdenes, unidades vendidas, ticket promedio y flete/impuestos.

**Visuales:** tarjetas KPI, línea de ventas por mes, barras por categoría y tabla resumen anual.

**Fuentes principales:** `Sales.SalesOrderHeader`, `Sales.SalesOrderDetail`, `Production.Product`.

### V2. Ventas por territorio

**Objetivo:** comparar el rendimiento comercial de las regiones.

**KPI:** ventas, órdenes, unidades y variación por territorio.

**Visuales:** barras por territorio/grupo regional, mapa cuando corresponda, línea temporal y tabla de detalle.

**Fuentes principales:** `Sales.SalesOrderHeader`, `Sales.SalesTerritory`, `Sales.SalesOrderDetail`.

### V3. Ventas por producto y categoría

**Objetivo:** identificar los productos y categorías más importantes para el negocio.

**KPI:** ventas, unidades, precio promedio, descuento y participación porcentual.

**Visuales:** Top 10 productos, treemap por categoría, barras por subcategoría y tabla de productos.

**Fuentes principales:** `Sales.SalesOrderDetail`, `Sales.SalesOrderHeader`, `Production.Product`, `Production.ProductSubcategory`, `Production.ProductCategory`.

### V4. Ventas online versus ventas de distribuidor

**Objetivo:** comparar los canales comerciales disponibles en la fuente.

**KPI:** ventas online, ventas no online, porcentaje online, órdenes y ticket promedio por canal.

**Visuales:** dona por canal, columnas mensuales por canal y tabla comparativa.

**Fuentes principales:** `Sales.SalesOrderHeader`, `Sales.SalesOrderDetail`.

### V5. Desempeño de vendedores

**Objetivo:** analizar la contribución de cada vendedor y su evolución.

**KPI:** ventas por vendedor, órdenes, clientes atendidos y comparación con ventas del año anterior/cuota cuando exista información.

**Visuales:** ranking de vendedores, barras de ventas, tendencia temporal y tabla vendedor/ventas/órdenes/clientes.

**Fuentes principales:** `Sales.SalesPerson`, `Sales.SalesOrderHeader`, `Sales.SalesOrderDetail`, `Sales.SalesPersonQuotaHistory`.

---

## Filtros recomendados

- Año y mes de la orden.
- Territorio y grupo regional.
- Categoría y subcategoría.
- Producto.
- Canal online/no online.
- Cliente.
- Vendedor.

## Funcionalidad adicional bonificable

Agregar Drill Down en los reportes de ventas y producción con esta jerarquía:

- Territorio → país/estado → ciudad.
- Categoría → subcategoría → producto.
- Año → trimestre → mes.
- Orden de trabajo → operación/ruta.

## Criterio de aceptación de la Entrega 1

- La base transaccional `AdventureWorks2022` está restaurada y operativa.
- La arquitectura usada corresponde a la del PDF del curso.
- Existen cinco diseños de reportes por cada perspectiva.
- Cada diseño define objetivo, indicadores, visuales y fuentes de datos.
- Se deja indicado que los reportes finales se implementarán en Power BI.
