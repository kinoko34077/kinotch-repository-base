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
    if ($Commit -cnotmatch '\A[0-9a-f]{40}\z') { throw "Invalid exact commit identity" }
    # These roots must already be established by the trusted host, not consumer input.
    foreach ($root in @($Cache,$StageRoot,$EmptyTemplate)) {
        if (-not [IO.Path]::IsPathRooted($root) -or -not (Test-Path -LiteralPath $root -PathType Container)) {
            throw "Invalid trusted local root"
        }
        if (((Get-Item -LiteralPath $root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Trusted root is a reparse point"
        }
    }
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
