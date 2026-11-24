# Offline bundle inspection only. Caller establishes trusted expected metadata.
# No extraction, execution, network access, cache admission or attestation claim.
function Test-KntReferenceBundle {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][ValidatePattern('^sha256:[0-9a-f]{64}$')][string]$ExpectedDigest,
        [Parameter(Mandatory=$true)][ValidateRange(1,16777216)][long]$ExpectedSize,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedCommit,
        [Parameter(Mandatory=$true)][ValidatePattern('^base-ref-v1-[0-9]{8}$')][string]$ExpectedTag
    )
    $ErrorActionPreference = "Stop"
    Add-Type -AssemblyName System.IO.Compression
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {
        if ($stream.Length -ne $ExpectedSize) { throw "Bundle size mismatch" }
        $hash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash.ToLowerInvariant()
        if (("sha256:" + $hash) -cne $ExpectedDigest) { throw "Bundle digest mismatch" }
        $stream.Position = 0
        $zip = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$true)
        try {
            if ($zip.Entries.Count -gt 2048) { throw "Too many bundle entries" }
            $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $exact = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $fixed = @("reference-bundle.json",".editorconfig",".gitattributes",".gitignore",".github/workflows/verify.yml","AGENTS.md","knt.cmd")
            $total = [long]0
            $metadata = $null
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName
                if ($name.Length -gt 240 -or $name -cnotmatch '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$') { throw "Unsafe bundle path" }
                foreach ($segment in $name.Split('/')) {
                    if ($segment.Length -gt 120 -or $segment -eq '.' -or $segment -eq '..' -or $segment.EndsWith('.') -or
                        $segment -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)') { throw "Unsafe bundle path segment" }
                }
                if (-not $name.StartsWith(".kinotch/",[StringComparison]::Ordinal) -and $name -cnotin $fixed) { throw "Unexpected bundle root" }
                if (-not $paths.Add($name)) { throw "Duplicate or case-colliding bundle path" }
                [void]$exact.Add($name)
                # ZIP external attributes: DOS directory/reparse, Unix non-regular file types.
                $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
                if (($entry.ExternalAttributes -band 0x410) -ne 0 -or ($unixType -ne 0 -and $unixType -ne 0x8000)) { throw "Non-regular bundle entry" }
                if ($entry.Length -lt 0 -or $entry.Length -gt (64MB - $total)) { throw "Bundle expanded size exceeds limit" }
                $total += $entry.Length
                if ($name -ceq "reference-bundle.json") { $metadata = $entry }
            }
            foreach ($name in $exact) {
                $parent = $name
                while ($parent.Contains('/')) {
                    $parent = $parent.Substring(0,$parent.LastIndexOf('/'))
                    if ($paths.Contains($parent)) { throw "Bundle file-parent collision" }
                }
            }
            foreach ($name in ($fixed + @(".kinotch/BASE_VERSION",".kinotch/base-files.json",".kinotch/scripts/knt.ps1"))) {
                if (-not $exact.Contains($name)) { throw "Missing required bundle entry: $name" }
            }
            if ($metadata.Length -gt 4096) { throw "Bundle metadata too large" }
            $ms = $metadata.Open()
            try {
                $buffer = New-Object byte[] 4097
                $count = 0
                while ($count -lt $buffer.Length) {
                    $read = $ms.Read($buffer,$count,$buffer.Length-$count)
                    if ($read -eq 0) { break }
                    $count += $read
                }
                if ($count -gt 4096 -or $count -ne $metadata.Length) { throw "Invalid bundle metadata size" }
                $utf8 = [Text.UTF8Encoding]::new($false,$true)
                $data = $utf8.GetString($buffer,0,$count) | ConvertFrom-Json
            } finally { $ms.Dispose() }
            if (($data.schema_version -isnot [int] -and $data.schema_version -isnot [long]) -or $data.schema_version -ne 1 -or
                $data.source_commit -isnot [string] -or $data.source_commit -cne $ExpectedCommit -or
                $data.release_tag -isnot [string] -or $data.release_tag -cne $ExpectedTag) {
                throw "Bundle identity mismatch"
            }
            return [pscustomobject]@{ digest=$ExpectedDigest; size=$ExpectedSize; source_commit=$ExpectedCommit; release_tag=$ExpectedTag; entries=$exact.Count; declared_expanded_bytes=$total }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
}
