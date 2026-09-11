param(
    [string]$Password = "SqlServer123!"
)

$ErrorActionPreference = "Stop"
$container = "adventureworks-sqlserver"
$backup = "/var/opt/mssql/backup/AdventureWorks2022.bak"

docker compose up -d

Write-Host "Esperando a que SQL Server esté disponible..."
for ($i = 0; $i -lt 60; $i++) {
    docker exec $container /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P $Password -Q "SELECT 1" 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
    if ($i -eq 59) { throw "SQL Server no estuvo disponible a tiempo." }
}

$query = @"
IF DB_ID(N'AdventureWorks2022') IS NULL
BEGIN
    RESTORE DATABASE [AdventureWorks2022]
    FROM DISK = N'$backup'
    WITH
        MOVE N'AdventureWorks2022' TO N'/var/opt/mssql/data/AdventureWorks2022.mdf',
        MOVE N'AdventureWorks2022_log' TO N'/var/opt/mssql/data/AdventureWorks2022_log.ldf',
        RECOVERY,
        STATS = 5;
END
ELSE
    PRINT 'AdventureWorks2022 ya está restaurada.';
GO
"@

$query | docker exec -i $container /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P $Password
if ($LASTEXITCODE -ne 0) { throw "La restauración falló." }

Write-Host "Restauración completada. Conexión: localhost,1433 / AdventureWorks2022"
