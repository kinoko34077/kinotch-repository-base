$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$SourceScript = Join-Path $RepoRoot ".kinotch/scripts/update-base-index.ps1"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-base-refresh-integrity-" + [guid]::NewGuid().ToString("N"))
$TempScripts = Join-Path $TempRoot ".kinotch/scripts"

New-Item -ItemType Directory -Path $TempScripts -Force | Out-Null
try {
    Copy-Item -LiteralPath $SourceScript -Destination (Join-Path $TempScripts "update-base-index.ps1") -Force

    $threw = $false
    try {
        . (Join-Path $TempScripts "update-base-index.ps1")
    }
    catch {
        $threw = $true
        if ($_.Exception.Message -notmatch "path-containment|containment") {
            throw "missing path-containment helper failed for the wrong reason: $($_.Exception.Message)"
        }
    }

    if (-not $threw) {
        throw "update-base-index.ps1 loaded without path-containment.ps1; Base integrity protection failed open"
    }

    Write-Host "[PASS] base-refresh fails closed when path-containment helper is missing" -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
