# Backs up the database and the medicine photos into backups\ (git-ignored: it holds family data).
#   powershell -ExecutionPolicy Bypass -File scripts\backup.ps1
# Restore: see docs/SETUP.md, "Sao lưu và khôi phục".
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$dir = Join-Path $root "backups"
New-Item -ItemType Directory -Force $dir | Out-Null
Push-Location $root
try {
    $sql = Join-Path $dir "antam-$stamp.sql"
    docker compose exec -T db pg_dump -U antam -d antam --clean --if-exists | Out-File -Encoding utf8 $sql
    if ($LASTEXITCODE -ne 0) { Write-Error "pg_dump failed"; exit 1 }
    docker compose exec -T backend tar -C /data -czf - media > (Join-Path $dir "media-$stamp.tgz")
    Write-Output "Saved $sql and media-$stamp.tgz"
    # Keep the 14 newest of each.
    Get-ChildItem $dir -Filter "antam-*.sql" | Sort-Object Name -Descending | Select-Object -Skip 14 | Remove-Item
    Get-ChildItem $dir -Filter "media-*.tgz" | Sort-Object Name -Descending | Select-Object -Skip 14 | Remove-Item
} finally {
    Pop-Location
}
