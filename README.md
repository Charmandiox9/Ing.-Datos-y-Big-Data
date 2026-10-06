# Ingeniería de Datos y Big Data

Proyecto de reportabilidad ETL para Adventure Works Cycles.

## Requisitos de la Entrega 1

La Entrega 1 considera:

- Diseño de los reportes solicitados.
- Base de datos transaccional implementada y operativa.
- Arquitectura de la solución tomada desde el documento del curso.

La arquitectura no se desarrolla nuevamente en este repositorio porque se utilizará la arquitectura definida en el PDF del proyecto.

## Prerrequisitos

Instalar y tener disponibles:

1. **Docker Desktop**, con el motor Docker iniciado.
2. **SQL Server Management Studio (SSMS)** para conectarse al servidor y revisar la base de datos.
3. **Git**, si se desea clonar o actualizar el repositorio.
4. PowerShell para ejecutar el script de restauración incluido.

## Estructura principal

```text
.
├── AdventureWorks2022.bak
├── docker-compose.yml
├── restaurar-adventureworks.ps1
├── Entrega 1/
│   └── Entrega_1_Diseno_Reportes.md
├── Entrega 2/
│   ├── ejecutar-etl.ps1
│   ├── sql/
│   └── Diseno_Final_Reportes.md
└── Entrega 3/
```

## Orden recomendado de ejecución

Realizar las actividades en este orden:

1. Instalar los prerrequisitos.
2. Clonar el repositorio o abrir la carpeta del proyecto.
3. Iniciar Docker Desktop.
4. Levantar el contenedor de SQL Server.
5. Restaurar la base de datos desde el archivo `.bak`.
6. Conectarse desde SSMS.
7. Verificar que `AdventureWorks2022` esté operativa.
8. Ejecutar el ETL para crear y cargar `AdventureWorksDW`.
9. Comprobar la carga y las vistas desde SSMS.
10. Revisar los diseños de reportes de las Entregas 1 y 2.

## 1. Obtener el proyecto

```powershell
git clone https://github.com/Charmandiox9/Ing.-Datos-y-Big-Data.git
cd Ing.-Datos-y-Big-Data
```

Si la carpeta ya existe, abrir una terminal dentro de ella.

## 2. Levantar el contenedor de SQL Server

Desde la raíz del proyecto, con Docker Desktop iniciado:

```powershell
docker compose up -d
```

Comprobar el estado:

```powershell
docker compose ps
```

El contenedor esperado es `adventureworks-sqlserver` y debe aparecer con estado `Up`.

El servicio utiliza SQL Server 2022 Developer y publica el puerto `1433` del contenedor en el puerto `1433` del equipo local.

## 3. Restaurar la base de datos

El respaldo debe estar en la raíz del proyecto con este nombre:

```text
AdventureWorks2022.bak
```

El archivo `.bak` se mantiene como recurso local y está excluido mediante `.gitignore` porque su tamaño supera el límite normal de archivos de GitHub. Después de clonar el repositorio, copiar manualmente `AdventureWorks2022.bak` a la raíz antes de restaurar.

Ejecutar el script incluido:

```powershell
.\restaurar-adventureworks.ps1
```

Si PowerShell bloquea la ejecución de scripts, permitirla solo para la sesión actual:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\restaurar-adventureworks.ps1
```

El script:

- Levanta el contenedor si todavía no está iniciado.
- Espera a que SQL Server acepte conexiones.
- Restaura `AdventureWorks2022` si aún no existe.
- No vuelve a restaurar la base si ya está creada.

La contraseña predeterminada del usuario `sa` es:

```text
SqlServer123!
```

Esta contraseña corresponde al valor definido en `docker-compose.yml`.

## 4. Conectarse desde SQL Server Management Studio

Abrir **SQL Server Management Studio** y seleccionar **Connect → Database Engine**.

Usar los siguientes valores:

| Campo | Valor |
|---|---|
| Server type | Database Engine |
| Server name | `localhost,1433` |
| Authentication | SQL Server Authentication |
| Login | `sa` |
| Password | `SqlServer123!` |

En las opciones avanzadas de conexión, activar **Trust server certificate** si SSMS muestra un error relacionado con el certificado.

Después de conectarse:

1. Abrir **Databases**.
2. Seleccionar **AdventureWorks2022**.
3. Abrir **Tables** para revisar los esquemas `Sales`, `Production`, `Purchasing`, `Person` y `HumanResources`.

## 5. Verificar la restauración en SSMS

Abrir una consulta nueva y ejecutar:

```sql
USE AdventureWorks2022;

SELECT DB_NAME() AS BaseActual;

SELECT name, state_desc
FROM sys.databases
WHERE name = N'AdventureWorks2022';

SELECT COUNT(*) AS CantidadDeTablas
FROM sys.tables;
```

La base debe aparecer como `ONLINE` y la instalación restaurada contiene 71 tablas.

## Diseño de reportes

El diseño de los reportes está en [Entrega_1_Diseno_Reportes.md](Entrega%201/Entrega_1_Diseno_Reportes.md).

Los bocetos visuales estáticos están disponibles en [mockups/index.html](Entrega%201/mockups/index.html). El índice permite navegar entre los 15 reportes propuestos.

El contrato técnico para reproducir los mockups en Power BI está en [powerbi-mapeo.md](Entrega%201/mockups/powerbi-mapeo.md), con medidas DAX sugeridas, relaciones, campos y jerarquías.

La propuesta contiene cinco reportes para cada perspectiva:

- Clientes.
- Procesos / producción.
- Ventas.

Cada reporte define su objetivo, KPI, visuales recomendados y tablas fuente. Los reportes finales se implementarán posteriormente en Power BI.

## Entrega 2: ETL y almacén analítico

El ETL toma la base transaccional `AdventureWorks2022` como fuente y crea una base separada, `AdventureWorksDW`, para análisis. Incluye dimensiones, tablas de hechos y 15 vistas `rpt` que sirven de origen para los gráficos definidos. No modifica las tablas de la fuente.

### Ejecutar el ETL

Desde una terminal PowerShell situada en la **raíz del proyecto**:

1. Iniciar Docker Desktop y comprobar que `docker compose ps` muestra el contenedor `adventureworks-sqlserver` en ejecución.
2. Si aún no se ha restaurado la fuente, colocar `AdventureWorks2022.bak` en la raíz y ejecutar `.\restaurar-adventureworks.ps1`.
3. Ejecutar la carga:

```powershell
& '.\Entrega 2\ejecutar-etl.ps1'
```

El script levanta el contenedor si hace falta, espera a que SQL Server esté disponible y ejecuta en orden los archivos de `Entrega 2/sql`: creación de base, esquema, carga, vistas y validación. Al finalizar debe mostrar `VALIDATION_OK` y `ETL completado y validado`. Si se detiene con un error, revisar el mensaje SQL anterior; no dar por terminada la carga.

Si PowerShell bloquea el script, permitir su ejecución solo en la terminal actual y repetir el comando:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& '.\Entrega 2\ejecutar-etl.ps1'
```

Para cargar **otra base compatible en la misma instancia** (con las tablas y columnas AdventureWorks utilizadas por el ETL), indicar su nombre y, si se quiere conservar el almacén anterior, uno distinto para el destino:

```powershell
& '.\Entrega 2\ejecutar-etl.ps1' -SourceDb AdventureWorks2019 -TargetDb AdventureWorksDW2019
```

El script utiliza `MSSQL_SA_PASSWORD` si está definida; de lo contrario usa la contraseña de demostración de `docker-compose.yml`. También acepta `-Password`.

**Importante:** cada nueva ejecución hace una carga completa y reemplaza los datos de las tablas `dw` del **destino seleccionado**. No ejecutarla sobre un almacén con cambios manuales que se quieran conservar. La carga de hechos y dimensiones ocurre en una transacción: si falla, se revierte esa carga.

### Qué hacer después

1. En SSMS, conectarse a `localhost,1433` con `sa` como se indica arriba y abrir `AdventureWorksDW`.
2. Ejecutar esta consulta para revisar el último estado del ETL y confirmar que existen las 15 vistas:

```sql
USE AdventureWorksDW;

SELECT TOP (1) RunId, SourceDatabase, Status, StartedAt, FinishedAt
FROM dw.EtlRun
ORDER BY RunId DESC;

SELECT COUNT(*) AS VistasReportabilidad
FROM sys.views
WHERE schema_id = SCHEMA_ID(N'rpt');

SELECT TOP (10) * FROM rpt.V01_ResumenVentas ORDER BY YearMonth;
```

3. Comprobar que el último estado sea `SUCCEEDED`, que `VistasReportabilidad` sea `15` y que la consulta de ejemplo devuelva filas.
4. Para construir los gráficos en Power BI Desktop, conectarse al servidor `localhost,1433`, base `AdventureWorksDW`, e importar las vistas `rpt` necesarias. Seguir el [diseño final de los 15 reportes](Entrega%202/Diseno_Final_Reportes.md).

La [guía detallada de Entrega 2](Entrega%202/README.md) explica el modelo, las opciones de ejecución, la validación y la conexión a Power BI.

## Solución de problemas

### Docker no inicia

Verificar que Docker Desktop esté abierto y que el motor esté ejecutándose. Luego repetir:

```powershell
docker compose up -d
```

### El puerto 1433 está ocupado

Revisar qué aplicación utiliza el puerto o cambiar el puerto publicado en `docker-compose.yml`. Si se cambia el puerto local, usar el nuevo valor en SSMS, por ejemplo `localhost,1434`.

### SSMS no conecta por certificado

Activar **Trust server certificate** en las opciones de conexión.

### La base no aparece

Ejecutar nuevamente:

```powershell
.\restaurar-adventureworks.ps1
```
