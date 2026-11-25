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
    if ($Command -cnotin @("doctor","base-check","setup","dev","test","build","verify","smoke","generated-integrity","pwa-check","help")) {
        throw "Command is outside the reference Router adapter scope"
    }
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
    if ($routerCommand -cnotin @("doctor","base-check","setup","dev","test","build","verify","smoke","generated-integrity","pwa-check","help")) {
        throw "Command is outside the reference Router adapter scope"
    }
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
        repository=$session.repository; channel=$session.channel; policy_revision=$session.policy_revision
        commit=$session.commit; mode=$session.mode; reused=$session.reused
        command=$result.command; exit_code=$result.exit_code; output=$result.output
    }
}
