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
8. Revisar el diseño de los reportes en `Entrega 1/Entrega_1_Diseno_Reportes.md`.

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
