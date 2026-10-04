function Get-KntBaseSnapshotHash {
    param([Parameter(Mandatory=$true)]$Entries)

    $lines = @($Entries | Sort-Object { [string]$_.path } | ForEach-Object {
        ([string]$_.path) + "=" + ([string]$_.sha256)
    })
    return Get-BaseTextHash -Text (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Get-KntMaintenancePatchCatalog {
    $catalogPath = Join-Path $BaseDir "maintenance-patches.json"
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Base maintenance patch catalog not found: $catalogPath"
    }

    $catalog = Get-KntJson -Path $catalogPath
    if ([int]$catalog.schema_version -ne 1) {
        throw "unsupported Base maintenance patch catalog schema"
    }
    if ([string]::IsNullOrWhiteSpace([string]$catalog.authority_base_version)) {
        throw "Base maintenance patch catalog is missing authority_base_version"
    }

    $ids = @{}
    foreach ($patch in @($catalog.patches)) {
        $id = [string]$patch.id
        if ([string]::IsNullOrWhiteSpace($id) -or $ids.ContainsKey($id)) {
            throw "Base maintenance patch catalog has a missing or duplicate patch id"
        }
        $ids[$id] = $true
        if ([string]::IsNullOrWhiteSpace([string]$patch.source_base_version)) {
            throw "Base maintenance patch '$id' is missing source_base_version"
        }

        $paths = @{}
        foreach ($file in @($patch.files)) {
            $path = ([string]$file.path).Replace("\\", "/").TrimStart("/")
            if ([string]::IsNullOrWhiteSpace($path) -or $path -match "(^|/)\.\.(/|$)" -or $paths.ContainsKey($path)) {
                throw "Base maintenance patch '$id' has an invalid or duplicate file path"
            }
            $paths[$path] = $true

            foreach ($field in @("source_sha256", "target_sha256")) {
                $value = [string]$file.$field
                if ($value -notmatch "^[0-9a-f]{64}$") {
                    throw "Base maintenance patch '$id' has invalid $field for '$path'"
                }
            }

            $contentPath = ([string]$file.content_path).Replace("\\", "/").TrimStart("/")
            if ([string]::IsNullOrWhiteSpace($contentPath) -or $contentPath -match "(^|/)\.\.(/|$)") {
                throw "Base maintenance patch '$id' has invalid content_path for '$path'"
            }
            $payload = Join-Path $BaseDir $contentPath
            [void](Assert-KntSafePath -Root $BaseDir -Candidate $payload -Description "maintenance patch payload")
            if (-not (Test-Path -LiteralPath $payload -PathType Leaf)) {
                throw "Base maintenance patch '$id' payload is missing for '$path'"
            }
            if ((Get-BaseFileHash -Path $payload) -ne [string]$file.target_sha256) {
                throw "Base maintenance patch '$id' payload hash does not match target_sha256 for '$path'"
            }
        }
    }
    return $catalog
}

function Find-KntMaintenancePatch {
    param(
        [Parameter(Mandatory=$true)]$Catalog,
        [Parameter(Mandatory=$true)][string]$Id
    )

    $matches = @($Catalog.patches | Where-Object { [string]$_.id -eq $Id })
    if ($matches.Count -ne 1) {
        throw "Unknown Base maintenance patch '$Id'"
    }
    return $matches[0]
}

function Test-KntMaintenancePatchProvenance {
    param([Parameter(Mandatory=$true)]$Index)

    if (-not $Index.PSObject.Properties["maintenance_patches"]) { return $true }

    $state = $Index.maintenance_patches
    $ok = $true
    if ([int]$state.schema_version -ne 1) {
        Write-Host "[base-check] PATCH_SCHEMA unsupported maintenance patch provenance" -ForegroundColor Yellow
        return $false
    }
    if ([string]$state.source_base_version -ne [string]$Index.base_version) {
        Write-Host "[base-check] PATCH_SOURCE source_base_version does not match base_version" -ForegroundColor Yellow
        $ok = $false
    }
    if ([string]$state.source_snapshot_sha256 -notmatch "^[0-9a-f]{64}$") {
        Write-Host "[base-check] PATCH_SOURCE invalid source snapshot hash" -ForegroundColor Yellow
        $ok = $false
    }

    $catalogPath = Join-Path $BaseDir "maintenance-patches.json"
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        Write-Host "[base-check] PATCH_CATALOG missing maintenance-patches.json" -ForegroundColor Yellow
        return $false
    }
    $catalogHash = Get-BaseFileHash -Path $catalogPath
    if ($catalogHash -ne [string]$state.catalog_sha256) {
        Write-Host "[base-check] PATCH_CATALOG catalog hash does not match recorded provenance" -ForegroundColor Yellow
        $ok = $false
    }

    try { $catalog = Get-KntMaintenancePatchCatalog }
    catch {
        Write-Host "[base-check] PATCH_CATALOG $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }

    $finalHashes = @{}
    foreach ($entry in @($Index.files)) {
        $finalHashes[[string]$entry.path] = [string]$entry.sha256
    }

    foreach ($support in @($state.support_files)) {
        $path = [string]$support.path
        if (-not $finalHashes.ContainsKey($path) -or $finalHashes[$path] -ne [string]$support.sha256) {
            Write-Host "[base-check] PATCH_SUPPORT invalid support-file provenance for $path" -ForegroundColor Yellow
            $ok = $false
        }
    }

    $patches = @($state.patches)
    $seenIds = @{}
    foreach ($record in $patches) {
        $id = [string]$record.id
        if ([string]::IsNullOrWhiteSpace($id) -or $seenIds.ContainsKey($id)) {
            Write-Host "[base-check] PATCH_ID missing or duplicate patch id" -ForegroundColor Yellow
            $ok = $false
            continue
        }
        $seenIds[$id] = $true

        try { $definition = Find-KntMaintenancePatch -Catalog $catalog -Id $id }
        catch {
            Write-Host "[base-check] PATCH_ID $($_.Exception.Message)" -ForegroundColor Yellow
            $ok = $false
            continue
        }

        if ([string]$record.authority_base_version -ne [string]$catalog.authority_base_version -or
            [string]$definition.source_base_version -ne [string]$state.source_base_version) {
            Write-Host "[base-check] PATCH_AUTHORITY invalid authority/source version for $id" -ForegroundColor Yellow
            $ok = $false
        }

        $definedFiles = @($definition.files | Sort-Object { [string]$_.path })
        $recordedFiles = @($record.files | Sort-Object { [string]$_.path })
        if ($definedFiles.Count -ne $recordedFiles.Count) {
            Write-Host "[base-check] PATCH_FILES file-count mismatch for $id" -ForegroundColor Yellow
            $ok = $false
            continue
        }
        for ($i = 0; $i -lt $definedFiles.Count; $i++) {
            $defined = $definedFiles[$i]
            $recorded = $recordedFiles[$i]
            if ([string]$defined.path -ne [string]$recorded.path -or
                [string]$defined.source_sha256 -ne [string]$recorded.source_sha256 -or
                [string]$defined.target_sha256 -ne [string]$recorded.target_sha256) {
                Write-Host "[base-check] PATCH_FILES catalog/provenance mismatch for $id" -ForegroundColor Yellow
                $ok = $false
            }
        }
    }

    $sourceHashes = @{}
    foreach ($entry in @($Index.files)) {
        $sourceHashes[[string]$entry.path] = [string]$entry.sha256
    }
    for ($patchIndex = $patches.Count - 1; $patchIndex -ge 0; $patchIndex--) {
        foreach ($file in @($patches[$patchIndex].files)) {
            $path = [string]$file.path
            if (-not $sourceHashes.ContainsKey($path) -or $sourceHashes[$path] -ne [string]$file.target_sha256) {
                Write-Host "[base-check] PATCH_CHAIN target hash mismatch for $path" -ForegroundColor Yellow
                $ok = $false
            }
            $sourceHashes[$path] = [string]$file.source_sha256
        }
    }
    foreach ($support in @($state.support_files)) {
        if ([bool]$support.added) {
            [void]$sourceHashes.Remove([string]$support.path)
        }
    }

    $sourceEntries = @($sourceHashes.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{ path = [string]$_.Key; sha256 = [string]$_.Value }
    })
    if ((Get-KntBaseSnapshotHash -Entries $sourceEntries) -ne [string]$state.source_snapshot_sha256) {
        Write-Host "[base-check] PATCH_SOURCE reconstructed source snapshot does not match provenance" -ForegroundColor Yellow
        $ok = $false
    }

    if ($ok) {
        Write-Knt ("Base maintenance patches: " + (($patches | ForEach-Object { [string]$_.id }) -join ", "))
    }
    return $ok
}

function Get-KntMaintenancePatchOptions {
    $id = $null
    $apply = $false
    $values = @($RemainingArgs)

    for ($index = 0; $index -lt $values.Count; $index++) {
        $value = [string]$values[$index]
        if ($value -eq "--apply") {
            $apply = $true
            continue
        }
        if ($value -eq "--id") {
            if ($index + 1 -ge $values.Count) {
                throw "base-patch requires a value after --id"
            }
            $id = [string]$values[++$index]
            continue
        }
        if ($value -like "--id=*") {
            $id = $value.Substring("--id=".Length)
            continue
        }
        throw "Unknown base-patch option: $value"
    }

    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "base-patch requires --id <patch-id>"
    }
    return [pscustomobject]@{ id = $id; apply = $apply }
}

function Invoke-KntBasePatch {
    if ([string]::IsNullOrWhiteSpace($RootOverride) -or [string]::IsNullOrWhiteSpace($BaseOverride)) {
        throw "base-patch requires -RootOverride <consumer> and -BaseOverride <repository-base .kinotch>"
    }

    $authorityRoot = Split-Path -Parent $BaseDir
    $authorityManifestPath = Join-Path $authorityRoot "project/project.json"
    if (-not (Test-Path -LiteralPath $authorityManifestPath -PathType Leaf)) {
        throw "base-patch authority is missing project/project.json"
    }
    $authorityManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $authorityManifestPath | ConvertFrom-Json
    if ([string]$authorityManifest.project.type -ne "repository-base") {
        throw "base-patch authority must be project.type repository-base"
    }

    $catalog = Get-KntMaintenancePatchCatalog
    $authorityVersion = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $BaseDir "BASE_VERSION")).Trim()
    if ([string]$catalog.authority_base_version -ne $authorityVersion) {
        throw "maintenance patch catalog authority_base_version does not match active Base"
    }

    $options = Get-KntMaintenancePatchOptions
    $definition = Find-KntMaintenancePatch -Catalog $catalog -Id ([string]$options.id)

    $targetBaseDir = Join-Path $Root ".kinotch"
    $targetIndexPath = Join-Path $targetBaseDir "base-files.json"
    $targetVersionPath = Join-Path $targetBaseDir "BASE_VERSION"
    if (-not (Test-Path -LiteralPath $targetIndexPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $targetVersionPath -PathType Leaf)) {
        throw "base-patch target requires a repository-local Base index and BASE_VERSION"
    }
    [void](Assert-KntSafePath -Root $Root -Candidate $targetBaseDir -Description "base-patch target Base" -AllowRoot)

    $index = Get-Content -Raw -Encoding UTF8 -LiteralPath $targetIndexPath | ConvertFrom-Json
    $targetVersion = (Get-Content -Raw -Encoding UTF8 -LiteralPath $targetVersionPath).Trim()
    if ([string]$index.base_version -ne $targetVersion -or
        [string]$definition.source_base_version -ne $targetVersion) {
        throw "Base maintenance patch '$($definition.id)' does not apply to target Base version '$targetVersion'"
    }

    $existingPatches = @()
    if ($index.PSObject.Properties["maintenance_patches"]) {
        $existingPatches = @($index.maintenance_patches.patches)
        if (@($existingPatches | Where-Object { [string]$_.id -eq [string]$definition.id }).Count -gt 0) {
            Write-Knt "Base maintenance patch '$($definition.id)' is already recorded"
            return 0
        }
    }

    $entryMap = @{}
    foreach ($entry in @($index.files)) {
        $entryMap[[string]$entry.path] = $entry
    }

    foreach ($file in @($definition.files)) {
        $path = [string]$file.path
        if (-not $entryMap.ContainsKey($path)) {
            throw "Base maintenance patch '$($definition.id)' cannot add protected target '$path'; full Base adoption is required"
        }
        if ([string]$entryMap[$path].sha256 -ne [string]$file.source_sha256) {
            throw "Base maintenance patch '$($definition.id)' source index hash does not match '$path'"
        }

        $targetPath = Join-Path $Root $path
        [void](Assert-KntSafePath -Root $Root -Candidate $targetPath -Description "base-patch target file")
        if ((Get-BaseFileHash -Path $targetPath) -ne [string]$file.source_sha256) {
            throw "Base maintenance patch '$($definition.id)' source content drifted for '$path'"
        }
    }

    if (-not $options.apply) {
        Write-Knt "Base maintenance patch dry-run: $($definition.id)"
        foreach ($file in @($definition.files)) {
            Write-Knt ("  " + [string]$file.path)
        }
        Write-Knt "Re-run with --apply to write only these Base-owned targets."
        return 0
    }

    $sourceSnapshotHash = if ($index.PSObject.Properties["maintenance_patches"]) {
        [string]$index.maintenance_patches.source_snapshot_sha256
    }
    else {
        Get-KntBaseSnapshotHash -Entries @($index.files)
    }

    $catalogPath = Join-Path $BaseDir "maintenance-patches.json"
    $catalogHash = Get-BaseFileHash -Path $catalogPath
    $targetCatalogPath = Join-Path $targetBaseDir "maintenance-patches.json"
    [void](Assert-KntSafeWritePath -Root $Root -Candidate $targetCatalogPath -Description "base-patch catalog write")
    [IO.File]::WriteAllText(
        $targetCatalogPath,
        (Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath),
        (New-Object System.Text.UTF8Encoding($false))
    )

    $catalogWasIndexed = $entryMap.ContainsKey(".kinotch/maintenance-patches.json")
    if ($catalogWasIndexed) {
        $entryMap[".kinotch/maintenance-patches.json"].sha256 = $catalogHash
    }
    else {
        $newEntry = [pscustomobject]@{
            path = ".kinotch/maintenance-patches.json"
            sha256 = $catalogHash
        }
        $index.files = @($index.files) + @($newEntry)
        $entryMap[".kinotch/maintenance-patches.json"] = $newEntry
    }

    foreach ($file in @($definition.files)) {
        $payload = Join-Path $BaseDir ([string]$file.content_path)
        [void](Assert-KntSafePath -Root $BaseDir -Candidate $payload -Description "maintenance patch payload")
        $targetPath = Join-Path $Root ([string]$file.path)
        [void](Assert-KntSafeWritePath -Root $Root -Candidate $targetPath -Description "base-patch target write")
        [IO.File]::WriteAllText(
            $targetPath,
            (Get-Content -Raw -Encoding UTF8 -LiteralPath $payload),
            (New-Object System.Text.UTF8Encoding($false))
        )
        if ((Get-BaseFileHash -Path $targetPath) -ne [string]$file.target_sha256) {
            throw "Base maintenance patch '$($definition.id)' target verification failed for '$($file.path)'"
        }
        $entryMap[[string]$file.path].sha256 = [string]$file.target_sha256
    }

    $record = [pscustomobject]@{
        id = [string]$definition.id
        authority_base_version = $authorityVersion
        files = @($definition.files | ForEach-Object {
            [pscustomobject]@{
                path = [string]$_.path
                source_sha256 = [string]$_.source_sha256
                target_sha256 = [string]$_.target_sha256
            }
        })
    }

    $state = [pscustomobject]@{
        schema_version = 1
        source_base_version = $targetVersion
        source_snapshot_sha256 = $sourceSnapshotHash
        catalog_sha256 = $catalogHash
        support_files = @([pscustomobject]@{
            path = ".kinotch/maintenance-patches.json"
            sha256 = $catalogHash
            added = (-not $catalogWasIndexed)
        })
        patches = @($existingPatches) + @($record)
    }

    if ($index.PSObject.Properties["maintenance_patches"]) {
        $index.maintenance_patches = $state
    }
    else {
        $index | Add-Member -NotePropertyName maintenance_patches -NotePropertyValue $state
    }

    [void](Assert-KntSafeWritePath -Root $Root -Candidate $targetIndexPath -Description "base-patch index write")
    [IO.File]::WriteAllText(
        $targetIndexPath,
        (ConvertTo-Json $index -Depth 20) + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Knt "Applied Base maintenance patch '$($definition.id)' while retaining source Base version '$targetVersion'"
    return 0
}
