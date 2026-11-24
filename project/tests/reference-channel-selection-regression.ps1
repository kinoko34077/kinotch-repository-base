$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $PSScriptRoot) "src/reference-channel-selection.ps1")
function New-Release([int]$Sequence) {
    [pscustomobject]@{
        id = [long](100 + $Sequence)
        tag_name = "base-ref-v1-{0:D8}" -f $Sequence
        draft = $false
        immutable = $true
        prerelease = $false
        author = [pscustomobject]@{id=79015263;login="kinoko34077"}
        assets = @([pscustomobject]@{id=[long](200+$Sequence);name="kinotch-base.zip";state="uploaded";digest=("sha256:" + ("a"*64))})
    }
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action | Out-Null }
    catch {
        if ($_.Exception.Message -match $Pattern) { return }
        throw
    }
    throw "Expected rejection: $Pattern"
}
$old = New-Release 1
$new = New-Release 2
$draft = New-Release 3
$draft.draft = $true
$new.prerelease = $true # mutable display flag must not determine selection
$r = Select-KntReferenceRelease -Releases @($new,$draft,$old) -Complete
if ($r.sequence -ne 2 -or $r.asset_id -ne 202 -or $r.pinned) { throw "Latest selection failed" }
$r = Select-KntReferenceRelease -Releases @($old,$new) -Complete -MinimumSequence 2 -PinnedSequence 1
if ($r.sequence -ne 1 -or -not $r.pinned) { throw "Explicit pin failed" }
Assert-Throws { Select-KntReferenceRelease -Releases @($old) -Complete -MinimumSequence 2 } "downgrade"
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$new) -Complete -PinnedSequence 3 } "Unknown pinned"
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$new) } "incomplete"
Assert-Throws { Select-KntReferenceRelease -Releases @() -Complete } "No published"
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$old) -Complete } "duplicate"
$bad = New-Release 3; $bad.tag_name = "base-ref-v1-3"
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "Invalid channel tag"
$bad = New-Release 3; $bad.immutable = $false
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "not immutable"
$bad = New-Release 3; $bad.immutable = "true"
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "not immutable"
$bad = New-Release 3; $bad.author.id = 1
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "Unexpected publisher"
$bad = New-Release 3; $bad.assets = @()
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "exactly one"
$bad = New-Release 3; $bad.assets = @($bad.assets[0],$bad.assets[0])
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "exactly one"
$bad = New-Release 3; $bad.assets[0].digest = "sha256:bad"
Assert-Throws { Select-KntReferenceRelease -Releases @($old,$bad) -Complete } "Invalid bundle"
Write-Host "[PASS] Reference channel selection: 14 synthetic cases"
exit 0
