# B1 independent snapshot fixture; never a production admission path.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BaseDir = Join-Path $RepoRoot ".kinotch"
. (Join-Path $BaseDir "scripts/path-containment.ps1")
. (Join-Path $RepoRoot "project/src/reference-snapshot.ps1")
$HostExe = (Get-Process -Id $PID).Path
Write-Host "Reference fixture host: $($PSVersionTable.PSVersion) / $($PSVersionTable.PSEdition)"

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
$Stages = Join-Path $Temp "stages"
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
function Receive-FixtureCommit([string]$Expected) {
    Receive-KntReferenceCommit -CacheRoot $Cache -Source $Source -Commit $Expected -EmptyTemplate $Template -InvokeGit { param($repo,$argv) Invoke-FixtureGit $repo $argv }
}
function New-FixtureSnapshot([string]$Commit) {
    New-KntReferenceSnapshot -Cache (Join-Path $Cache $Commit) -Commit $Commit -StageRoot $Stages -EmptyTemplate $Template -InvokeGit { param($repo,$argv) Invoke-FixtureGit $repo $argv }
}
New-Item -ItemType Directory -Path @($Consumer,$Source,$Cache,$Template,$Hooks,$Stages) -Force | Out-Null
try {
    foreach ($key in $SavedGitEnv.Keys) { Remove-Item -LiteralPath ("Env:" + $key) }
    $env:GIT_CONFIG_NOSYSTEM = "1"
    $env:GIT_CONFIG_GLOBAL = Join-Path $Temp "empty-global-config"
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GIT_OPTIONAL_LOCKS = "0"
    $env:GIT_NO_REPLACE_OBJECTS = "1"
    Invoke-FixtureGit $Source @("init","--quiet","--template=$Template") | Out-Null
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
    # Retain exact source identities, then materialize independent stages.
    $retainedA = Receive-FixtureCommit $commitA
    if ($retainedA.reused -or $retainedA.commit -cne $commitA) { throw "Initial retention failed" }
    $stageA = New-FixtureSnapshot $commitA
    $baseA = Join-Path $stageA ".kinotch"
    Invoke-Probe -Consumer $Consumer -ExternalBase $baseA -Arguments @("doctor") -Expected 1 -Pattern "project\.name must have at least $minimum characters"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Old schema probe modified consumer" }
    $retainedB = Receive-FixtureCommit $commitB
    if ($retainedB.reused -or $retainedB.commit -cne $commitB) { throw "Updated retention failed" }
    $stageB = New-FixtureSnapshot $commitB
    $baseB = Join-Path $stageB ".kinotch"
    Invoke-Probe -Consumer $Consumer -ExternalBase $baseB -Arguments @("doctor") -Expected 0 -Pattern "Base version:"
    Invoke-Probe -Consumer $Consumer -ExternalBase $baseB -Arguments @("migrate", "--apply") -Expected 2 -Pattern "BaseOverride is read-only"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Updated schema probe modified consumer" }

    # A stage's Git metadata and working bytes must not affect another stage or cache.
    $cacheConfig = Get-Content -LiteralPath (Join-Path $retainedA.path "config") -Raw
    $otherBefore = Get-TreeFingerprint $stageB
    Invoke-FixtureGit $stageA @("config","fixture.local","changed") | Out-Null
    [IO.File]::WriteAllText((Join-Path $baseA "schemas/project.schema.json"), "damaged stage")
    if ((Get-Content -LiteralPath (Join-Path $retainedA.path "config") -Raw) -cne $cacheConfig -or
        (Get-TreeFingerprint $stageB) -cne $otherBefore) { throw "Stage mutation propagated" }
    Remove-Item -LiteralPath $stageA -Recurse -Force
    # Simulate unavailable origin: materialization must only use local cache.
    $offlineSource = Join-Path $Temp "source-offline"
    Move-Item -LiteralPath $Source -Destination $offlineSource
    $offlineHit = Receive-FixtureCommit $commitA
    if (-not $offlineHit.reused -or $offlineHit.path -cne $retainedA.path) { throw "Offline retention reuse failed" }
    $cacheCount = @(Get-ChildItem -LiteralPath $Cache -Force).Count
    $rejected = $false
    try { Receive-FixtureCommit ("1" * 40) | Out-Null }
    catch { if ($_.Exception.Message -notmatch "Source unavailable") { throw }; $rejected = $true }
    if (-not $rejected -or @(Get-ChildItem -LiteralPath $Cache -Force).Count -ne $cacheCount) { throw "Unavailable source changed cache" }
    $stageA = New-FixtureSnapshot $commitA
    Invoke-Probe -Consumer $Consumer -ExternalBase (Join-Path $stageA ".kinotch") -Arguments @("doctor") -Expected 1 -Pattern "project\.name must have at least $minimum characters"
    if ((Get-TreeFingerprint $stageB) -cne $otherBefore) { throw "Offline recovery changed normal stage" }
    Move-Item -LiteralPath $offlineSource -Destination $Source

    # Exact commit retrieval ignores movement of mutable tags, including on a cache miss.
    Invoke-FixtureGit $Source @("tag","-f",$tagA,$commitB) | Out-Null
    $freshRoot = Join-Path $Temp "fresh-cache"
    New-Item -ItemType Directory -Path $freshRoot | Out-Null
    $fresh = Receive-KntReferenceCommit -CacheRoot $freshRoot -Source $Source -Commit $commitA -EmptyTemplate $Template -InvokeGit { param($repo,$argv) Invoke-FixtureGit $repo $argv }
    if ($fresh.reused -or (Get-FixtureCommit $fresh.path "refs/kinotch/retained/$commitA") -cne $commitA) { throw "Moved tag influenced exact retention" }

    # Unknown exact commit must leave no incoming cache and keep existing versions.
    $rejected = $false
    try { Receive-FixtureCommit ("2" * 40) | Out-Null }
    catch { if ($_.Exception.Message -notmatch "Fixture Git failed|remote error|not our ref|couldn't find") { throw }; $rejected = $true }
    if (-not $rejected -or @(Get-ChildItem -LiteralPath $Cache -Force).Count -ne $cacheCount) { throw "Failed fetch leaked or modified cache" }

    # Corrupt retained locator is not silently repaired or replaced.
    $stageCount = @(Get-ChildItem -LiteralPath $Stages -Force).Count
    # Put a different commit object into A's fixture cache for deliberate corruption.
    Invoke-FixtureGit $retainedA.path @("fetch","--quiet","--no-tags","--depth=1",$retainedB.path,"refs/kinotch/retained/$commitB") | Out-Null
    Invoke-FixtureGit $retainedA.path @("update-ref","refs/kinotch/retained/$commitA",$commitB) | Out-Null
    $rejected = $false
    try { Receive-FixtureCommit $commitA | Out-Null }
    catch { if ($_.Exception.Message -notmatch "identity mismatch") { throw }; $rejected = $true }
    if (-not $rejected -or (Get-FixtureCommit $retainedA.path "refs/kinotch/retained/$commitA") -cne $commitB) { throw "Corrupt cache was silently repaired" }
    $rejected = $false
    try { New-FixtureSnapshot $commitA | Out-Null }
    catch { if ($_.Exception.Message -notmatch "identity mismatch") { throw }; $rejected = $true }
    if (-not $rejected -or @(Get-ChildItem -LiteralPath $Stages -Force).Count -ne $stageCount) { throw "Corrupt retained identity admitted or leaked stage" }
    Invoke-FixtureGit $retainedA.path @("update-ref","refs/kinotch/retained/$commitA",$commitA) | Out-Null

    # Unsupported gitlink mode is rejected without materializing it.
    Invoke-FixtureGit $Source @("update-index","--add","--cacheinfo","160000,$commitA,unexpected-link") | Out-Null
    Invoke-FixtureGit $Source @("commit","--quiet","-m","synthetic unsupported tree") | Out-Null
    $commitC = Get-FixtureCommit $Source "HEAD"
    $tagC = "base-ref-v1-00000003"
    Invoke-FixtureGit $Source @("tag",$tagC) | Out-Null
    Receive-FixtureCommit $commitC | Out-Null
    $rejected = $false
    try { New-FixtureSnapshot $commitC | Out-Null }
    catch { if ($_.Exception.Message -notmatch "Unsupported snapshot tree entry") { throw }; $rejected = $true }
    if (-not $rejected -or @(Get-ChildItem -LiteralPath $Stages -Force).Count -ne $stageCount) { throw "Unsupported tree admitted or leaked stage" }
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Native Git reference probe modified consumer" }
    if ((Get-TreeFingerprint $stageB) -cne $otherBefore) { throw "Normal stage changed" }
    if (Test-Path -LiteralPath (Join-Path $Consumer ".kinotch")) { throw "Probe materialized local Base" }
    if (@(Get-ChildItem -LiteralPath $Cache -Force | Where-Object { $_.Name -like "incoming-*" }).Count -ne 0) { throw "Incoming cache leaked" }
    Write-Host "[PASS] Independent retention and snapshots: exact SHA A/B, offline cache hit, source loss/unknown/corrupt ref/tree rejection, isolated recovery, consumer unchanged, external apply denied"
}
finally {
    foreach ($variable in @(Get-ChildItem Env: | Where-Object { $_.Name -like "GIT_*" })) {
        Remove-Item -LiteralPath ("Env:" + $variable.Name)
    }
    foreach ($key in $SavedGitEnv.Keys) { Set-Item -LiteralPath ("Env:" + $key) -Value $SavedGitEnv[$key] }
    Remove-Item -LiteralPath $Temp -Recurse -Force
}
