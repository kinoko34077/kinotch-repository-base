param(
    [string]$RootOverride,

    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"

if ($RootOverride) {
    $Root = (Resolve-Path -LiteralPath $RootOverride).Path
    $BaseDir = Join-Path $Root ".kinotch"
}
else {
    $BaseDir = Split-Path -Parent $PSScriptRoot
    $Root = Split-Path -Parent $BaseDir
}

$ManifestPath = Join-Path $Root "project/project.json"
$BaseFilesPath = Join-Path $BaseDir "base-files.json"
$ValidationPath = Join-Path $BaseDir "scripts/knt-validation.ps1"
$BaseIndexScriptPath = Join-Path $BaseDir "scripts/update-base-index.ps1"

if (-not (Test-Path -LiteralPath $ValidationPath -PathType Leaf)) {
    throw "Validation script not found: $ValidationPath"
}
. $ValidationPath
if (-not (Test-Path -LiteralPath $BaseIndexScriptPath -PathType Leaf)) {
    throw "Base index script not found: $BaseIndexScriptPath"
}
. $BaseIndexScriptPath

function Write-Knt([string]$Message) {
    Write-Host "[knt] $Message"
}

function Get-Manifest {
    return Get-KntJson -Path $ManifestPath
}

function Get-SelectedInitProfiles {
    $selected = New-Object System.Collections.Generic.List[string]
    $values = @($RemainingArgs)
    for ($index = 0; $index -lt $values.Count; $index++) {
        $value = [string]$values[$index]
        if ($value -eq "--profile") {
            if ($index + 1 -ge $values.Count -or [string]::IsNullOrWhiteSpace([string]$values[$index + 1])) {
                throw "init requires a value after --profile"
            }
            $value = [string]$values[++$index]
        }
        elseif ($value -like "--profile=*") {
            $value = $value.Substring("--profile=".Length)
        }
        else {
            throw "Unknown init option: $value"
        }

        if ($value -eq "windows") { $value = "windows-gui" }
        if ($value -notin @("cli", "windows-gui", "mcp", "api")) {
            throw "Unsupported Default Pack profile: $value"
        }
        if ($value -notin $selected) { [void]$selected.Add($value) }
    }
    if ($selected.Count -eq 0) { throw "init requires at least one --profile" }
    return @($selected)
}

function Write-KntJsonFile([string]$Path, $Value) {
    $json = ConvertTo-Json $Value -Depth 20
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Init {
    if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
        Write-Host "[init] Repository is already initialized: project/project.json" -ForegroundColor Yellow
        return 1
    }

    $profiles = @(Get-SelectedInitProfiles)
    $projectRoot = Join-Path $Root "project"
    if (Test-Path -LiteralPath $projectRoot -PathType Container) {
        $existing = @(Get-ChildItem -LiteralPath $projectRoot -Force)
        if ($existing.Count -gt 0) {
            Write-Host "[init] Project directory is not empty; refusing to overwrite Project files" -ForegroundColor Yellow
            return 1
        }
    }

    $templateRoot = Join-Path $BaseDir "templates/project"
    if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
        throw "Project template not found: $templateRoot"
    }
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null

    foreach ($templateEntry in @(Get-ChildItem -LiteralPath $templateRoot -Force)) {
        if ($templateEntry.Name -eq "README.md") {
            $destination = Join-Path $Root "README.md"
        }
        elseif ($templateEntry.Name -eq ".gitignore") {
            $destination = Join-Path $projectRoot ".gitignore"
        }
        else {
            $destination = Join-Path $projectRoot $templateEntry.Name
        }

        if (Test-Path -LiteralPath $destination) {
            if ($templateEntry.Name -eq "README.md") { continue }
            throw "Refusing to overwrite existing generated path: $destination"
        }
        Copy-Item -LiteralPath $templateEntry.FullName -Destination $destination -Recurse -Force
    }

    $manifest = Get-KntJson -Path $ManifestPath
    $manifest.project.name = (Split-Path -Leaf $Root.TrimEnd([char[]]@("/", "\")))
    if ([string]::IsNullOrWhiteSpace($manifest.project.name)) { $manifest.project.name = "kinotch-project" }
    $manifest.project.description = "KiNoTch. Project initialized with Default Packs: " + ($profiles -join ", ")
    $manifest.profile = $profiles[0]
    $manifest | Add-Member -NotePropertyName profiles -NotePropertyValue $profiles -Force
    $manifest.paths | Add-Member -NotePropertyName defaults -NotePropertyValue "defaults.json" -Force

    $moduleNames = New-Object System.Collections.Generic.List[string]
    $surfaceNames = New-Object System.Collections.Generic.List[string]
    $defaults = [pscustomobject]@{ schema_version = 1; packs = [pscustomobject]@{} }
    foreach ($profileName in $profiles) {
        $profilePath = Join-Path $BaseDir ("profiles/" + $profileName + ".json")
        $profile = Get-KntJson -Path $profilePath
        foreach ($module in @($profile.runtime_modules)) {
            if ($module -notin $moduleNames) { [void]$moduleNames.Add([string]$module) }
        }
        foreach ($surface in @($profile.surfaces.PSObject.Properties | Where-Object { $_.Value -eq $true })) {
            if ($surface.Name -notin $surfaceNames) { [void]$surfaceNames.Add([string]$surface.Name) }
            $defaults.packs | Add-Member -NotePropertyName $surface.Name -NotePropertyValue ([pscustomobject]@{ state = "DEFAULT" }) -Force
        }
    }
    $manifest.runtime.modules = @($moduleNames)
    foreach ($surface in @($manifest.surfaces.PSObject.Properties)) {
        $surface.Value = ($surface.Name -in $surfaceNames)
    }
    Write-KntJsonFile -Path $ManifestPath -Value $manifest
    Write-KntJsonFile -Path (Join-Path $projectRoot "defaults.json") -Value $defaults
    Write-Knt "Initialized Project with Default Packs: $($profiles -join ', ')"
    return 0
}

function Test-BaseFiles {
    if (-not (Test-Path -LiteralPath $BaseFilesPath -PathType Leaf)) {
        Write-Knt "base-files.json is missing."
        return $false
    }
    $index = Get-KntJson -Path $BaseFilesPath
    $ok = $true
    $currentVersion = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $BaseDir "BASE_VERSION")).Trim()
    if ([string]$index.base_version -ne $currentVersion) {
        Write-Host "[base-check] VERSION  index=$($index.base_version) current=$currentVersion" -ForegroundColor Yellow
        $ok = $false
    }
    $indexedPaths = @($index.files | ForEach-Object { [string]$_.path })
    foreach ($expectedPath in @(Get-BaseProtectedPaths -Root $Root)) {
        if ($expectedPath -notin $indexedPaths) {
            Write-Host "[base-check] UNINDEXED  $expectedPath" -ForegroundColor Yellow
            $ok = $false
        }
    }
    foreach ($indexedPath in $indexedPaths) {
        if ($indexedPath -notin @(Get-BaseProtectedPaths -Root $Root)) {
            Write-Host "[base-check] ORPHANED  $indexedPath" -ForegroundColor Yellow
            $ok = $false
        }
    }
    foreach ($entry in @($index.files)) {
        $path = Join-Path $Root $entry.path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Write-Host "[base-check] MISSING  $($entry.path)" -ForegroundColor Red
            $ok = $false
            continue
        }
        $hash = Get-BaseFileHash -Path $path
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

function Get-ManifestPathValue($Manifest, [string]$Name, [string]$Default) {
    $value = Get-KntJsonProperty $Manifest.paths $Name
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $Default }
    return [string]$value
}

function Invoke-ProjectCommand($Manifest, [string]$Name) {
    $spec = Resolve-Command $Manifest $Name
    if (-not $spec) {
        Write-Knt "Command '$Name' is not configured for this project."
        return 0
    }
    $cwd = Join-Path $Root $spec.cwd
    if (-not (Test-Path -LiteralPath $cwd -PathType Container)) {
        Write-Host "[doctor] MISSING command cwd: $($spec.cwd)" -ForegroundColor Red
        return 1
    }
    $argText = if ($RemainingArgs) {
        " " + (($RemainingArgs | ForEach-Object { '"' + ($_ -replace '"','\"') + '"' }) -join ' ')
    }
    else { "" }
    Write-Knt "$Name -> $($spec.run)"
    Push-Location $cwd
    try {
        Invoke-Expression ($spec.run + $argText)
        if ($null -ne $LASTEXITCODE) { return $LASTEXITCODE }
        return 0
    }
    finally {
        Pop-Location
    }
}

function Add-DoctorSchemaErrors {
    param([System.Collections.Generic.List[string]]$Errors, $Data, $Schema, [string]$Path)
    foreach ($errorText in @(Test-KntSchema -Data $Data -Schema $Schema -Path $Path)) {
        [void]$Errors.Add($errorText)
    }
}

function Invoke-Doctor($Manifest) {
    $ok = $true
    Write-Knt "Repository root: $Root"
    Write-Knt "Project: $($Manifest.project.name) [$($Manifest.project.type)]"
    $selectedProfiles = @([string]$Manifest.profile)
    $profilesProperty = $Manifest.PSObject.Properties["profiles"]
    if ($profilesProperty -and @($Manifest.profiles).Count -gt 0) {
        $selectedProfiles = @($Manifest.profiles | ForEach-Object { [string]$_ })
    }
    Write-Knt "Profile: $($Manifest.profile)$(if ($selectedProfiles.Count -gt 1) { ' [' + ($selectedProfiles -join ', ') + ']' } else { '' })"
    $baseVersion = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $BaseDir "BASE_VERSION")).Trim()
    Write-Knt "Base version: $baseVersion"

    if (-not $RootOverride -and -not (Test-BaseFiles)) { $ok = $false }

    $required = @(
        "project/docs/INDEX.md",
        "project/docs/CURRENT_STATE.md",
        "project/contracts/actions.json",
        "project/contracts/surfaces.json"
    )
    foreach ($requiredPath in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $requiredPath) -PathType Leaf)) {
            Write-Host "[doctor] MISSING $requiredPath" -ForegroundColor Red
            $ok = $false
        }
    }

    $schemaErrors = New-Object System.Collections.Generic.List[string]
    $manifestSchema = Get-KntJson -Path (Join-Path $BaseDir "schemas/project.schema.json")
    $actionSchema = Get-KntJson -Path (Join-Path $BaseDir "schemas/action.schema.json")
    $surfaceSchema = Get-KntJson -Path (Join-Path $BaseDir "schemas/surface.schema.json")
    $defaultsSchema = Get-KntJson -Path (Join-Path $BaseDir "schemas/defaults.schema.json")
    Add-DoctorSchemaErrors $schemaErrors $Manifest $manifestSchema "project/project.json"

    $projectRoot = Join-Path $Root "project"
    $actionRelative = Get-ManifestPathValue $Manifest "actions" "contracts/actions.json"
    $surfaceRelative = Get-ManifestPathValue $Manifest "surfaces" "contracts/surfaces.json"
    $actionPath = Join-Path $projectRoot $actionRelative
    $surfacePath = Join-Path $projectRoot $surfaceRelative
    if (Test-Path -LiteralPath $actionPath -PathType Leaf) {
        Add-DoctorSchemaErrors $schemaErrors (Get-KntJson -Path $actionPath) $actionSchema $actionRelative
    }
    if (Test-Path -LiteralPath $surfacePath -PathType Leaf) {
        Add-DoctorSchemaErrors $schemaErrors (Get-KntJson -Path $surfacePath) $surfaceSchema $surfaceRelative
    }
    $defaultsRelative = Get-ManifestPathValue $Manifest "defaults" ""
    if (-not [string]::IsNullOrWhiteSpace($defaultsRelative)) {
        $defaultsPath = Join-Path $projectRoot $defaultsRelative
        if (Test-Path -LiteralPath $defaultsPath -PathType Leaf) {
            Add-DoctorSchemaErrors $schemaErrors (Get-KntJson -Path $defaultsPath) $defaultsSchema $defaultsRelative
        }
    }

    if ($schemaErrors.Count -gt 0) {
        Write-Host "[doctor] Schema validation failed" -ForegroundColor Red
        foreach ($errorText in $schemaErrors) {
            Write-Host "[doctor] $errorText" -ForegroundColor Red
        }
        $ok = $false
    }

    $profiles = New-Object System.Collections.Generic.List[object]
    foreach ($selectedProfile in $selectedProfiles) {
        $profilePath = Join-Path $BaseDir ("profiles/" + $selectedProfile + ".json")
        if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
            Write-Host "[doctor] MISSING profile: $selectedProfile" -ForegroundColor Red
            $ok = $false
        }
        else {
            [void]$profiles.Add((Get-KntJson -Path $profilePath))
        }
    }

    $modules = @($Manifest.runtime.modules)
    Write-Knt ("Runtime modules: " + ($(if ($modules.Count) { $modules -join ", " } else { "(none)" })))
    $enabled = @($Manifest.surfaces.PSObject.Properties | Where-Object { $_.Value -eq $true } | ForEach-Object { $_.Name })
    Write-Knt ("Surfaces: " + ($(if ($enabled.Count) { $enabled -join ", " } else { "(none)" })))

    if ($profiles.Count -gt 0) {
        $recommendedModules = @($profiles | ForEach-Object { $_.runtime_modules } | Select-Object -Unique)
        $missingModules = @($recommendedModules | Where-Object { $_ -notin $modules })
        $extraModules = @($modules | Where-Object { $_ -notin $recommendedModules })
        if ($missingModules.Count -or $extraModules.Count) {
            Write-Host "[doctor] WARN profile runtime module recommendation differs from manifest." -ForegroundColor Yellow
        }

        $recommendedSurfaces = @($profiles | ForEach-Object {
            $profileSurfaces = Get-KntJsonProperty $_ "surfaces"
            @($profileSurfaces.PSObject.Properties | Where-Object { $_.Value -eq $true } | ForEach-Object { $_.Name })
        } | Select-Object -Unique)
        foreach ($profileSurface in $recommendedSurfaces) {
            $manifestValue = Get-KntJsonProperty $Manifest.surfaces $profileSurface
            if ($manifestValue -ne $true) {
                Write-Host "[doctor] CONTRADICTION profile surface '$profileSurface' is not enabled in manifest." -ForegroundColor Red
                $ok = $false
            }
        }
        foreach ($manifestSurface in @($Manifest.surfaces.PSObject.Properties | Where-Object { $_.Value -eq $true })) {
            if ($manifestSurface.Name -notin $recommendedSurfaces) {
                Write-Host "[doctor] WARN manifest surface '$($manifestSurface.Name)' is not recommended by selected profile(s)." -ForegroundColor Yellow
            }
        }
    }

    foreach ($pathProperty in @($Manifest.paths.PSObject.Properties)) {
        if ([string]::IsNullOrWhiteSpace([string]$pathProperty.Value)) { continue }
        $candidate = Join-Path $projectRoot ([string]$pathProperty.Value)
        if (-not (Test-Path -LiteralPath $candidate)) {
            Write-Host "[doctor] MISSING path: $($pathProperty.Value) ($($pathProperty.Name))" -ForegroundColor Red
            $ok = $false
        }
    }

    foreach ($commandProperty in @($Manifest.commands.PSObject.Properties)) {
        $spec = Resolve-Command $Manifest $commandProperty.Name
        if ($spec -and -not (Test-Path -LiteralPath (Join-Path $Root $spec.cwd) -PathType Container)) {
            Write-Host "[doctor] MISSING command cwd: $($spec.cwd) ($($commandProperty.Name))" -ForegroundColor Red
            $ok = $false
        }
    }

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
  doctor      Base/project structure and schema diagnostics
  init        Create a Project from selected Default Pack profiles
  base-check  Detect modifications in common Base files
  base-refresh Regenerate Base file hashes (repository-base only)
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
    if ($Command -eq "base-refresh") {
        $refreshManifest = Get-Manifest
        if ($refreshManifest.project.type -ne "repository-base") {
            throw "base-refresh is only available for project.type repository-base"
        }
        Update-BaseIndex -Root $Root
        Write-Knt "Base index refreshed"
        exit 0
    }
    if ($Command -eq "init") {
        exit (Invoke-Init)
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
