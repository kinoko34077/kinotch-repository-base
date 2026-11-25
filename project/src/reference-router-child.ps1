# Trusted host child; payload is written only by the admitted session adapter.
param([Parameter(Mandatory=$true)][string]$PayloadPath)
$ErrorActionPreference = "Stop"
try {
    $packet = Get-Content -LiteralPath $PayloadPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $forward = [string[]]@($packet.arguments)
    $global:LASTEXITCODE = $null
    & $packet.router -RootOverride $packet.consumer -BaseOverride $packet.base -ReferenceMode -Command $packet.command -RemainingArgs $forward
    if ($null -eq $LASTEXITCODE) { exit 1 }
    exit ([int]$LASTEXITCODE)
}
catch {
    Write-Host "[reference-router] Invocation failed" -ForegroundColor Red
    exit 1
}
