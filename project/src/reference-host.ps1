# Trusted host adapter. Load only from a previously trusted installation, never
# from an unverified checkout. Run one session per PowerShell process because
# native environment isolation below is process-wide. No credential handling.
function Invoke-KntIsolatedReferenceGit {
    param(
        [Parameter(Mandatory=$true)][string]$GitExecutable,
        [Parameter(Mandatory=$true)][string]$RepositoryPath,
        [Parameter(Mandatory=$true)][string[]]$GitArguments,
        [Parameter(Mandatory=$true)][string]$EmptyConfig,
        [Parameter(Mandatory=$true)][string]$EmptyHooks
    )
    Assert-KntReferenceDirectory $RepositoryPath
    Assert-KntReferenceDirectory $EmptyHooks
    if (-not [IO.Path]::IsPathRooted($GitExecutable) -or -not (Test-Path -LiteralPath $GitExecutable -PathType Leaf)) { throw "Trusted Git executable unavailable" }
    if (-not [IO.Path]::IsPathRooted($EmptyConfig) -or
        -not (Test-Path -LiteralPath $EmptyConfig -PathType Leaf) -or
        (Get-Item -LiteralPath $EmptyConfig -Force).Length -ne 0 -or
        @(Get-ChildItem -LiteralPath $EmptyHooks -Force).Count -ne 0) { throw "Reference Git isolation files are invalid" }
    $saved = @{}
    foreach ($item in @(Get-ChildItem Env: | Where-Object { $_.Name -like "GIT_*" -or $_.Name -in @("GCM_INTERACTIVE","SSH_ASKPASS") })) {
        $saved[$item.Name] = $item.Value
    }
    $ErrorActionPreference = "Continue"
    try {
        foreach ($key in $saved.Keys) { Remove-Item -LiteralPath ("Env:" + $key) -ErrorAction Stop }
        $env:GIT_CONFIG_NOSYSTEM = "1"
        $env:GIT_CONFIG_GLOBAL = $EmptyConfig
        $env:GIT_ATTR_NOSYSTEM = "1"
        $env:GIT_NO_REPLACE_OBJECTS = "1"
        $env:GIT_TERMINAL_PROMPT = "0"
        $env:GIT_OPTIONAL_LOCKS = "0"
        $env:GCM_INTERACTIVE = "never"
        # Only the two transports needed by the trusted core. No redirects,
        # credential helper, inherited global config, hooks or fsmonitor.
        $isolatedArgs = @("-C",$RepositoryPath,
            "-c","core.hooksPath=$EmptyHooks","-c","core.attributesFile=$EmptyConfig",
            "-c","core.fsmonitor=false","-c","core.autocrlf=false","-c","core.protectHFS=true","-c","core.protectNTFS=true",
            "-c","protocol.allow=never","-c","protocol.file.allow=always","-c","protocol.https.allow=always",
            "-c","http.followRedirects=false","-c","http.sslVerify=true","-c","http.extraHeader=",
            "-c","credential.helper=","-c","core.askPass=","-c","gc.auto=0","-c","maintenance.auto=false")
        $output = @(& $GitExecutable @isolatedArgs @GitArguments 2>$null)
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "Isolated reference Git failed (exit $code)" }
        return $output
    }
    finally {
        foreach ($item in @(Get-ChildItem Env: | Where-Object { $_.Name -like "GIT_*" -or $_.Name -in @("GCM_INTERACTIVE","SSH_ASKPASS") })) {
            Remove-Item -LiteralPath ("Env:" + $item.Name)
        }
        foreach ($key in $saved.Keys) { Set-Item -LiteralPath ("Env:" + $key) -Value $saved[$key] }
    }
}

function New-KntReferenceHostDirectory([string]$Root,[string]$Name) {
    $path = Assert-KntSafePath -Root $Root -Candidate (Join-Path $Root $Name) -Description "Reference host directory"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null
    }
    Assert-KntReferenceDirectory $path
    return $path
}

# Candidate host entry for a trusted public repository decision. The caller must
# own the pre-established host-only root (outside the consumer), Git executable,
# resolver and user authorization. This is not an admission-policy implementation.
function Invoke-KntPublicReferenceSession {
    param(
        [Parameter(Mandatory=$true)][string]$HostRoot,
        [Parameter(Mandatory=$true)][string]$GitExecutable,
        [Parameter(Mandatory=$true)][string]$Repository,
        [Parameter(Mandatory=$true)][long]$RepositoryId,
        [Parameter(Mandatory=$true)][string]$Channel,
        [Parameter(Mandatory=$true)][string]$PolicyRevision,
        [Parameter(Mandatory=$true)][scriptblock]$ResolveApproved,
        [Parameter(Mandatory=$true)][scriptblock]$UseSnapshot,
        [string]$PinnedCommit = ""
    )
    $ErrorActionPreference = "Stop"
    Assert-KntReferenceDirectory $HostRoot
    [void](Get-KntPublicReferenceOrigin $Repository)
    if ($RepositoryId -le 0) { throw "Trusted numeric repository identity required" }
    $cacheParent = New-KntReferenceHostDirectory $HostRoot "cache"
    $cache = New-KntReferenceHostDirectory $cacheParent ([string]$RepositoryId)
    $session = Assert-KntSafePath -Root $HostRoot -Candidate (Join-Path $HostRoot ("session-" + [guid]::NewGuid().ToString("N"))) -Description "Reference session root"
    New-Item -ItemType Directory -Path $session -ErrorAction Stop | Out-Null
    try {
        $stages = New-KntReferenceHostDirectory $session "stages"
        $emptyTemplate = New-KntReferenceHostDirectory $session "template"
        $emptyHooks = New-KntReferenceHostDirectory $session "hooks"
        $emptyConfig = Join-Path $session "gitconfig"
        [IO.File]::WriteAllText($emptyConfig,"",(New-Object System.Text.UTF8Encoding($false)))
        $invokeGit = {
            param($repoPath,$gitArgs)
            Invoke-KntIsolatedReferenceGit -GitExecutable $GitExecutable -RepositoryPath $repoPath -GitArguments $gitArgs -EmptyConfig $emptyConfig -EmptyHooks $emptyHooks
        }
        Invoke-KntReferenceSession -Repository $Repository -RepositoryId $RepositoryId -Channel $Channel -PolicyRevision $PolicyRevision -CacheRoot $cache -PublicGitHub -StageRoot $stages -EmptyTemplate $emptyTemplate -ResolveApproved $ResolveApproved -InvokeGit $invokeGit -UseSnapshot $UseSnapshot -PinnedCommit $PinnedCommit
    }
    finally {
        Remove-Item -LiteralPath $session -Recurse -Force -ErrorAction Stop
    }
}
