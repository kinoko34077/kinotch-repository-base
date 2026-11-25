$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root ".kinotch/scripts/path-containment.ps1")
. (Join-Path $root "project/src/reference-snapshot.ps1")
. (Join-Path $root "project/src/reference-migration-plan.ps1")
$git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$temp = Join-Path ([IO.Path]::GetTempPath()) ("knt-mig-" + [guid]::NewGuid().ToString("N"))
$source = Join-Path $temp "source"
$consumer = Join-Path $temp "consumer"
$template = Join-Path $temp "empty"
New-Item -ItemType Directory -Path @($source,$consumer,$template) -Force | Out-Null
$saved = @{}
foreach ($v in @(Get-ChildItem Env: | Where-Object {$_.Name -like "GIT_*"})) {$saved[$v.Name]=$v.Value}
function Run-MigrationGit([string]$path,[string[]]$argv) {
    $out = @(& $git -C $path -c user.name=Fixture -c user.email=fixture@example.invalid -c "core.hooksPath=$template" -c core.autocrlf=false -c core.longpaths=true -c protocol.file.allow=always @argv)
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed" }
    return $out
}
function Commit-Fixture([string]$path) {
    Run-MigrationGit $path @("add","-f",".") | Out-Null
    Run-MigrationGit $path @("commit","--quiet","-m","fixture") | Out-Null
    return [string](Run-MigrationGit $path @("rev-parse","HEAD"))
}
try {
    foreach ($key in $saved.Keys) { Remove-Item -LiteralPath ("Env:"+$key) }
    $env:GIT_CONFIG_NOSYSTEM="1"
    $env:GIT_CONFIG_GLOBAL=Join-Path $temp "empty-config"
    $env:GIT_TERMINAL_PROMPT="0"
    $env:GIT_NO_REPLACE_OBJECTS="1"
    foreach ($p in @($source,$consumer)) {
        Run-MigrationGit $p @("init","--quiet","--template=$template") | Out-Null
        New-Item -ItemType Directory -Path @((Join-Path $p ".kinotch"),(Join-Path $p ".github/workflows")) -Force | Out-Null
        foreach ($file in @("AGENTS.md","knt.cmd",".github/workflows/verify.yml",".gitignore",".kinotch/shared.ps1")) {
            [IO.File]::WriteAllText((Join-Path $p $file),"fixture $file")
        }
        $index=@{schema_version=1;base_version="fixture";files=@(@{path="AGENTS.md"},@{path="knt.cmd"},@{path=".github/workflows/verify.yml"},@{path=".gitignore"},@{path=".kinotch/shared.ps1"})}
        # Same canonical bytes in both repositories.
        [IO.File]::WriteAllText((Join-Path $p ".kinotch/base-files.json"),'{"schema_version":1,"base_version":"fixture","files":[{"path":"AGENTS.md"},{"path":"knt.cmd"},{"path":".github/workflows/verify.yml"},{"path":".gitignore"},{"path":".kinotch/shared.ps1"}]}')
    }
    $sourceCommit = Commit-Fixture $source
    Copy-Item -LiteralPath (Join-Path $root ".kinotch/tests/fixtures/valid-minimal") -Destination (Join-Path $consumer "project") -Recurse
    $manifestPath = Join-Path $consumer "project/project.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest.commands.test = [pscustomobject]@{run="Write-Output 'migration-project-test-success'";cwd="."}
    [IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 20),(New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $consumer "project-owned.txt"),"project")
    $consumerCommit = Commit-Fixture $consumer
    $argsPlan=@{SourceRepositoryPath=$source;SourceCommit=$sourceCommit;ConsumerRepositoryPath=$consumer;ConsumerCommit=$consumerCommit;InvokeGit={param($p,$a) Run-MigrationGit $p $a}}
    $plan=Get-KntLegacyReferenceMigrationPlan @argsPlan
    if ($plan.status -cne "CANDIDATE" -or @($plan.items | Where-Object action -eq "RETIRE_CANDIDATE").Count -ne 1 -or @($plan.items | Where-Object action -eq "REPLACE_ENTRY_CANDIDATE").Count -ne 3) {throw "Clean plan failed"}
    # A Project-owned root config difference does not prevent unrelated migration.
    [IO.File]::WriteAllText((Join-Path $consumer ".gitignore"),"project config")
    $argsPlan.ConsumerCommit=Commit-Fixture $consumer
    $plan=Get-KntLegacyReferenceMigrationPlan @argsPlan
    if ($plan.status -cne "CANDIDATE" -or ($plan.items | Where-Object path -eq ".gitignore").action -cne "KEEP") {throw "Root config not preserved"}
    # An extra file under the old Base, even when self-reported index is unchanged,
    # blocks its retirement. No deletion or checkout occurs.
    [IO.File]::WriteAllText((Join-Path $consumer ".kinotch/extra.txt"),"preserve")
    $argsPlan.ConsumerCommit=Commit-Fixture $consumer
    $plan=Get-KntLegacyReferenceMigrationPlan @argsPlan
    if ($plan.status -cne "HOLD" -or $plan.items[0].action -cne "PRESERVE_CONFLICT" -or -not (Test-Path -LiteralPath (Join-Path $consumer ".kinotch/extra.txt"))) {throw "Unknown Base file not protected"}
    # Reuse the earlier exact tree as a read-only input, independent of HEAD.
    $argsPlan.ConsumerCommit=$consumerCommit
    $plan=Get-KntLegacyReferenceMigrationPlan @argsPlan
    if ($plan.status -cne "CANDIDATE") {throw "Plan used current worktree instead of requested commit"}
    [IO.File]::WriteAllText((Join-Path $consumer "AGENTS.md"),"custom instructions")
    $argsPlan.ConsumerCommit=Commit-Fixture $consumer
    $plan=Get-KntLegacyReferenceMigrationPlan @argsPlan
    if (($plan.items | Where-Object path -eq "AGENTS.md").action -cne "PRESERVE_CONFLICT") {throw "Custom agent instructions not protected"}
    if (@(Run-MigrationGit $consumer @("status","--porcelain")).Count -ne 0) {throw "Planner modified working tree"}
    $unchangedHead = [string](Run-MigrationGit $consumer @("rev-parse","HEAD"))
    $unchangedTree = [string](Run-MigrationGit $consumer @("write-tree"))
    $cacheRoot = Join-Path $temp "cache"
    $stageRoot = Join-Path $temp "stages"
    New-Item -ItemType Directory -Path @($cacheRoot,$stageRoot) | Out-Null
    $migrationGit = {param($p,$a) Run-MigrationGit $p $a}
    $retained = Receive-KntReferenceCommit -CacheRoot $cacheRoot -Source $consumer -Commit $consumerCommit -EmptyTemplate $template -InvokeGit $migrationGit
    $replacements = @{
        "AGENTS.md"="# synthetic reference-only agent entry"
        "knt.cmd"="@rem synthetic reference-only host entry"
        ".github/workflows/verify.yml"="# synthetic reference-only workflow entry"
    }
    $hostExe = (Get-Process -Id $PID).Path
    $baseDir = Join-Path $root ".kinotch"
    $router = Join-Path $baseDir "scripts/knt.ps1"
    $migrationArgs = @{
        SourceRepositoryPath=$source;SourceCommit=$sourceCommit;ConsumerCache=$retained.path
        ConsumerCommit=$consumerCommit;StageRoot=$stageRoot;EmptyTemplate=$template
        ReplacementFiles=$replacements;InvokeGit=$migrationGit
        UseCandidate={
            param($candidateRoot,$candidateTree,$candidatePlan)
            if (Test-Path -LiteralPath (Join-Path $candidateRoot ".kinotch")) {throw "Local Base was not retired"}
            if ((Get-Content -LiteralPath (Join-Path $candidateRoot "project-owned.txt") -Raw) -cne "project" -or
                (Get-Content -LiteralPath (Join-Path $candidateRoot "AGENTS.md") -Raw) -cne $replacements["AGENTS.md"]) {throw "Migration candidate content mismatch"}
            foreach ($cmd in @("doctor","verify")) {
                $beforePreference = $ErrorActionPreference
                try {
                    $ErrorActionPreference="Continue"
                    $output=@(& $hostExe -NoProfile -ExecutionPolicy Bypass -File $router -RootOverride $candidateRoot -BaseOverride $baseDir -ReferenceMode $cmd 2>&1)
                    $code=$LASTEXITCODE
                } finally {$ErrorActionPreference=$beforePreference}
                if ($code -ne 0) {throw "Migrated candidate $cmd failed: $($output -join ' ')"}
                if ($cmd -eq "verify" -and ($output -join " ") -notmatch "migration-project-test-success") {throw "Migrated Project test did not execute"}
            }
            "candidate-doctor-verify-ok"
        }
    }
    $candidate = Invoke-KntLegacyReferenceMigrationCandidate @migrationArgs
    if ($candidate.applied_to_consumer -or $candidate.consumer_commit -cne $consumerCommit -or
        $candidate.candidate_tree -ceq $candidate.restored_tree -or $candidate.result[0] -cne "candidate-doctor-verify-ok" -or
        @(Get-ChildItem -LiteralPath $stageRoot -Force).Count -ne 0) {throw "Migration candidate proof failed"}
    # A conflicted revision may not reach the callback; its stage is cleaned.
    $conflictCache = Receive-KntReferenceCommit -CacheRoot $cacheRoot -Source $consumer -Commit $unchangedHead -EmptyTemplate $template -InvokeGit $migrationGit
    $migrationArgs.ConsumerCache=$conflictCache.path
    $migrationArgs.ConsumerCommit=$unchangedHead
    $migrationArgs.UseCandidate={throw "Conflicted candidate callback ran"}
    $rejected=$false
    try {Invoke-KntLegacyReferenceMigrationCandidate @migrationArgs | Out-Null}
    catch {if ($_.Exception.Message -notmatch "plan is HOLD") {throw};$rejected=$true}
    if (-not $rejected -or @(Get-ChildItem -LiteralPath $stageRoot -Force).Count -ne 0 -or
        [string](Run-MigrationGit $consumer @("rev-parse","HEAD")) -cne $unchangedHead -or
        [string](Run-MigrationGit $consumer @("write-tree")) -cne $unchangedTree -or
        @(Run-MigrationGit $consumer @("status","--porcelain")).Count -ne 0) {throw "Consumer or cleanup boundary failed"}
    Write-Host "[PASS] Legacy reference migration: exact source and consumer trees, host entry candidates, configuration preservation, extra Base and custom entry rejection, read-only"
    Write-Host "[PASS] Migration candidate: independent tree retirement, trusted entry replacement, real doctor/verify, exact rollback, conflict cleanup, consumer unchanged"
}
finally {
    foreach ($v in @(Get-ChildItem Env: | Where-Object {$_.Name -like "GIT_*"})) {Remove-Item -LiteralPath ("Env:"+$v.Name)}
    foreach ($key in $saved.Keys) {Set-Item -LiteralPath ("Env:"+$key) -Value $saved[$key]}
    Remove-Item -LiteralPath $temp -Recurse -Force
}
