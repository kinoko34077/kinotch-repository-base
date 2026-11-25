# Thin adapter for a previously admitted snapshot. No version selection,
# Git fetching, Default resolution or production admission is implemented here.
function Invoke-KntReferenceRouter {
    param(
        [Parameter(Mandatory=$true)][string]$SnapshotRoot,
        [Parameter(Mandatory=$true)][string]$ConsumerRoot,
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable,
        [Parameter(Mandatory=$true)][string]$Commit,
        [Parameter(Mandatory=$true)][string]$Mode,
        [Parameter(Mandatory=$true)][string]$Command,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments = @()
    )
    Assert-KntReferenceCommit $Commit
    if ($Mode -cnotin @("CURRENT","OFFLINE")) { throw "Invalid admitted reference mode" }
    # This candidate exposes only normal Project commands and diagnostics.
    # Migration/administration/deploy need their own accepted authority.
    Assert-KntReferenceRouterCommand $Command
    foreach ($root in @($SnapshotRoot,$ConsumerRoot)) { Assert-KntReferenceDirectory $root }
    if ((Test-KntProjectPathContained -Root $SnapshotRoot -Candidate $ConsumerRoot -AllowRoot) -or
        (Test-KntProjectPathContained -Root $ConsumerRoot -Candidate $SnapshotRoot -AllowRoot)) {
        throw "Snapshot and consumer must have independent roots"
    }
    if (-not [IO.Path]::IsPathRooted($PowerShellExecutable) -or
        -not (Test-Path -LiteralPath $PowerShellExecutable -PathType Leaf)) {
        throw "Trusted PowerShell executable unavailable"
    }
    $base = Assert-KntSafePath -Root $SnapshotRoot -Candidate (Join-Path $SnapshotRoot ".kinotch") -Description "Reference Base root"
    $router = Assert-KntSafePath -Root $SnapshotRoot -Candidate (Join-Path $base "scripts/knt.ps1") -Description "Reference Router"
    if (-not (Test-Path -LiteralPath $router -PathType Leaf)) { throw "Reference Router missing" }
    # The native -File parameter binder differs between Windows PowerShell
    # and pwsh. Bind forwarded argument data explicitly in the trusted child.
    $child = Join-Path $PSScriptRoot "reference-router-child.ps1"
    if (-not (Test-Path -LiteralPath $child -PathType Leaf)) { throw "Trusted Router child missing" }
    $payload = Assert-KntSafePath -Root $SnapshotRoot -Candidate (Join-Path $SnapshotRoot (".knt-router-" + [guid]::NewGuid().ToString("N") + ".json")) -Description "Router session input"
    $createdPayload = $false
    $previous = $ErrorActionPreference
    try {
        $packet = [pscustomobject]@{ router=$router; consumer=$ConsumerRoot; base=$base; command=$Command; arguments=@($Arguments) }
        $stream = [IO.File]::Open($payload,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $createdPayload = $true
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($packet | ConvertTo-Json -Depth 8 -Compress))
            $stream.Write($bytes,0,$bytes.Length)
        }
        finally { $stream.Dispose() }
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = $null
        $output = @(& $PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $child -PayloadPath $payload 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
        if ($createdPayload -and (Test-Path -LiteralPath $payload)) { Remove-Item -LiteralPath $payload -Force -ErrorAction Stop }
    }
    if ($null -eq $code) { throw "Reference Router produced no exit code" }
    return [pscustomobject]@{
        command=$Command; commit=$Commit; mode=$Mode; exit_code=[int]$code
        output=@($output | ForEach-Object { [string]$_ })
    }
}

# Invoke inside a trusted host/session. The session owns resolution, pinning,
# cache, checkout and cleanup. Preserve its result and the exact native status.
function Invoke-KntReferenceRouterSession {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$InvokeSession,
        [Parameter(Mandatory=$true)][string]$ConsumerRoot,
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable,
        [Parameter(Mandatory=$true)][string]$Command,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments = @()
    )
    $routerConsumer = $ConsumerRoot
    $routerHost = $PowerShellExecutable
    $routerCommand = $Command
    $routerArguments = @($Arguments)
    Assert-KntReferenceRouterCommand $routerCommand
    $use = { param($snapshot,$selectedCommit,$selectedMode)
        Invoke-KntReferenceRouter -SnapshotRoot $snapshot -ConsumerRoot $routerConsumer -PowerShellExecutable $routerHost -Commit $selectedCommit -Mode $selectedMode -Command $routerCommand -Arguments $routerArguments
    }
    $session = & $InvokeSession $use
    if ($null -eq $session -or @($session.result).Count -ne 1) { throw "Invalid Router session result" }
    $result = $session.result[0]
    if ($result.commit -cne $session.commit -or $result.mode -cne $session.mode -or
        $result.command -cne $routerCommand -or $result.exit_code -isnot [int]) {
        throw "Router result identity mismatch"
    }
    return [pscustomobject]@{
        repository=$session.repository; repository_id=$session.repository_id; channel=$session.channel; policy_revision=$session.policy_revision
        commit=$session.commit; mode=$session.mode; reused=$session.reused
        command=$result.command; exit_code=$result.exit_code; output=$result.output
    }
}

function Assert-KntReferenceRouterCommand([string]$Command) {
    if ($Command -cnotin @("doctor","base-check","setup","dev","test","build","verify","smoke","generated-integrity","pwa-check","help")) {
        throw "Command is outside the reference Router adapter scope"
    }
}

# This is the existing Verify workflow's execution sequence, not the devflow
# evidence evaluator. No decision to skip or admit a check is made here.
function Invoke-KntReferenceVerificationSession {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$InvokeSession,
        [Parameter(Mandatory=$true)][string]$ConsumerRoot,
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable
    )
    $verificationConsumer = $ConsumerRoot
    $verificationHost = $PowerShellExecutable
    $verificationCommands = @("doctor","setup","verify")
    $use = { param($snapshot,$selectedCommit,$selectedMode)
        if ($selectedMode -cne "CURRENT") { throw "Formal verification requires CURRENT reference admission" }
        foreach ($step in $verificationCommands) {
            $result = Invoke-KntReferenceRouter -SnapshotRoot $snapshot -ConsumerRoot $verificationConsumer -PowerShellExecutable $verificationHost -Commit $selectedCommit -Mode $selectedMode -Command $step
            $result
            if ($result.exit_code -ne 0) { break }
        }
    }
    $session = & $InvokeSession $use
    if ($null -eq $session -or $session.mode -cne "CURRENT") { throw "Invalid verification session mode" }
    $results = @($session.result)
    if ($results.Count -lt 1 -or $results.Count -gt $verificationCommands.Count) { throw "Invalid verification session result count" }
    for ($i=0;$i -lt $results.Count;$i++) {
        $result = $results[$i]
        if ($result.commit -cne $session.commit -or $result.mode -cne $session.mode -or
            $result.command -cne $verificationCommands[$i] -or $result.exit_code -isnot [int] -or
            ($i -lt ($results.Count-1) -and $result.exit_code -ne 0)) {
            throw "Verification session result identity/order mismatch"
        }
    }
    $exitCode = $results[-1].exit_code
    if ($results.Count -lt $verificationCommands.Count -and $exitCode -eq 0) { throw "Incomplete verification session" }
    return [pscustomobject]@{
        repository=$session.repository; repository_id=$session.repository_id
        channel=$session.channel; policy_revision=$session.policy_revision
        commit=$session.commit; mode=$session.mode; reused=$session.reused
        exit_code=$exitCode; steps=$results
    }
}

# Central host entry. A trusted installation owns these functions and the
# resolver, cache location, runtime and policy. Never load a resolver supplied
# by a consumer repository. No production install or policy admission here.
function Invoke-KntBaseHostCommand {
    [CmdletBinding(DefaultParameterSetName="Command")]
    param(
        [Parameter(Mandatory=$true)][string]$HostRoot,
        [Parameter(Mandatory=$true)][string]$GitExecutable,
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable,
        [Parameter(Mandatory=$true)][string]$ConsumerRoot,
        [Parameter(Mandatory=$true)][string]$Channel,
        [Parameter(Mandatory=$true)][string]$PolicyRevision,
        [Parameter(Mandatory=$true)][scriptblock]$ResolveApproved,
        [string]$PinnedCommit = "",
        [Parameter(Mandatory=$true,ParameterSetName="Command")][string]$Command,
        [Parameter(ParameterSetName="Command")][AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments = @(),
        [Parameter(Mandatory=$true,ParameterSetName="Verification")][switch]$Verification
    )
    Assert-KntReferenceDirectory $HostRoot
    Assert-KntReferenceDirectory $ConsumerRoot
    if ((Test-KntProjectPathContained -Root $HostRoot -Candidate $ConsumerRoot -AllowRoot) -or
        (Test-KntProjectPathContained -Root $ConsumerRoot -Candidate $HostRoot -AllowRoot)) {
        throw "Trusted host root and consumer must be independent"
    }
    $baseHostParameters = @{
        HostRoot=$HostRoot; GitExecutable=$GitExecutable
        Repository="kinoko34077/kinotch-repository-base"; RepositoryId=[long]1380962239
        Channel=$Channel; PolicyRevision=$PolicyRevision
        ResolveApproved=$ResolveApproved; PinnedCommit=$PinnedCommit
    }
    $baseHostSession = {param($callback) Invoke-KntPublicReferenceSession @baseHostParameters -UseSnapshot $callback}
    $adapter = @{InvokeSession=$baseHostSession;ConsumerRoot=$ConsumerRoot;PowerShellExecutable=$PowerShellExecutable}
    if ($PSCmdlet.ParameterSetName -eq "Verification") {
        if (-not $Verification) { throw "Verification mode must be explicitly selected" }
        Invoke-KntReferenceVerificationSession @adapter
    }
    else {
        Invoke-KntReferenceRouterSession @adapter -Command $Command -Arguments $Arguments
    }
}

# New Project seed only, in a disposable root. The admitted snapshot owns
# the shared templates and doctor/schema checks; the trusted host owns Verify.
# No Project commands, repository writes, workflow execution or authorization.
function Get-KntReferenceProjectSeed {
    param(
        [Parameter(Mandatory=$true)][string]$SnapshotRoot,
        [Parameter(Mandatory=$true)][string]$Commit,
        [Parameter(Mandatory=$true)][string]$Mode,
        [Parameter(Mandatory=$true)][string]$ScratchRoot,
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable,
        [Parameter(Mandatory=$true)][string]$ManifestJson,
        [Parameter(Mandatory=$true)][string]$DefaultsJson,
        [AllowEmptyString()][string]$Specification = "",
        [Parameter(Mandatory=$true)][string]$TrustedVerifyContent
    )
    Assert-KntReferenceCommit $Commit
    if ($Mode -cne "CURRENT") { throw "Reference Bootstrap requires CURRENT admission" }
    Assert-KntReferenceDirectory $SnapshotRoot
    Assert-KntReferenceDirectory $ScratchRoot
    $manifest = $ManifestJson | ConvertFrom-Json -ErrorAction Stop
    # Fixed initial layout, not a second Base schema. The admitted doctor
    # handles the full manifest/default/contract semantics and compatibility.
    foreach ($pair in @(@("docs","docs/"),@("actions","contracts/actions.json"),@("surfaces","contracts/surfaces.json"),@("defaults","defaults.json"))) {
        if ($manifest.paths.($pair[0]) -cne $pair[1]) { throw "Reference seed requires the standard Project path: $($pair[0])" }
    }
    if ([string]::IsNullOrWhiteSpace($TrustedVerifyContent)) { throw "Trusted Verify seed unavailable" }
    $templateMap = [ordered]@{
        "AGENTS.md" = "project/templates/reference/AGENTS.md"
        "knt.cmd" = "project/templates/reference/knt.cmd"
        "project/docs/INDEX.md" = ".kinotch/templates/project/docs/INDEX.md"
        "project/docs/CURRENT_STATE.md" = ".kinotch/templates/project/docs/CURRENT_STATE.md"
        "project/docs/SPEC.md" = ".kinotch/templates/project/docs/SPEC.md"
        "project/contracts/actions.json" = ".kinotch/templates/project/contracts/actions.json"
        "project/contracts/surfaces.json" = ".kinotch/templates/project/contracts/surfaces.json"
    }
    $files = [ordered]@{}
    foreach ($path in $templateMap.Keys) {
        $template = Assert-KntSafePath -Root $SnapshotRoot -Candidate (Join-Path $SnapshotRoot $templateMap[$path]) -Description "Reference seed template"
        if (-not (Test-Path -LiteralPath $template -PathType Leaf)) { throw "Required central seed template missing" }
        $files[$path] = Get-Content -LiteralPath $template -Raw -Encoding UTF8
    }
    $files["project/docs/CURRENT_STATE.md"] = $files["project/docs/CURRENT_STATE.md"].Replace(
        "Repository initialized from KiNoTch. Repository Base template.",
        "Repository initialized from the central reference-only Base seed; no local Base implementation."
    )
    if ($Specification) { $files["project/docs/SPEC.md"] = $Specification }
    else {
        $files["project/docs/SPEC.md"] = $files["project/docs/SPEC.md"].Replace(
            "Keep common behavior in .kinotch/**.","Keep common behavior in the central Repository Base."
        )
    }
    $files["project/project.json"] = $ManifestJson
    $files["project/defaults.json"] = $DefaultsJson
    $files[".github/workflows/verify.yml"] = $TrustedVerifyContent
    $stage = Assert-KntSafePath -Root $ScratchRoot -Candidate (Join-Path $ScratchRoot ("seed-" + [guid]::NewGuid().ToString("N"))) -Description "Reference seed stage"
    New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
    try {
        foreach ($path in $files.Keys) {
            $dest = Assert-KntSafePath -Root $stage -Candidate (Join-Path $stage $path) -Description "Reference seed file"
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            [IO.File]::WriteAllText($dest,[string]$files[$path],(New-Object System.Text.UTF8Encoding($false)))
        }
        # Only diagnostics. Do not run untrusted Project setup/test commands.
        $diagnosis = Invoke-KntReferenceRouter -SnapshotRoot $SnapshotRoot -ConsumerRoot $stage -PowerShellExecutable $PowerShellExecutable -Commit $Commit -Mode $Mode -Command doctor
        if ($diagnosis.exit_code -ne 0) { throw "Reference seed did not pass the admitted Base doctor" }
        return [pscustomobject]@{commit=$Commit;mode=$Mode;files=$files;doctor_exit_code=$diagnosis.exit_code}
    }
    finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop }
}

function Invoke-KntReferenceSeedSession {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$InvokeSession,
        [Parameter(Mandatory=$true)][string]$ScratchRoot,
        [Parameter(Mandatory=$true)][string]$PowerShellExecutable,
        [Parameter(Mandatory=$true)][string]$ManifestJson,
        [Parameter(Mandatory=$true)][string]$DefaultsJson,
        [AllowEmptyString()][string]$Specification = "",
        [Parameter(Mandatory=$true)][string]$TrustedVerifyContent
    )
    $seedInputs = @{
        ScratchRoot=$ScratchRoot; PowerShellExecutable=$PowerShellExecutable
        ManifestJson=$ManifestJson; DefaultsJson=$DefaultsJson
        Specification=$Specification; TrustedVerifyContent=$TrustedVerifyContent
    }
    $use = { param($snapshot,$selectedCommit,$selectedMode)
        Get-KntReferenceProjectSeed @seedInputs -SnapshotRoot $snapshot -Commit $selectedCommit -Mode $selectedMode
    }
    $session = & $InvokeSession $use
    if ($null -eq $session -or @($session.result).Count -ne 1 -or $session.mode -cne "CURRENT") {
        throw "Invalid reference seed session"
    }
    $result = $session.result[0]
    if ($result.commit -cne $session.commit -or $result.mode -cne $session.mode -or $result.doctor_exit_code -ne 0) {
        throw "Reference seed session identity mismatch"
    }
    return [pscustomobject]@{
        repository=$session.repository; repository_id=$session.repository_id
        channel=$session.channel; policy_revision=$session.policy_revision
        commit=$session.commit; mode=$session.mode; files=$result.files
        doctor_exit_code=$result.doctor_exit_code
    }
}
