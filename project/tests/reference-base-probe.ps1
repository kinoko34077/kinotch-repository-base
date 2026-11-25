# B0/B1 native Git reference fixture; never a production admission path.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BaseDir = Join-Path $RepoRoot ".kinotch"
$HostExe = if ($PSVersionTable.PSEdition -eq "Desktop") {
    (Get-Command powershell -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
} else {
    (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
}

function Get-TreeFingerprint([string]$Root) {
    $entries = @(Get-ChildItem -LiteralPath $Root -Force -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
        if ($_.PSIsContainer) { "D $relative" }
        else { "F $relative $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    } | Sort-Object)
    return ($entries -join [Environment]::NewLine)
}

function Invoke-Probe([string]$Consumer, [string]$ExternalBase, [string[]]$Arguments, [int]$Expected, [string]$Pattern) {
    $output = @(& $HostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ExternalBase "scripts/knt.ps1") -RootOverride $Consumer -BaseOverride $ExternalBase @Arguments 2>&1)
    $code = $LASTEXITCODE
    $message = $output -join [Environment]::NewLine
    if ($code -ne $Expected -or $message -notmatch $Pattern) {
        throw "Expected exit $Expected and diagnostic '$Pattern', got $code : $message"
    }
}

$Temp = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-reference-probe-" + [guid]::NewGuid().ToString("N"))
$Consumer = Join-Path $Temp "consumer"
$Source = Join-Path $Temp "source"
$Cache = Join-Path $Temp "cache"
$Template = Join-Path $Temp "empty-template"
$Hooks = Join-Path $Temp "empty-hooks"
$Git = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$SavedGitEnv = @{}
foreach ($variable in @(Get-ChildItem Env: | Where-Object { $_.Name -like "GIT_*" })) {
    $SavedGitEnv[$variable.Name] = $variable.Value
}
function Invoke-FixtureGit([string]$Repository,[string[]]$GitArguments) {
    $output = @(& $Git -C $Repository -c "core.hooksPath=$Hooks" -c core.autocrlf=false -c protocol.file.allow=always -c user.name=Fixture -c user.email=fixture@example.invalid @GitArguments)
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $($GitArguments[0])" }
    return $output
}
function Get-FixtureCommit([string]$Repository,[string]$Ref) {
    return [string](Invoke-FixtureGit $Repository @("rev-parse","--verify",$Ref))
}
function Select-FixtureCommit([string]$Tag,[string]$Expected) {
    Invoke-FixtureGit $Cache @("fetch","--quiet","--no-tags",$Source,"refs/tags/$Tag") | Out-Null
    $actual = Get-FixtureCommit $Cache "FETCH_HEAD"
    if ($actual -cne $Expected -or (Invoke-FixtureGit $Cache @("cat-file","-t",$actual)) -cne "commit") { throw "Fetched commit identity mismatch" }
    Invoke-FixtureGit $Cache @("checkout","--quiet","--detach",$Expected) | Out-Null
}
New-Item -ItemType Directory -Path @($Consumer,$Source,$Cache,$Template,$Hooks) -Force | Out-Null
try {
    foreach ($key in $SavedGitEnv.Keys) { Remove-Item -LiteralPath ("Env:" + $key) }
    $env:GIT_CONFIG_NOSYSTEM = "1"
    $env:GIT_CONFIG_GLOBAL = Join-Path $Temp "empty-global-config"
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GIT_OPTIONAL_LOCKS = "0"
    foreach ($repository in @($Source,$Cache)) {
        Invoke-FixtureGit $repository @("init","--quiet","--template=$Template") | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $BaseDir "tests/fixtures/valid-minimal") -Destination (Join-Path $Consumer "project") -Recurse
    Copy-Item -LiteralPath $BaseDir -Destination (Join-Path $Source ".kinotch") -Recurse
    $schemaPath = Join-Path $Source ".kinotch/schemas/project.schema.json"
    $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $name = (Get-Content -LiteralPath (Join-Path $Consumer "project/project.json") -Raw -Encoding UTF8 | ConvertFrom-Json).project.name
    $minimum = $name.Length + 1
    $schema.properties.project.properties.name.minLength = $minimum
    [IO.File]::WriteAllText($schemaPath, ($schema | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $Consumer "user-owned.txt"), "preserve me")
    $before = Get-TreeFingerprint $Consumer

    $tagA = "base-ref-v1-00000001"
    $tagB = "base-ref-v1-00000002"
    Invoke-FixtureGit $Source @("add","-f",".kinotch") | Out-Null
    Invoke-FixtureGit $Source @("commit","--quiet","-m","synthetic strict schema") | Out-Null
    $commitA = Get-FixtureCommit $Source "HEAD"
    Invoke-FixtureGit $Source @("tag",$tagA) | Out-Null
    Copy-Item -LiteralPath (Join-Path $BaseDir "schemas/project.schema.json") -Destination $schemaPath -Force
    Invoke-FixtureGit $Source @("add","-f",".kinotch/schemas/project.schema.json") | Out-Null
    Invoke-FixtureGit $Source @("commit","--quiet","-m","canonical schema correction") | Out-Null
    $commitB = Get-FixtureCommit $Source "HEAD"
    Invoke-FixtureGit $Source @("tag",$tagB) | Out-Null
    $cachedBase = Join-Path $Cache ".kinotch"

    Select-FixtureCommit $tagA $commitA
    Invoke-Probe -Consumer $Consumer -ExternalBase $cachedBase -Arguments @("doctor") -Expected 1 -Pattern "project\.name must have at least $minimum characters"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Old schema probe modified consumer" }
    Select-FixtureCommit $tagB $commitB
    Invoke-Probe -Consumer $Consumer -ExternalBase $cachedBase -Arguments @("doctor") -Expected 0 -Pattern "Base version:"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Updated schema probe modified consumer" }
    Invoke-Probe -Consumer $Consumer -ExternalBase $cachedBase -Arguments @("migrate", "--apply") -Expected 2 -Pattern "BaseOverride is read-only"

    # Offline rollback uses only the fetched commit object, no new fetch.
    Invoke-FixtureGit $Cache @("checkout","--quiet","--detach",$commitA) | Out-Null
    Invoke-Probe -Consumer $Consumer -ExternalBase $cachedBase -Arguments @("doctor") -Expected 1 -Pattern "project\.name must have at least $minimum characters"
    Invoke-FixtureGit $Source @("tag","-f",$tagA,$commitB) | Out-Null
    $rejected = $false
    try { Select-FixtureCommit $tagA $commitA }
    catch { if ($_.Exception.Message -notmatch "identity mismatch") { throw }; $rejected = $true }
    if (-not $rejected -or (Get-FixtureCommit $Cache "HEAD") -cne $commitA) { throw "Moved tag was admitted" }
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Native Git reference probe modified consumer" }
    if (Test-Path -LiteralPath (Join-Path $Consumer ".kinotch")) { throw "Probe materialized local Base" }
    Write-Host "[PASS] Native Git reference: A/B external schema, offline rollback, moved tag rejection, consumer unchanged, external apply denied"
}
finally {
    foreach ($variable in @(Get-ChildItem Env: | Where-Object { $_.Name -like "GIT_*" })) {
        Remove-Item -LiteralPath ("Env:" + $variable.Name)
    }
    foreach ($key in $SavedGitEnv.Keys) { Set-Item -LiteralPath ("Env:" + $key) -Value $SavedGitEnv[$key] }
    Remove-Item -LiteralPath $Temp -Recurse -Force
}
