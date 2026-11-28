# Backs up the database and the medicine photos into backups\ (git-ignored: it holds family data).
#   powershell -ExecutionPolicy Bypass -File scripts\backup.ps1
# Restore: scripts\restore.ps1 (see docs/SETUP.md, "Sao lưu và khôi phục").
#
# - Files are made inside the containers and copied out with "docker compose cp", so Windows PowerShell 5.1
#   never re-encodes binary data (">" would turn it into UTF-16 and corrupt it).
# - Each file is checked (pg_restore --list, tar -tzf) before it counts as a backup.
# - Both files are encrypted with BACKUP_PASSPHRASE from .env (AES-256 + HMAC-SHA256). Keep that passphrase
#   somewhere other than this laptop: without it the backups cannot be opened.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "backup-crypto.ps1")

$passphrase = Get-BackupPassphrase $root
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$dir = Join-Path $root "backups"
New-Item -ItemType Directory -Force $dir | Out-Null
$tmpDump = Join-Path $dir "antam-$stamp.dump"
$tmpMedia = Join-Path $dir "media-$stamp.tgz"

function Invoke-Checked([string]$what, [scriptblock]$command) {
    & $command
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)" }
}

Push-Location $root
try {
    Invoke-Checked "pg_dump" { docker compose exec -T db pg_dump -U antam -d antam -Fc -f /tmp/antam.dump }
    Invoke-Checked "checking the database dump" { docker compose exec -T db sh -c "pg_restore --list /tmp/antam.dump > /dev/null" }
    Invoke-Checked "copying the database dump" { docker compose cp db:/tmp/antam.dump $tmpDump }
    docker compose exec -T db rm -f /tmp/antam.dump | Out-Null

    Invoke-Checked "packing photos" { docker compose exec -T backend tar -C /data -czf /tmp/media.tgz media }
    Invoke-Checked "checking the photo archive" { docker compose exec -T backend sh -c "tar -tzf /tmp/media.tgz > /dev/null" }
    Invoke-Checked "copying the photo archive" { docker compose cp backend:/tmp/media.tgz $tmpMedia }
    docker compose exec -T backend rm -f /tmp/media.tgz | Out-Null

    foreach ($f in @($tmpDump, $tmpMedia)) {
        if ((Get-Item $f).Length -eq 0) { throw "$f is empty" }
        Protect-BackupFile $f "$f.enc" $passphrase
        # The encrypted copy must open again before the plain one is thrown away.
        $check = "$f.check"
        Unprotect-BackupFile "$f.enc" $check $passphrase
        $same = (Get-FileHash $f).Hash -eq (Get-FileHash $check).Hash
        Remove-Item $check, $f
        if (-not $same) { throw "Encrypted copy of $f does not match" }
    }
    Write-Output "Saved and checked: antam-$stamp.dump.enc, media-$stamp.tgz.enc"

    # Keep the 14 newest of each.
    Get-ChildItem $dir -Filter "antam-*.dump.enc" | Sort-Object Name -Descending | Select-Object -Skip 14 | Remove-Item
    Get-ChildItem $dir -Filter "media-*.tgz.enc" | Sort-Object Name -Descending | Select-Object -Skip 14 | Remove-Item
} finally {
    foreach ($f in @($tmpDump, $tmpMedia)) { if (Test-Path $f) { Remove-Item $f } }
    Pop-Location
}
