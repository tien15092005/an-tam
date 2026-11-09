# Builds the debug APK on Windows when "Long Paths" is off (docs/SETUP.md).
#
# Android's desugaring writes files with very long names (image_picker and others) under each plugin's
# build/.transforms folder. Past 260 characters Gradle can create them but not delete them, so the next
# build fails with "Unable to delete directory". This removes those folders with the \\?\ long-path
# prefix first. Not needed once LongPathsEnabled = 1.
#
# Even with long paths on, Gradle and the Flutter tool sometimes fail to delete stale intermediates on this
# machine (a different folder each time). Stopping the Gradle daemon and starting from empty intermediates
# avoids that, at the cost of a full build (about 3 minutes).
param([string]$Mode = "debug")

# Native tools write warnings to stderr; Windows PowerShell would treat them as errors. Exit codes decide.
$ErrorActionPreference = "Continue"
$app = Split-Path -Parent $PSScriptRoot
$build = Join-Path $app "build"
if (Test-Path $build) {
    $real = (Get-Item $build).Target
    if (-not $real) { $real = $build } elseif ($real -is [array]) { $real = $real[0] }
    Get-ChildItem $real -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $t = Join-Path $_.FullName ".transforms"
        if (Test-Path -LiteralPath $t) { cmd /c "rd /s /q `"\\?\$t`"" | Out-Null }
    }
    $inter = Join-Path $real "app\intermediates"
    if (Test-Path -LiteralPath $inter) {
        & (Join-Path $app "android\gradlew.bat") -p (Join-Path $app "android") --stop | Out-Null
        cmd /c "rd /s /q `"\\?\$inter`"" | Out-Null
    }
}
Push-Location $app
try {
    flutter.bat build apk "--$Mode"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
