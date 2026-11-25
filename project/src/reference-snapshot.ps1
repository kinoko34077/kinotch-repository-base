# B1.2: cache identity/retention only; never authorizes a revision.
function Assert-KntReferenceDirectory([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Invalid trusted local root"
    }
    if (((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Trusted root is a reparse point"
    }
}

function Assert-KntReferenceCommit([string]$Commit) {
    if ($Commit -cnotmatch '\A[0-9a-f]{40}\z') { throw "Invalid exact commit identity" }
}

function Test-KntRetainedCache([string]$Path,[string]$Commit,[scriptblock]$InvokeGit) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    Assert-KntReferenceDirectory $Path
    if ([string](& $InvokeGit $Path @("rev-parse","--is-bare-repository")) -cne "true" -or
        (Test-Path -LiteralPath (Join-Path $Path "objects/info/alternates"))) {
        throw "Invalid retained cache"
    }
    $actual = [string](& $InvokeGit $Path @("rev-parse","--verify","refs/kinotch/retained/$Commit"))
    if ($actual -cne $Commit -or [string](& $InvokeGit $Path @("cat-file","-t",$actual)) -cne "commit") {
        throw "Retained commit identity mismatch"
    }
    return $true
}

# The host supplies the repository-specific trusted cache root and exact admitted
# commit. Local source only in this prototype; no consumer-controlled URL.
function Receive-KntReferenceCommit {
    param(
        [Parameter(Mandatory=$true)][string]$CacheRoot,
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Commit,
        [Parameter(Mandatory=$true)][string]$EmptyTemplate,
        [Parameter(Mandatory=$true)][scriptblock]$InvokeGit
    )
    Assert-KntReferenceCommit $Commit
    Assert-KntReferenceDirectory $CacheRoot
    Assert-KntReferenceDirectory $EmptyTemplate
    if (@(Get-ChildItem -LiteralPath $EmptyTemplate -Force).Count -ne 0) { throw "Git template must be empty" }
    if (-not [IO.Path]::IsPathRooted($Source)) { throw "Invalid trusted source path" }
    $target = Assert-KntSafePath -Root $CacheRoot -Candidate (Join-Path $CacheRoot $Commit) -Description "Retained cache"
    if (Test-KntRetainedCache $target $Commit $InvokeGit) {
        return [pscustomobject]@{ path=$target; commit=$Commit; reused=$true }
    }
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Source unavailable" }
    Assert-KntReferenceDirectory $Source
    $incoming = Assert-KntSafePath -Root $CacheRoot -Candidate (Join-Path $CacheRoot ("incoming-" + [guid]::NewGuid().ToString("N"))) -Description "Incoming cache"
    New-Item -ItemType Directory -Path $incoming -ErrorAction Stop | Out-Null
    try {
        & $InvokeGit $incoming @("init","--quiet","--bare","--template=$EmptyTemplate") | Out-Null
        # Each fetch owns its shallow metadata. Only the validated directory is
        # published. The native same-parent move never overwrites a cache.
        $ref = "refs/kinotch/retained/$Commit"
        & $InvokeGit $incoming @("-c","fetch.fsckObjects=true","fetch","--quiet","--no-write-fetch-head","--no-tags","--no-recurse-submodules","--depth=1","--no-auto-gc","--",$Source,($Commit + ":" + $ref)) | Out-Null
        if (-not (Test-KntRetainedCache $incoming $Commit $InvokeGit)) { throw "Incoming cache missing" }
        $reused = $false
        try { [IO.Directory]::Move($incoming,$target) }
        catch {
            # Another invocation may have published this exact identity. Never
            # overwrite its directory; any inconsistent existing state fails.
            if (-not (Test-KntRetainedCache $target $Commit $InvokeGit)) { throw }
            $reused = $true
        }
        return [pscustomobject]@{ path=$target; commit=$Commit; reused=$reused }
    }
    finally {
        if (Test-Path -LiteralPath $incoming) { Remove-Item -LiteralPath $incoming -Recurse -Force }
    }
}

# B1: trusted local cache -> independent exact-commit snapshot.
# Internal prototype only. Caller owns trust/admission, isolated Git invocation,
# protected cache/staging roots and lifetime. No network, approval or execution here.
function New-KntReferenceSnapshot {
    param(
        [Parameter(Mandatory=$true)][string]$Cache,
        [Parameter(Mandatory=$true)][string]$Commit,
        [Parameter(Mandatory=$true)][string]$StageRoot,
        [Parameter(Mandatory=$true)][string]$EmptyTemplate,
        [Parameter(Mandatory=$true)][scriptblock]$InvokeGit
    )
    Assert-KntReferenceCommit $Commit
    # These roots must already be established by the trusted host, not consumer input.
    foreach ($root in @($Cache,$StageRoot,$EmptyTemplate)) { Assert-KntReferenceDirectory $root }
    if (@(Get-ChildItem -LiteralPath $EmptyTemplate -Force).Count -ne 0) { throw "Git template must be empty" }
    $stage = Assert-KntSafePath -Root $StageRoot -Candidate (Join-Path $StageRoot ([guid]::NewGuid().ToString("N"))) -Description "Reference stage"
    # Never overwrite an existing stage. The caller owns successful stage cleanup.
    New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
    $completed = $false
    try {
        & $InvokeGit $stage @("init","--quiet","--template=$EmptyTemplate") | Out-Null
        # Native local transport avoids whole-history copies, hardlinks and alternates.
        # A retained ref is only a locator; verify its actual object before checkout.
        & $InvokeGit $stage @("-c","fetch.fsckObjects=true","fetch","--quiet","--no-tags","--no-recurse-submodules","--depth=1",$Cache,"refs/kinotch/retained/$Commit") | Out-Null
        $actual = [string](& $InvokeGit $stage @("rev-parse","--verify","FETCH_HEAD"))
        if ($actual -cne $Commit -or [string](& $InvokeGit $stage @("cat-file","-t",$actual)) -cne "commit") {
            throw "Retained commit identity mismatch"
        }
        foreach ($entry in @(& $InvokeGit $stage @("ls-tree","-r","--full-tree",$Commit))) {
            if ($entry -cnotmatch '\A100(644|755) blob [0-9a-f]{40}\t') { throw "Unsupported snapshot tree entry" }
        }
        & $InvokeGit $stage @("checkout","--quiet","--detach",$Commit) | Out-Null
        if ([string](& $InvokeGit $stage @("rev-parse","--verify","HEAD")) -cne $Commit -or
            (Test-Path -LiteralPath (Join-Path $stage ".git/objects/info/alternates"))) {
            throw "Independent snapshot verification failed"
        }
        $completed = $true
        return $stage
    }
    finally {
        if (-not $completed) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
}

# B1.3: compose one use of a trusted resolution. Not an authority or a live
# launcher. The host owns the resolver, its evidence, roots and Git isolation.
function Invoke-KntReferenceSession {
    param(
        [Parameter(Mandatory=$true)][string]$Repository,
        [Parameter(Mandatory=$true)][string]$Channel,
        [Parameter(Mandatory=$true)][string]$PolicyRevision,
        [Parameter(Mandatory=$true)][string]$CacheRoot,
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$StageRoot,
        [Parameter(Mandatory=$true)][string]$EmptyTemplate,
        [Parameter(Mandatory=$true)][scriptblock]$ResolveApproved,
        [Parameter(Mandatory=$true)][scriptblock]$InvokeGit,
        [Parameter(Mandatory=$true)][scriptblock]$UseSnapshot,
        [string]$PinnedCommit = ""
    )
    if ($PinnedCommit) { Assert-KntReferenceCommit $PinnedCommit }
    # The injected trusted authority, not this function, establishes admission,
    # compatibility, freshness, revocation, and offline eligibility.
    $resolution = & $ResolveApproved $Repository $Channel $PolicyRevision $PinnedCommit
    if ($null -eq $resolution -or $resolution -is [array] -or
        $resolution.repository -isnot [string] -or $resolution.repository -cne $Repository -or
        $resolution.channel -isnot [string] -or $resolution.channel -cne $Channel -or
        $resolution.policy_revision -isnot [string] -or $resolution.policy_revision -cne $PolicyRevision -or
        $resolution.mode -isnot [string] -or
        $resolution.commit -isnot [string]) { throw "Invalid reference resolution identity" }
    # Copy the selected values once. Do not re-resolve after acquisition starts.
    $commit = $resolution.commit
    $mode = $resolution.mode
    Assert-KntReferenceCommit $commit
    if ($PinnedCommit -and $commit -cne $PinnedCommit) { throw "Pinned commit mismatch" }

    if ($mode -ceq "CURRENT") {
        $retained = Receive-KntReferenceCommit -CacheRoot $CacheRoot -Source $Source -Commit $commit -EmptyTemplate $EmptyTemplate -InvokeGit $InvokeGit
    }
    elseif ($mode -ceq "OFFLINE") {
        # OFFLINE is an explicitly admitted cached revision, never an automatic
        # downgrade on rejection, unknown trust, or a failed current fetch.
        Assert-KntReferenceDirectory $CacheRoot
        $cached = Assert-KntSafePath -Root $CacheRoot -Candidate (Join-Path $CacheRoot $commit) -Description "Offline retained cache"
        if (-not (Test-KntRetainedCache $cached $commit $InvokeGit)) { throw "Approved offline revision not retained" }
        $retained = [pscustomobject]@{ path=$cached; commit=$commit; reused=$true }
    }
    else { throw "Reference use not admitted" }

    $stage = New-KntReferenceSnapshot -Cache $retained.path -Commit $commit -StageRoot $StageRoot -EmptyTemplate $EmptyTemplate -InvokeGit $InvokeGit
    try {
        $result = @(& $UseSnapshot $stage $commit $mode)
        return [pscustomobject]@{
            repository=$Repository
            channel=$Channel
            policy_revision=$PolicyRevision
            commit=$commit
            mode=$mode
            reused=$retained.reused
            result=$result
        }
    }
    finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop
    }
}
