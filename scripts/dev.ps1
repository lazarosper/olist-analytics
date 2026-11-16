# Start a working session (PowerShell, from the repository root):
#
#     .\scripts\dev.ps1
#
# 1. activates the Python virtual environment, so `dbt` is this project's dbt
# 2. checks that the connection settings exist (they are never stored in the repo)
# 3. hides Python deprecation notices printed by the Snowflake driver

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot '.venv\Scripts\Activate.ps1')

$required = 'SNOWFLAKE_ACCOUNT', 'SNOWFLAKE_USER', 'SNOWFLAKE_PRIVATE_KEY_PATH', 'OLIST_PII_SALT'
$missing = @()
foreach ($name in $required) {
    if (-not (Test-Path "Env:$name")) {
        # A terminal opened before the variable was saved does not see it yet:
        # read it from the Windows user settings.
        $value = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($value) { Set-Item -Path "Env:$name" -Value $value } else { $missing += $name }
    }
}

$env:PYTHONWARNINGS = 'ignore'

if ($missing.Count -gt 0) {
    Write-Host "Missing environment variables: $($missing -join ', ')" -ForegroundColor Red
    Write-Host 'Set them (see README, "Run it") before running dbt.' -ForegroundColor Red
}
else {
    $dbtPath = (Get-Command dbt).Source
    Write-Host "Ready. dbt = $dbtPath" -ForegroundColor Green
    Write-Host 'Default target: dev (ANALYTICS_DEV). Try: dbt debug' -ForegroundColor Green
}
