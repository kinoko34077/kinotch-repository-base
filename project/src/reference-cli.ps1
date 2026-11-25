# Invoke from a separately trusted host installation, never a consumer checkout.
# Layout: <host>/base-source/project/src/reference-cli.ps1
# <host>/reference-host-profile.ps1 is installed by the trusted host owner.
# No installation, admission policy, or permissions are changed here.
$ErrorActionPreference = "Stop"
try {
    if ($args.Count -lt 2) { throw "Usage: reference-cli.ps1 <consumer-root> <command|verification> [arguments...]" }
    $consumer = [string]$args[0]
    $verb = [string]$args[1]
    $forward = @()
    if ($args.Count -gt 2) { $forward = [string[]]@($args[2..($args.Count-1)]) }
    $sourceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if ((Split-Path -Leaf $sourceRoot) -cne "base-source") { throw "Reference CLI requires a trusted host installation" }
    $hostRoot = Split-Path -Parent $sourceRoot
    . (Join-Path $sourceRoot ".kinotch/scripts/path-containment.ps1")
    . (Join-Path $PSScriptRoot "reference-snapshot.ps1")
    . (Join-Path $PSScriptRoot "reference-host.ps1")
    . (Join-Path $PSScriptRoot "reference-router.ps1")
    Assert-KntReferenceDirectory $hostRoot
    Assert-KntReferenceDirectory $sourceRoot
    Assert-KntReferenceDirectory $consumer
    if ((Test-KntProjectPathContained -Root $hostRoot -Candidate $consumer -AllowRoot) -or
        (Test-KntProjectPathContained -Root $consumer -Candidate $hostRoot -AllowRoot)) {
        throw "Trusted host root and consumer must be independent"
    }
    if ($verb -ceq "verification") {
        if ($forward.Count -ne 0) { throw "Verification takes no forwarded arguments" }
    }
    else { Assert-KntReferenceRouterCommand $verb }
    $profilePath = Assert-KntSafePath -Root $hostRoot -Candidate (Join-Path $hostRoot "reference-host-profile.ps1") -Description "Trusted host profile"
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) { throw "Trusted host profile unavailable" }
    $profile = & $profilePath
    if ($profile -isnot [System.Collections.IDictionary] -or
        $profile.ResolveApproved -isnot [scriptblock] -or
        $profile.GitExecutable -isnot [string] -or [string]::IsNullOrWhiteSpace($profile.GitExecutable) -or
        $profile.Channel -isnot [string] -or [string]::IsNullOrWhiteSpace($profile.Channel) -or
        $profile.PolicyRevision -isnot [string] -or [string]::IsNullOrWhiteSpace($profile.PolicyRevision)) {
        throw "Invalid trusted host profile"
    }
    $call = @{
        HostRoot=$hostRoot; GitExecutable=$profile.GitExecutable
        PowerShellExecutable=(Get-Process -Id $PID).Path; ConsumerRoot=$consumer
        Channel=$profile.Channel; PolicyRevision=$profile.PolicyRevision
        ResolveApproved=$profile.ResolveApproved
    }
    if ($profile.Contains("PinnedCommit")) {
        if ($profile.PinnedCommit -isnot [string]) { throw "Invalid host pin" }
        $call.PinnedCommit=$profile.PinnedCommit
    }
    if ($verb -ceq "verification") {
        $result = Invoke-KntBaseHostCommand @call -Verification
        foreach ($step in $result.steps) {
            Write-Host ("[reference] step={0} exit={1}" -f $step.command,$step.exit_code)
            foreach ($line in $step.output) { Write-Host ([string]$line) }
        }
    }
    else {
        $result = Invoke-KntBaseHostCommand @call -Command $verb -Arguments $forward
        foreach ($line in $result.output) { Write-Host ([string]$line) }
    }
    # Diagnostic record, not an independently authenticated CI receipt.
    Write-Host ("[reference] commit={0} mode={1} exit={2}" -f $result.commit,$result.mode,$result.exit_code)
    exit ([int]$result.exit_code)
}
catch {
    # Resolver errors may contain sensitive details. Do not print raw exceptions.
    Write-Host "[reference] Trusted host invocation failed; check host configuration and admission diagnostics." -ForegroundColor Red
    exit 1
}
