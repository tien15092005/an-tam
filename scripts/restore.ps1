# Restores a backup made by backup.ps1. OVERWRITES the current database and photos.
#   powershell -ExecutionPolicy Bypass -File scripts\restore.ps1 -Stamp 20261128-1300
#   powershell -ExecutionPolicy Bypass -File scripts\restore.ps1 -Stamp 20261128-1300 -TestOnly
# -TestOnly restores into a throw-away database (antam_restore_test), counts rows, and drops it again:
# a safe way to prove a backup really opens, without touching live data.
param(
    [Parameter(Mandatory = $true)][string]$Stamp,
    [switch]$TestOnly
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "backup-crypto.ps1")
$passphrase = Get-BackupPassphrase $root
$dir = Join-Path $root "backups"
$dump = Join-Path $dir "antam-$Stamp.dump"
$media = Join-Path $dir "media-$Stamp.tgz"

function Invoke-Checked([string]$what, [scriptblock]$command) {
    & $command
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)" }
}

Push-Location $root
try {
    Unprotect-BackupFile "$dump.enc" $dump $passphrase
    Unprotect-BackupFile "$media.enc" $media $passphrase
    Invoke-Checked "copying the dump in" { docker compose cp $dump db:/tmp/restore.dump }
    if ($TestOnly) {
        docker compose exec -T db dropdb -U antam --if-exists antam_restore_test | Out-Null
        Invoke-Checked "creating the test database" { docker compose exec -T db createdb -U antam antam_restore_test }
        Invoke-Checked "restoring into the test database" {
            docker compose exec -T db pg_restore -U antam -d antam_restore_test --no-owner /tmp/restore.dump
        }
        $counts = docker compose exec -T db psql -U antam -d antam_restore_test -tAc `
            "select 'users=' || (select count(*) from users) || ' medications=' || (select count(*) from medications) || ' dose_logs=' || (select count(*) from dose_logs)"
        Invoke-Checked "dropping the test database" { docker compose exec -T db dropdb -U antam antam_restore_test }
        Invoke-Checked "checking the photo archive" { docker compose cp $media backend:/tmp/restore.tgz }
        Invoke-Checked "listing photos" { docker compose exec -T backend sh -c "tar -tzf /tmp/restore.tgz > /dev/null" }
        docker compose exec -T -u root backend rm -f /tmp/restore.tgz | Out-Null
        Write-Output "Backup $Stamp opens and restores: $counts"
    } else {
        Invoke-Checked "restoring the database" {
            docker compose exec -T db pg_restore -U antam -d antam --clean --if-exists --no-owner /tmp/restore.dump
        }
        Invoke-Checked "copying photos in" { docker compose cp $media backend:/tmp/restore.tgz }
        Invoke-Checked "restoring photos" { docker compose exec -T backend tar -C /data -xzf /tmp/restore.tgz }
        docker compose exec -T -u root backend rm -f /tmp/restore.tgz | Out-Null
        Write-Output "Restored $Stamp. Restart the backend: docker compose restart backend"
    }
    docker compose exec -T db rm -f /tmp/restore.dump | Out-Null
} finally {
    foreach ($f in @($dump, $media)) { if (Test-Path $f) { Remove-Item $f } }
    Pop-Location
}
