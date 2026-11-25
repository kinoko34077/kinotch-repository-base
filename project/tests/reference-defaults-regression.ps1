# Real router / actual catalog, no consumer repository or network writes.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Base = Join-Path $RepoRoot ".kinotch"
$Router = Join-Path $Base "scripts/knt.ps1"
$HostExe = (Get-Process -Id $PID).Path
$Temp = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-reference-defaults-" + [guid]::NewGuid().ToString("N"))
$Consumer = Join-Path $Temp "consumer"
New-Item -ItemType Directory -Path $Consumer | Out-Null
function Write-Json($Path,$Data) {
    [IO.File]::WriteAllText($Path,($Data | ConvertTo-Json -Depth 20),(New-Object System.Text.UTF8Encoding($false)))
}
function Run-Router([string[]]$Arguments,[int]$Expected,[switch]$Legacy) {
    $flags = @("-RootOverride",$Consumer,"-BaseOverride",$Base)
    if (-not $Legacy) { $flags += "-ReferenceMode" }
    $output = @(& $HostExe -NoProfile -ExecutionPolicy Bypass -File $Router @flags @Arguments 2>&1)
    if ($LASTEXITCODE -ne $Expected) { throw "Unexpected router exit: $LASTEXITCODE / $($output -join ' ')" }
    return ($output -join [Environment]::NewLine)
}
try {
    Copy-Item -LiteralPath (Join-Path $Base "tests/fixtures/valid-minimal") -Destination (Join-Path $Consumer "project") -Recurse
    $manifestPath = Join-Path $Consumer "project/project.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest.paths | Add-Member -NotePropertyName defaults -NotePropertyValue "defaults.json"
    Write-Json $manifestPath $manifest
    $defaultsPath = Join-Path $Consumer "project/defaults.json"
    $defaults = @{schema_version=1; packs=@{config=@{state="DEFAULT"}; logging=@{state="DISABLED"}}}
    Write-Json $defaultsPath $defaults
    Run-Router @("doctor") 0 | Out-Null
    Run-Router @("doctor") 1 -Legacy | Out-Null
    $packet = Run-Router @("reference-path","config","logging") 0 | ConvertFrom-Json
    if (@($packet.references).Count -ne 2 -or $packet.references[0].state -cne "DEFAULT" -or
        $packet.references[0].path -cne (Join-Path $Base "templates/defaults/config/tools/config-default.ps1") -or
        $packet.references[1].state -cne "DISABLED" -or $null -ne $packet.references[1].path) { throw "Wrong reference paths" }
    . $packet.references[0].path
    $merged = Merge-KntConfigMaps -Maps @(@{value=1},@{value=2})
    if ($merged.value -ne 2) { throw "Central helper did not execute" }
    if (Test-Path -LiteralPath (Join-Path $Consumer ".kinotch")) { throw "Base materialized in consumer" }
    if (Test-Path -LiteralPath (Join-Path $Consumer "project/tools/config-default.ps1")) { throw "Helper materialized in consumer" }
    Run-Router @("reference-path","config") 2 -Legacy | Out-Null
    Run-Router @("reference-path","unknown-pack") 2 | Out-Null
    Run-Router @("reference-path","api") 2 | Out-Null

    $toolsPath = Join-Path $Consumer "project/tools"
    New-Item -ItemType Directory -Path $toolsPath | Out-Null
    $override = Join-Path $toolsPath "config-default.ps1"
    [IO.File]::WriteAllText($override,"function Get-LocalOverride { 'local' }")
    $out = Run-Router @("doctor") 1
    if ($out -notmatch "local helper") { throw "Legacy conflict not diagnosed" }
    Run-Router @("reference-path","config") 2 | Out-Null
    $defaults.packs.config.state = "OVERRIDE"
    Write-Json $defaultsPath $defaults
    $packet = Run-Router @("reference-path","config") 0 | ConvertFrom-Json
    if ($packet.references[0].state -cne "OVERRIDE" -or $packet.references[0].path -cne $override) { throw "Override not preserved" }
    . $packet.references[0].path
    if ((Get-LocalOverride) -cne "local") { throw "Override did not execute" }
    $defaults.packs.config.state = "DISABLED"
    Write-Json $defaultsPath $defaults
    $packet = Run-Router @("reference-path","config") 0 | ConvertFrom-Json
    if ($packet.references[0].state -cne "DISABLED" -or $null -ne $packet.references[0].path -or
        (Get-Content -LiteralPath $override -Raw) -cne "function Get-LocalOverride { 'local' }") { throw "Disabled changed local override" }
    Remove-Item -LiteralPath $override
    $defaults.packs.config.state = "DEFAULT"
    $defaults.packs.config.materialized_files = @(@{path="project/tools/config-default.ps1";sha256=("0"*64)})
    Write-Json $defaultsPath $defaults
    Run-Router @("reference-path","config") 2 | Out-Null
    $defaults.packs.config.Remove("materialized_files")
    $defaults.packs.api = @{state="DEFAULT"}
    Write-Json $defaultsPath $defaults
    Run-Router @("reference-path","api") 2 | Out-Null
    Write-Host "[PASS] Reference Defaults: real catalog/router, central helper, local override, disabled, compatibility and legacy conflict rejection"
}
finally { Remove-Item -LiteralPath $Temp -Recurse -Force }
