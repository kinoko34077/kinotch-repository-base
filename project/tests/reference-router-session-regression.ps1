# B1/B2 integration: both revisions have a valid protected Base index.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root ".kinotch/scripts/update-base-index.ps1")
. (Join-Path $root "project/src/reference-snapshot.ps1")
. (Join-Path $root "project/src/reference-router.ps1")
. (Join-Path $root "project/src/reference-host.ps1")
$hostExe = (Get-Process -Id $PID).Path
$git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$temp = Join-Path ([IO.Path]::GetTempPath()) ("kr-" + [guid]::NewGuid().ToString("N"))
$source = Join-Path $temp "src"
$consumer = Join-Path $temp "consumer"
$cache = Join-Path $temp "cache"
$stages = Join-Path $temp "stages"
$template = Join-Path $temp "template"
New-Item -ItemType Directory -Path @($source,$consumer,$cache,$stages,$template) -Force | Out-Null
$saved = @{}
foreach ($v in @(Get-ChildItem Env: | Where-Object {$_.Name -like "GIT_*"})) {$saved[$v.Name]=$v.Value}
function Run-RouterFixtureGit([string]$repo,[string[]]$argv) {
    $lines = @(& $git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid -c "core.hooksPath=$template" -c core.autocrlf=false -c core.longpaths=true -c protocol.file.allow=always @argv)
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $($argv[0])" }
    return $lines
}
function Commit-RouterFixture {
    Run-RouterFixtureGit $source @("add","-f",".") | Out-Null
    Run-RouterFixtureGit $source @("commit","--quiet","-m","fixture") | Out-Null
    return [string](Run-RouterFixtureGit $source @("rev-parse","HEAD"))
}
function Fingerprint-RouterConsumer {
    return (@(Get-ChildItem -LiteralPath $consumer -Force -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($consumer.Length + 1)
        if ($_.PSIsContainer) { "D $rel" }
        else { "F $rel $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    } | Sort-Object) -join [Environment]::NewLine)
}
try {
    foreach ($key in $saved.Keys) { Remove-Item -LiteralPath ("Env:"+$key) }
    $env:GIT_CONFIG_NOSYSTEM="1"
    $env:GIT_CONFIG_GLOBAL=Join-Path $temp "empty-config"
    $env:GIT_TERMINAL_PROMPT="0"
    $env:GIT_NO_REPLACE_OBJECTS="1"
    Run-RouterFixtureGit $source @("init","--quiet","--template=$template") | Out-Null
    Copy-Item -LiteralPath (Join-Path $root ".kinotch") -Destination (Join-Path $source ".kinotch") -Recurse
    $index = Get-Content -LiteralPath (Join-Path $root ".kinotch/base-files.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($entry in @($index.files | Where-Object {$_.path -notlike ".kinotch/*"})) {
        $target = Join-Path $source $entry.path
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $entry.path) -Destination $target
    }
    New-Item -ItemType Directory -Path (Join-Path $source "project") | Out-Null
    Copy-Item -LiteralPath (Join-Path $root "project/project.json") -Destination (Join-Path $source "project/project.json")
    Copy-Item -LiteralPath (Join-Path $root ".kinotch/tests/fixtures/valid-minimal") -Destination (Join-Path $consumer "project") -Recurse
    $manifestPath = Join-Path $consumer "project/project.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest.commands.setup = [pscustomobject]@{run="Write-Output 'consumer-setup-success'";cwd="."}
    $manifest.commands.test = [pscustomobject]@{run="Write-Output 'consumer-test-success'";cwd="."}
    $manifest.commands.build = [pscustomobject]@{run="Write-Output 'consumer-build-success'";cwd="."}
    $manifest.commands.smoke = [pscustomobject]@{exec="Write-Output";args=@("forward-start");cwd=".";forward_args=$true}
    [IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 20),(New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $consumer "user-owned.txt"),"preserved")
    $before = Fingerprint-RouterConsumer
    # A is a synthetic older version with a stricter schema and matching index.
    $schemaPath = Join-Path $source ".kinotch/schemas/project.schema.json"
    $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $schema.properties.project.properties.name.minLength = $manifest.project.name.Length + 1
    [IO.File]::WriteAllText($schemaPath,($schema | ConvertTo-Json -Depth 40),(New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $source ".kinotch/BASE_VERSION"),"0.0.1"+[Environment]::NewLine)
    $patchPath = Join-Path $source ".kinotch/maintenance-patches.json"
    $patch = Get-Content -LiteralPath $patchPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $patch.authority_base_version = "0.0.1"
    [IO.File]::WriteAllText($patchPath,($patch | ConvertTo-Json -Depth 40),(New-Object System.Text.UTF8Encoding($false)))
    Update-BaseIndex -Root $source
    $commitA = Commit-RouterFixture
    foreach ($path in @("schemas/project.schema.json","BASE_VERSION","maintenance-patches.json","base-files.json","FILE_INVENTORY.txt")) {
        Copy-Item -LiteralPath (Join-Path $root (".kinotch/"+$path)) -Destination (Join-Path $source (".kinotch/"+$path)) -Force
    }
    $commitB = Commit-RouterFixture
    $decision = [pscustomobject]@{repository="fixture/base";channel="fixture";policy_revision="fixture";commit=$commitA;mode="CURRENT"}
    $calls = @{resolve=0}
    $session = @{
        Repository="fixture/base";Channel="fixture";PolicyRevision="fixture";CacheRoot=$cache;Source=$source
        StageRoot=$stages;EmptyTemplate=$template
        ResolveApproved={param($r,$c,$p,$pin) $calls.resolve++; $decision}
        InvokeGit={param($repo,$argv) Run-RouterFixtureGit $repo $argv}
    }
    $invoke = {param($useSnapshot) Invoke-KntReferenceSession @session -UseSnapshot $useSnapshot}
    $run = @{InvokeSession=$invoke;ConsumerRoot=$consumer;PowerShellExecutable=$hostExe}
    $first = Invoke-KntReferenceRouterSession @run -Command doctor
    if ($first.commit -cne $commitA -or $first.exit_code -ne 1 -or ($first.output -join " ") -notmatch "project\.name must have at least") { throw "A schema diagnostic not preserved" }
    $decision.commit=$commitB
    $second = Invoke-KntReferenceRouterSession @run -Command doctor
    if ($second.commit -cne $commitB -or $second.exit_code -ne 0 -or ($second.output -join " ") -notmatch '\[doctor\] OK') { throw "B normal use did not adopt updated revision" }
    $verify = Invoke-KntReferenceRouterSession @run -Command verify
    if ($verify.exit_code -ne 0 -or -not $verify.reused -or ($verify.output -join " ") -notmatch "consumer-test-success") { throw "Consumer command execution failed" }
    $forwarded = @("--marker","-RootOverride","elsewhere","-BaseOverride","another-place","argument with spaces")
    $smoke = Invoke-KntReferenceRouterSession @run -Command smoke -Arguments $forwarded
    if ($smoke.exit_code -ne 0 -or $smoke.commit -cne $commitB) { throw "Structured argument forwarding failed" }
    foreach ($value in $forwarded) {
        if ($smoke.output -cnotcontains $value) { throw "Forwarded argument changed or became a Router option: $value" }
    }
    $legacy = Invoke-KntReferenceRouterSession @run -Command test -Arguments @("unexpected")
    if ($legacy.exit_code -eq 0 -or ($legacy.output -join " ") -notmatch "cannot safely forward arguments") { throw "Legacy forwarding was not rejected" }
    # A verification sequence must resolve once, use the same commit for
    # all three steps and stop after the first failed step.
    $decision.commit=$commitA
    $badVerification = Invoke-KntReferenceVerificationSession @run
    if ($badVerification.commit -cne $commitA -or $badVerification.exit_code -ne 1 -or
        @($badVerification.steps).Count -ne 1 -or $badVerification.steps[0].command -cne "doctor" -or
        $calls.resolve -ne 6) { throw "Verification failed to stop after doctor" }
    $decision.commit=$commitB
    $goodVerification = Invoke-KntReferenceVerificationSession @run
    if ($goodVerification.exit_code -ne 0 -or $goodVerification.commit -cne $commitB -or
        @($goodVerification.steps).Count -ne 3 -or
        ($goodVerification.steps[1].output -join " ") -notmatch "consumer-setup-success" -or
        ($goodVerification.steps[2].output -join " ") -notmatch "consumer-test-success" -or
        $calls.resolve -ne 7) { throw "Verification sequence did not share one resolution" }
    foreach ($stepResult in $goodVerification.steps) {
        if ($stepResult.commit -cne $commitB -or $stepResult.mode -cne "CURRENT") { throw "Verification revision changed" }
    }
    # Central host entry using pre-retained fixture revisions, no public fetch.
    $trustedHostRoot = Join-Path $temp "host"
    $hostCache = Join-Path (Join-Path $trustedHostRoot "cache") "1380962239"
    New-Item -ItemType Directory -Path $hostCache -Force | Out-Null
    foreach ($sha in @($commitA,$commitB)) {
        Copy-Item -LiteralPath (Join-Path $cache $sha) -Destination (Join-Path $hostCache $sha) -Recurse
    }
    $hostDecision = [pscustomobject]@{repository="kinoko34077/kinotch-repository-base";repository_id=[long]1380962239;channel="fixture";policy_revision="fixture";commit=$commitB;mode="CURRENT"}
    $hostCalls = @{resolve=0}
    $hostInvocation = @{
        HostRoot=$trustedHostRoot; GitExecutable=$git; PowerShellExecutable=$hostExe
        ConsumerRoot=$consumer; Channel="fixture"; PolicyRevision="fixture"
        ResolveApproved={param($r,$c,$p,$pin) $hostCalls.resolve++; $hostDecision}
    }
    $hostVerified = Invoke-KntBaseHostCommand @hostInvocation -Verification
    if ($hostVerified.exit_code -ne 0 -or $hostVerified.repository_id -ne 1380962239 -or
        $hostVerified.commit -cne $commitB -or -not $hostVerified.reused -or $hostCalls.resolve -ne 1) { throw "Central host verification failed" }
    $hostDecision.mode="OFFLINE"
    $hostOffline = Invoke-KntBaseHostCommand @hostInvocation -Command doctor
    if ($hostOffline.exit_code -ne 0 -or $hostOffline.mode -cne "OFFLINE" -or $hostCalls.resolve -ne 2) { throw "Ordinary offline command failed" }
    $rejectedOfflineVerification=$false
    try { Invoke-KntBaseHostCommand @hostInvocation -Verification | Out-Null }
    catch { if ($_.Exception.Message -notmatch "requires CURRENT") { throw }; $rejectedOfflineVerification=$true }
    if (-not $rejectedOfflineVerification -or $hostCalls.resolve -ne 3 -or
        @(Get-ChildItem -LiteralPath $trustedHostRoot -Filter "session-*").Count -ne 0) { throw "Offline formal verification was not rejected or cleaned" }
    Move-Item -LiteralPath $source -Destination (Join-Path $temp "offline")
    $decision.mode="OFFLINE"
    $decision.commit=$commitA
    $offline = Invoke-KntReferenceRouterSession @run -Command doctor
    if ($offline.mode -cne "OFFLINE" -or $offline.exit_code -ne 1 -or -not $offline.reused) { throw "Offline previous revision failed" }
    $rejected=$false
    try { Invoke-KntReferenceRouterSession @run -Command reference-path | Out-Null }
    catch { if ($_.Exception.Message -notmatch "outside the reference Router adapter scope") {throw};$rejected=$true }
    if (-not $rejected -or $calls.resolve -ne 8) { throw "Out-of-scope command resolved a revision" }
    if (@(Get-ChildItem -LiteralPath $stages -Force).Count -ne 0 -or (Fingerprint-RouterConsumer) -cne $before) { throw "Stage leak or consumer mutation" }
    Write-Host "[PASS] Reference verification session: one resolution, same SHA, ordered doctor/setup/verify, first failure, formal offline rejection, central host entry"
    Write-Host "[PASS] Reference Router session: protected A/B, exact revision and exit, verify, structured arguments, legacy rejection, cache reuse, offline, no consumer change"
}
finally {
    foreach ($v in @(Get-ChildItem Env: | Where-Object {$_.Name -like "GIT_*"})) {Remove-Item -LiteralPath ("Env:"+$v.Name)}
    foreach ($key in $saved.Keys) {Set-Item -LiteralPath ("Env:"+$key) -Value $saved[$key]}
    Remove-Item -LiteralPath $temp -Recurse -Force
}
