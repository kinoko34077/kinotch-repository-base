function Get-BaseProtectedPaths {
    param([Parameter(Mandatory=$true)][string]$Root)

    $fixed = @(
        ".editorconfig",
        ".gitattributes",
        ".gitignore",
        ".github/workflows/verify.yml",
        "AGENTS.md",
        "knt.cmd"
    )
    $common = @(Get-ChildItem -LiteralPath (Join-Path $Root ".kinotch") -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length).TrimStart([char]92) -replace "\\", "/"
        if ($relative -ne ".kinotch/base-files.json") { $relative }
    })

    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($fixed + $common)) {
        if (-not $paths.Contains($path)) { [void]$paths.Add($path) }
    }
    $paths.Sort([System.StringComparer]::Ordinal)
    return $paths.ToArray()
}

function Update-BaseIndex {
    param([Parameter(Mandatory=$true)][string]$Root)

    $manifestPath = Join-Path $Root "project/project.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "project/project.json not found: $manifestPath"
    }
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    if ($manifest.project.type -ne "repository-base") {
        throw "base-refresh is only available for project.type repository-base"
    }

    $protectedPaths = @(Get-BaseProtectedPaths -Root $Root)
    $inventoryPath = Join-Path $Root ".kinotch/FILE_INVENTORY.txt"
    [IO.File]::WriteAllText($inventoryPath, ($protectedPaths -join [Environment]::NewLine) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($relative in $protectedPaths) {
        $path = Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Base protected file not found: $relative"
        }
        [void]$entries.Add([pscustomobject]@{
            path = $relative
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
        })
    }

    $version = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $Root ".kinotch/BASE_VERSION")).Trim()
    $index = [pscustomobject]@{
        schema_version = 1
        base_version = $version
        files = $entries.ToArray()
    }
    $json = ConvertTo-Json $index -Depth 10
    [IO.File]::WriteAllText((Join-Path $Root ".kinotch/base-files.json"), $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

if ($PSBoundParameters.ContainsKey("Root")) {
    Update-BaseIndex -Root $Root
}
