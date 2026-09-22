param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$BaseDir = Split-Path -Parent $PSScriptRoot
$Root = Split-Path -Parent $BaseDir
$ManifestPath = Join-Path $Root "project/project.json"
$BaseFilesPath = Join-Path $BaseDir "base-files.json"

function Write-Knt([string]$Message) {
    Write-Host "[knt] $Message"
}

function Get-Manifest {
    if (-not (Test-Path $ManifestPath)) {
        throw "project/project.json not found: $ManifestPath"
    }
    return Get-Content -Raw -Encoding UTF8 $ManifestPath | ConvertFrom-Json
}

function Test-BaseFiles {
    if (-not (Test-Path $BaseFilesPath)) {
        Write-Knt "base-files.json is missing."
        return $false
    }
    $index = Get-Content -Raw -Encoding UTF8 $BaseFilesPath | ConvertFrom-Json
    $ok = $true
    foreach ($entry in $index.files) {
        $path = Join-Path $Root $entry.path
        if (-not (Test-Path $path)) {
            Write-Host "[base-check] MISSING  $($entry.path)" -ForegroundColor Red
            $ok = $false
            continue
        }
        $hash = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
        if ($hash -ne $entry.sha256) {
            Write-Host "[base-check] CHANGED  $($entry.path)" -ForegroundColor Yellow
            $ok = $false
        }
    }
    if ($ok) { Write-Knt "Base files: OK" }
    return $ok
}

function Resolve-Command($Manifest, [string]$Name) {
    $prop = $Manifest.commands.PSObject.Properties[$Name]
    if (-not $prop) { return $null }
    $value = $prop.Value
    if ($value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($value)) { return $null }
        return [pscustomobject]@{ run = $value; cwd = "project" }
    }
    if (-not $value.run) { return $null }
    $cwd = if ($value.cwd) { [string]$value.cwd } else { "project" }
    return [pscustomobject]@{ run = [string]$value.run; cwd = $cwd }
}

function Invoke-ProjectCommand($Manifest, [string]$Name) {
    $spec = Resolve-Command $Manifest $Name
    if (-not $spec) {
        Write-Knt "Command '$Name' is not configured for this project."
        return 0
    }
    $cwd = Join-Path $Root $spec.cwd
    if (-not (Test-Path $cwd)) { throw "Command cwd not found: $($spec.cwd)" }
    $argText = if ($RemainingArgs) { " " + (($RemainingArgs | ForEach-Object { '"' + ($_ -replace '"','\"') + '"' }) -join ' ') } else { "" }
    Write-Knt "$Name -> $($spec.run)"
    Push-Location $cwd
    try {
        Invoke-Expression ($spec.run + $argText)
        if ($null -ne $LASTEXITCODE) { return $LASTEXITCODE }
        return 0
    }
    finally { Pop-Location }
}

function Invoke-Doctor($Manifest) {
    $ok = $true
    Write-Knt "Repository root: $Root"
    Write-Knt "Project: $($Manifest.project.name) [$($Manifest.project.type)]"
    Write-Knt "Profile: $($Manifest.profile)"
    $baseVersion = (Get-Content -Raw -Encoding UTF8 (Join-Path $BaseDir "BASE_VERSION")).Trim()
    Write-Knt "Base version: $baseVersion"

    if (-not (Test-BaseFiles)) { $ok = $false }

    foreach ($required in @("project/docs/INDEX.md", "project/docs/CURRENT_STATE.md", "project/contracts/actions.json", "project/contracts/surfaces.json")) {
        if (-not (Test-Path (Join-Path $Root $required))) {
            Write-Host "[doctor] MISSING $required" -ForegroundColor Red
            $ok = $false
        }
    }

    $modules = @($Manifest.runtime.modules)
    Write-Knt ("Runtime modules: " + ($(if ($modules.Count) { $modules -join ", " } else { "(none)" })))
    $enabled = @($Manifest.surfaces.PSObject.Properties | Where-Object { $_.Value -eq $true } | ForEach-Object { $_.Name })
    Write-Knt ("Surfaces: " + ($(if ($enabled.Count) { $enabled -join ", " } else { "(none)" })))

    $configured = @($Manifest.commands.PSObject.Properties | Where-Object { $null -ne (Resolve-Command $Manifest $_.Name) } | ForEach-Object { $_.Name })
    Write-Knt ("Commands: " + ($(if ($configured.Count) { $configured -join ", " } else { "(none configured yet)" })))

    if ($ok) {
        Write-Host "[doctor] OK" -ForegroundColor Green
        return 0
    }
    Write-Host "[doctor] FAILED" -ForegroundColor Red
    return 1
}

function Show-Help {
    @"
KiNoTch. repository command router

Usage:
  knt.cmd <command>
  .kinotch/scripts/knt.ps1 <command>

Common commands:
  doctor      Base/project structure diagnostics
  base-check  Detect modifications in common Base files
  setup       Project setup command
  dev         Project development command
  test        Project tests
  build       Project build
  verify      Project verify command; falls back to test + build
  smoke       Project smoke / real-entry check
  help        This help
"@ | Write-Host
}

try {
    if ($Command -eq "help" -or $Command -eq "--help" -or $Command -eq "-h") {
        Show-Help
        exit 0
    }
    if ($Command -eq "base-check") {
        if (Test-BaseFiles) { exit 0 } else { exit 1 }
    }

    $manifest = Get-Manifest
    if ($Command -eq "doctor") { exit (Invoke-Doctor $manifest) }

    if ($Command -eq "verify") {
        $direct = Resolve-Command $manifest "verify"
        if ($direct) { exit (Invoke-ProjectCommand $manifest "verify") }
        foreach ($fallback in @("test", "build")) {
            if (Resolve-Command $manifest $fallback) {
                $code = Invoke-ProjectCommand $manifest $fallback
                if ($code -ne 0) { exit $code }
            }
        }
        exit 0
    }

    if ($Command -in @("setup","dev","test","build","smoke","deploy")) {
        exit (Invoke-ProjectCommand $manifest $Command)
    }

    Write-Host "Unknown command: $Command" -ForegroundColor Red
    Show-Help
    exit 2
}
catch {
    Write-Host "[knt] ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
