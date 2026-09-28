param(
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string]$SourceDb = 'AdventureWorks2022',
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string]$TargetDb = 'AdventureWorksDW',
    [string]$Password = '',
    [switch]$SkipContainerStart
)

$ErrorActionPreference = 'Stop'
$containerName = 'adventureworks-sqlserver'
$containerScripts = '/var/opt/mssql/backup/Entrega 2/sql'
$scriptFolder = Join-Path $PSScriptRoot 'sql'

if (-not $Password) {
    $Password = [Environment]::GetEnvironmentVariable('MSSQL_SA_PASSWORD')
}
if (-not $Password) {
    $Password = 'SqlServer123!'
}
if (-not (Test-Path -LiteralPath $scriptFolder)) {
    throw "No existe la carpeta de scripts SQL: $scriptFolder"
}
if ($SourceDb -eq $TargetDb) {
    throw 'SourceDb y TargetDb deben ser diferentes.'
}

if (-not $SkipContainerStart) {
    docker compose -f (Join-Path $PSScriptRoot '..\docker-compose.yml') up -d
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar el contenedor.' }
}

Write-Host "Esperando el servidor SQL del contenedor..."
$ready = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    docker exec -e "SQLCMDPASSWORD=$Password" $containerName `
        /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b `
        -Q 'SELECT 1' *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw 'SQL Server no estuvo disponible a tiempo.' }

$scripts = @(
    '00_create_database.sql',
    '01_schema.sql',
    '02_load.sql',
    '03_reporting_views.sql',
    '04_validate.sql'
)

foreach ($scriptName in $scripts) {
    if (-not (Test-Path -LiteralPath (Join-Path $scriptFolder $scriptName))) {
        throw "Falta el script $scriptName"
    }
    Write-Host "Ejecutando $scriptName..."
    docker exec -e "SQLCMDPASSWORD=$Password" $containerName `
        /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b -r 1 `
        -v "SourceDb=$SourceDb" "TargetDb=$TargetDb" `
        -i "$containerScripts/$scriptName"
    if ($LASTEXITCODE -ne 0) {
        throw "Falló $scriptName. Revisa el mensaje SQL anterior."
    }
}

Write-Host "ETL completado y validado. Fuente: $SourceDb. Almacén: $TargetDb."
