param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbName = "banay",
    [string]$DbUser = "postgres",
    [string]$DbPassword = "postgres",
    [switch]$StartBackend
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-PostgresBinPath {
    $psql = Get-Command psql -ErrorAction SilentlyContinue
    if ($psql) {
        return Split-Path -Parent $psql.Path
    }

    $candidates = @(
        "C:\Program Files\PostgreSQL\17\bin",
        "C:\Program Files\PostgreSQL\16\bin",
        "C:\Program Files\PostgreSQL\15\bin",
        "C:\Program Files\PostgreSQL\14\bin"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate "psql.exe")) {
            return $candidate
        }
    }

    throw "PostgreSQL n'est pas detecte. Installe PostgreSQL puis relance ce script."
}

function Ensure-PostgresServiceRunning {
    $service = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "postgres" -or $_.DisplayName -match "Postgre" } |
        Select-Object -First 1

    if (-not $service) {
        Write-Host "Aucun service PostgreSQL Windows detecte. Je continue quand meme avec les binaires." -ForegroundColor Yellow
        return
    }

    if ($service.Status -ne "Running") {
        Write-Step "Demarrage du service $($service.Name)"
        Start-Service -Name $service.Name
        $service.WaitForStatus("Running", "00:00:20")
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendRoot = Split-Path -Parent $scriptRoot

Write-Step "Detection de PostgreSQL"
$postgresBin = Get-PostgresBinPath
$env:PATH = "$postgresBin;$env:PATH"
$env:PGPASSWORD = $DbPassword

Ensure-PostgresServiceRunning

Write-Step "Creation de la base si necessaire"
$databaseExists = & psql -h $DbHost -p $DbPort -U $DbUser -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DbName';"
if (($databaseExists | Out-String).Trim() -ne "1") {
    & createdb -h $DbHost -p $DbPort -U $DbUser $DbName
}

Write-Step "Prisma db push"
Push-Location $backendRoot
try {
    npm run prisma:push

    Write-Step "Prisma seed"
    npm run prisma:seed

    if ($StartBackend) {
        Write-Step "Demarrage du backend"
        npm run start:dev
    }
}
finally {
    Pop-Location
}