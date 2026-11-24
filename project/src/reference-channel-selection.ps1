# Experimental B0/B1 selection only. No network, I/O, execution or promotion.
# The caller must establish the fixed origin/repository and complete API response.
function Select-KntReferenceRelease {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Releases,
        [switch]$Complete,
        [ValidateRange(0,99999999)][int]$MinimumSequence = 0,
        [ValidateRange(0,99999999)][int]$PinnedSequence = 0
    )
    if (-not $Complete) { throw "Release list is incomplete" }
    $records = @{}
    foreach ($release in $Releases) {
        if ($null -eq $release -or $release.tag_name -isnot [string]) {
            throw "Invalid release record"
        }
        if (-not $release.tag_name.StartsWith("base-ref-v1-", [StringComparison]::Ordinal)) { continue }
        if ($release.draft -isnot [bool]) { throw "Invalid draft flag" }
        if ($release.draft) { continue }
        if ($release.tag_name -cnotmatch '^base-ref-v1-([0-9]{8})$') {
            throw "Invalid channel tag"
        }
        $sequence = [int]$Matches[1]
        if ($sequence -eq 0 -or $records.ContainsKey($sequence)) {
            throw "Invalid or duplicate promotion sequence"
        }
        $records[$sequence] = $release
    }
    if ($records.Count -eq 0) { throw "No published channel candidate" }
    $sequence = if ($PinnedSequence -ne 0) { $PinnedSequence } else {
        [int]($records.Keys | Measure-Object -Maximum).Maximum
    }
    if (-not $records.ContainsKey($sequence)) { throw "Unknown pinned promotion" }
    if ($PinnedSequence -eq 0 -and $sequence -lt $MinimumSequence) {
        throw "Automatic downgrade rejected"
    }
    $selected = $records[$sequence]
    if ($selected.immutable -isnot [bool] -or -not $selected.immutable) {
        throw "Promotion is not immutable"
    }
    if (($selected.author.id -isnot [int] -and $selected.author.id -isnot [long]) -or
        $selected.author.id -ne 79015263 -or $selected.author.login -cne "kinoko34077") {
        throw "Unexpected publisher"
    }
    if (($selected.id -isnot [int] -and $selected.id -isnot [long]) -or $selected.id -le 0) {
        throw "Invalid release identity"
    }
    $assets = @($selected.assets | Where-Object { $_.name -ceq "kinotch-base.zip" })
    if ($assets.Count -ne 1) { throw "Expected exactly one Base bundle" }
    $asset = $assets[0]
    if (($asset.id -isnot [int] -and $asset.id -isnot [long]) -or $asset.id -le 0 -or
        $asset.state -cne "uploaded" -or $asset.digest -isnot [string] -or
        $asset.digest -cnotmatch '^sha256:[0-9a-f]{64}$') {
        throw "Invalid bundle metadata"
    }
    return [pscustomobject]@{
        sequence = $sequence
        tag = $selected.tag_name
        release_id = [long]$selected.id
        asset_id = [long]$asset.id
        digest = $asset.digest
        pinned = ($PinnedSequence -ne 0)
    }
}
