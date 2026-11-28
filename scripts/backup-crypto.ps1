# Encryption for backups, using only .NET (works in Windows PowerShell 5.1 and PowerShell 7).
# File format: "ANTAMBK1" | salt (16) | IV (16) | AES-256-CBC ciphertext | HMAC-SHA256 of everything before (32).
# Keys come from the passphrase with PBKDF2-SHA256 (200,000 rounds): 32 bytes for AES, 32 for HMAC.

function Get-BackupPassphrase([string]$root) {
    $env_file = Join-Path $root ".env"
    $line = if (Test-Path $env_file) { Get-Content $env_file | Where-Object { $_ -match '^\s*BACKUP_PASSPHRASE\s*=' } | Select-Object -First 1 }
    $value = if ($line) { ($line -split '=', 2)[1].Trim() } else { "" }
    if ($value.Length -lt 16) { throw "Set BACKUP_PASSPHRASE (at least 16 characters) in .env. Keep a copy outside this laptop." }
    return $value
}

function Get-BackupKeys([string]$passphrase, [byte[]]$salt) {
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($passphrase, $salt, 200000,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $bytes = $kdf.GetBytes(64)
    $kdf.Dispose()
    return @{ Aes = $bytes[0..31]; Mac = $bytes[32..63] }
}

function Protect-BackupFile([string]$plainPath, [string]$outPath, [string]$passphrase) {
    $magic = [System.Text.Encoding]::ASCII.GetBytes("ANTAMBK1")
    $salt = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt)
    $keys = Get-BackupKeys $passphrase $salt
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = [byte[]]$keys.Aes
    $aes.GenerateIV()
    $plain = [System.IO.File]::ReadAllBytes($plainPath)
    $cipher = $aes.CreateEncryptor().TransformFinalBlock($plain, 0, $plain.Length)
    $body = New-Object System.IO.MemoryStream
    $body.Write($magic, 0, 8); $body.Write($salt, 0, 16); $body.Write($aes.IV, 0, 16); $body.Write($cipher, 0, $cipher.Length)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(,[byte[]]$keys.Mac)
    $tag = $hmac.ComputeHash($body.ToArray())
    $body.Write($tag, 0, 32)
    [System.IO.File]::WriteAllBytes($outPath, $body.ToArray())
    $aes.Dispose(); $hmac.Dispose(); $body.Dispose()
}

function Unprotect-BackupFile([string]$encPath, [string]$outPath, [string]$passphrase) {
    $all = [System.IO.File]::ReadAllBytes($encPath)
    if ($all.Length -lt 8 + 16 + 16 + 16 + 32 -or [System.Text.Encoding]::ASCII.GetString($all, 0, 8) -ne "ANTAMBK1") {
        throw "$encPath is not an An Tam backup"
    }
    $salt = $all[8..23]; $iv = $all[24..39]
    $keys = Get-BackupKeys $passphrase ([byte[]]$salt)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(,[byte[]]$keys.Mac)
    $tag = $hmac.ComputeHash($all, 0, $all.Length - 32)
    $hmac.Dispose()
    $given = $all[($all.Length - 32)..($all.Length - 1)]
    $diff = 0
    for ($i = 0; $i -lt 32; $i++) { $diff = $diff -bor ($tag[$i] -bxor $given[$i]) }
    if ($diff -ne 0) { throw "Wrong passphrase, or $encPath is damaged" }
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = [byte[]]$keys.Aes
    $aes.IV = [byte[]]$iv
    $cipherLength = $all.Length - 40 - 32
    $plain = $aes.CreateDecryptor().TransformFinalBlock($all, 40, $cipherLength)
    [System.IO.File]::WriteAllBytes($outPath, $plain)
    $aes.Dispose()
}
