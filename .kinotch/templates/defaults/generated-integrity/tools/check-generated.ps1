param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$configPath = Join-Path $Root "generated-integrity.json"
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Error "generated-integrity.json is missing"
    exit 1
}
$config = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json
if ([int]$config.schema_version -ne 1 -or [string]$config.algorithm -ne "SHA-256") {
    Write-Error "Unsupported generated-integrity configuration"
    exit 1
}

$failed = $false
foreach ($entry in @($config.entries)) {
    $artifact = Join-Path $Root ([string]$entry.artifact)
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
        Write-Error "Generated artifact is missing: $($entry.artifact)"
        $failed = $true
        continue
    }
    if ([string]$entry.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        Write-Error "Generated artifact hash is missing or invalid: $($entry.artifact)"
        $failed = $true
        continue
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifact).Hash.ToLowerInvariant()
    if ($actual -ne ([string]$entry.sha256).ToLowerInvariant()) {
        Write-Error "Generated artifact is stale: $($entry.artifact)"
        $failed = $true
    }
}

if ($failed) { exit 1 }
Write-Output "Generated integrity: OK ($(@($config.entries).Count) artifact(s))"
exit 0
