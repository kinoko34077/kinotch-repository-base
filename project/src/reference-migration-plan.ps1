# Non-mutating legacy snapshot migration preflight.
# SourceCommit must come from a trusted historical Base authority, not the
# consumer's self-reported index. This plans a Git-tree change, never deletes files.
function Get-KntMigrationTreeEntry {
    param([string]$RepositoryPath,[string]$Commit,[string]$Path,[scriptblock]$InvokeGit)
    $lines = @(& $InvokeGit $RepositoryPath @("ls-tree","--full-tree",$Commit,"--",$Path))
    if ($lines.Count -eq 0) { return $null }
    if ($lines.Count -ne 1 -or [string]$lines[0] -cnotmatch '\A([0-9]{6}) (blob|tree|commit) ([0-9a-f]{40})\t(.+)\z') {
        throw "Invalid Git tree entry"
    }
    if ($Matches[4] -cne $Path) { throw "Unexpected Git tree entry" }
    return [pscustomobject]@{ mode=$Matches[1]; type=$Matches[2]; sha=$Matches[3] }
}

function Get-KntLegacyReferenceMigrationPlan {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRepositoryPath,
        [Parameter(Mandatory=$true)][string]$SourceCommit,
        [Parameter(Mandatory=$true)][string]$ConsumerRepositoryPath,
        [Parameter(Mandatory=$true)][string]$ConsumerCommit,
        [Parameter(Mandatory=$true)][scriptblock]$InvokeGit
    )
    foreach ($sha in @($SourceCommit,$ConsumerCommit)) { Assert-KntReferenceCommit $sha }
    foreach ($path in @($SourceRepositoryPath,$ConsumerRepositoryPath)) { Assert-KntReferenceDirectory $path }
    foreach ($identity in @(@{path=$SourceRepositoryPath;sha=$SourceCommit},@{path=$ConsumerRepositoryPath;sha=$ConsumerCommit})) {
        if ([string](& $InvokeGit $identity.path @("cat-file","-t",$identity.sha)) -cne "commit") { throw "Migration identity is not a commit" }
    }
    # Source index is read only from the admitted historical commit. Its root
    # entries determine the existing protected host files, not a new inventory.
    $sourceIndexText = @(& $InvokeGit $SourceRepositoryPath @("show",($SourceCommit + ":.kinotch/base-files.json"))) -join [Environment]::NewLine
    $index = $sourceIndexText | ConvertFrom-Json -ErrorAction Stop
    if ([int]$index.schema_version -ne 1 -or -not $index.files -or $index.PSObject.Properties["maintenance_patches"]) {
        throw "Unsupported historical Base index"
    }
    $sourceTree = Get-KntMigrationTreeEntry $SourceRepositoryPath $SourceCommit ".kinotch" $InvokeGit
    $consumerTree = Get-KntMigrationTreeEntry $ConsumerRepositoryPath $ConsumerCommit ".kinotch" $InvokeGit
    if ($null -eq $sourceTree -or $sourceTree.type -cne "tree" -or $sourceTree.mode -cne "040000") { throw "Historical Base tree missing" }
    $items = New-Object System.Collections.Generic.List[object]
    $matches = $null -ne $consumerTree -and $consumerTree.type -ceq "tree" -and $consumerTree.mode -ceq $sourceTree.mode -and $consumerTree.sha -ceq $sourceTree.sha
    [void]$items.Add([pscustomobject]@{
        path=".kinotch"; source_sha=$sourceTree.sha; consumer_sha=if ($consumerTree) {$consumerTree.sha} else {$null}
        action=if ($matches) {"RETIRE_CANDIDATE"} else {"PRESERVE_CONFLICT"}
    })
    $canPlan = $matches
    $seen = @{}
    foreach ($entry in @($index.files)) {
        $path = [string]$entry.path
        if ($path -cmatch '\A\.kinotch/') { continue }
        # The only root replacements in the initial reference migration are
        # host entry points. All other root configuration remains consumer-owned.
        if ($path -cnotmatch '\A(?:\.editorconfig|\.gitattributes|\.gitignore|AGENTS\.md|knt\.cmd|\.github/workflows/verify\.yml)\z' -or $seen.ContainsKey($path)) {
            throw "Unsupported protected root entry"
        }
        $seen[$path] = $true
        $source = Get-KntMigrationTreeEntry $SourceRepositoryPath $SourceCommit $path $InvokeGit
        $consumer = Get-KntMigrationTreeEntry $ConsumerRepositoryPath $ConsumerCommit $path $InvokeGit
        if ($null -eq $source -or $source.type -cne "blob" -or $source.mode -cnotmatch '\A100(644|755)\z') { throw "Historical root file missing or invalid" }
        $same = $null -ne $consumer -and $source.sha -ceq $consumer.sha -and $source.mode -ceq $consumer.mode -and $consumer.type -ceq "blob"
        $entryPoint = $path -cin @("AGENTS.md","knt.cmd",".github/workflows/verify.yml")
        $action = if ($entryPoint -and $same) {"REPLACE_ENTRY_CANDIDATE"} elseif ($entryPoint) {"PRESERVE_CONFLICT"} else {"KEEP"}
        if ($action -eq "PRESERVE_CONFLICT") { $canPlan = $false }
        [void]$items.Add([pscustomobject]@{path=$path;source_sha=$source.sha;consumer_sha=if ($consumer) {$consumer.sha} else {$null};action=$action})
    }
    foreach ($required in @("AGENTS.md","knt.cmd",".github/workflows/verify.yml")) {
        if (-not $seen.ContainsKey($required)) { throw "Historical Base lacks required entry point" }
    }
    # Candidate only: before applying, require exact candidate identity, clean
    # working state (if local), approved thin replacements and post-change tests.
    return [pscustomobject]@{
        schema_version=1; source_commit=$SourceCommit; consumer_commit=$ConsumerCommit
        source_version=[string]$index.base_version; status=if ($canPlan) {"CANDIDATE"} else {"HOLD"}
        items=$items.ToArray()
    }
}

# Build and inspect a migration candidate only in a disposable independent snapshot.
# Replacement contents are supplied by the trusted host, not a consumer manifest.
# No consumer ref, worktree, index or source cache is changed by this function.
function Invoke-KntLegacyReferenceMigrationCandidate {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRepositoryPath,
        [Parameter(Mandatory=$true)][string]$SourceCommit,
        [Parameter(Mandatory=$true)][string]$ConsumerCache,
        [Parameter(Mandatory=$true)][string]$ConsumerCommit,
        [Parameter(Mandatory=$true)][string]$StageRoot,
        [Parameter(Mandatory=$true)][string]$EmptyTemplate,
        [Parameter(Mandatory=$true)][System.Collections.IDictionary]$ReplacementFiles,
        [Parameter(Mandatory=$true)][scriptblock]$InvokeGit,
        [Parameter(Mandatory=$true)][scriptblock]$UseCandidate
    )
    $expected = @("AGENTS.md","knt.cmd",".github/workflows/verify.yml")
    if (@($ReplacementFiles.Keys).Count -ne $expected.Count) { throw "Exactly three trusted host entry replacements are required" }
    foreach ($path in $expected) {
        if (@($ReplacementFiles.Keys) -cnotcontains $path -or $ReplacementFiles[$path] -isnot [string] -or [string]::IsNullOrWhiteSpace($ReplacementFiles[$path])) {
            throw "Missing or invalid trusted host entry replacement: $path"
        }
    }
    $stage = New-KntReferenceSnapshot -Cache $ConsumerCache -Commit $ConsumerCommit -StageRoot $StageRoot -EmptyTemplate $EmptyTemplate -InvokeGit $InvokeGit
    try {
        $plan = Get-KntLegacyReferenceMigrationPlan -SourceRepositoryPath $SourceRepositoryPath -SourceCommit $SourceCommit -ConsumerRepositoryPath $stage -ConsumerCommit $ConsumerCommit -InvokeGit $InvokeGit
        if ($plan.status -cne "CANDIDATE") { throw "Legacy migration plan is HOLD; no candidate applied" }
        if (@(& $InvokeGit $stage @("status","--porcelain")).Count -ne 0) { throw "Independent migration snapshot is not clean" }
        $oldTree = [string](& $InvokeGit $stage @("rev-parse",($ConsumerCommit+"^{tree}")))
        $retired = @(Get-KntMigrationTreeEntry $stage $ConsumerCommit ".kinotch" $InvokeGit)
        if ($retired.Count -ne 1 -or $retired[0].type -cne "tree") { throw "Legacy Base tree missing" }
        # The sole destructive operation targets our newly created stage only.
        & $InvokeGit $stage @("rm","-r","--quiet","--",".kinotch") | Out-Null
        foreach ($path in $expected) {
            $target = Assert-KntSafePath -Root $stage -Candidate (Join-Path $stage $path) -Description "Migration entry replacement"
            [IO.File]::WriteAllText($target,[string]$ReplacementFiles[$path],(New-Object System.Text.UTF8Encoding($false)))
        }
        & $InvokeGit $stage (@("add","--")+$expected) | Out-Null
        $tree = [string](& $InvokeGit $stage @("write-tree"))
        Assert-KntReferenceCommit $tree
        $changes = @(& $InvokeGit $stage @("diff-tree","-r","--name-status","--no-renames",$ConsumerCommit,$tree))
        $seen = @()
        $removed = 0
        foreach ($line in $changes) {
            if ($line -cmatch '\AD\t\.kinotch/.+\z') { $removed++; continue }
            if ($line -cmatch '\AM\t(.+)\z' -and $expected -ccontains $Matches[1] -and $seen -cnotcontains $Matches[1]) {
                $seen += $Matches[1]
                continue
            }
            throw "Migration candidate contains an unexpected tree change"
        }
        if ($removed -lt 1 -or $seen.Count -ne $expected.Count -or (Test-Path -LiteralPath (Join-Path $stage ".kinotch"))) {
            throw "Incomplete legacy Base retirement or host entry replacement"
        }
        # Verify the real candidate with the trusted caller, still in the stage.
        $result = @(& $UseCandidate $stage $tree $plan)
        # Restoration is explicitly tested in the same disposable repository.
        & $InvokeGit $stage @("reset","--hard","--quiet",$ConsumerCommit) | Out-Null
        if ([string](& $InvokeGit $stage @("write-tree")) -cne $oldTree -or
            @(& $InvokeGit $stage @("status","--porcelain")).Count -ne 0) {
            throw "Independent migration rollback did not restore the exact tree"
        }
        return [pscustomobject]@{
            source_commit=$SourceCommit; consumer_commit=$ConsumerCommit; candidate_tree=$tree
            restored_tree=$oldTree; removed_base_files=$removed; replaced_entries=$expected
            result=$result; applied_to_consumer=$false
        }
    }
    finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop
    }
}
