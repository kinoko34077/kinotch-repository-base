$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $PSScriptRoot) "src/reference-bundle-inspection.ps1")
Add-Type -AssemblyName System.IO.Compression
$root = Join-Path ([IO.Path]::GetTempPath()) ("knt-reference-bundle-" + [guid]::NewGuid().ToString("N"))
[void](New-Item -ItemType Directory -Path $root)
$commit = "a"*40
$tag = "base-ref-v1-00000001"
$fixed = @(".editorconfig",".gitattributes",".gitignore",".github/workflows/verify.yml","AGENTS.md","knt.cmd",".kinotch/BASE_VERSION",".kinotch/base-files.json",".kinotch/scripts/knt.ps1")
function New-Fixture([string]$Name, [string[]]$Extra=@(), [string]$Omit="", [string]$Commit=$commit, [switch]$Link) {
    $path = Join-Path $root ($Name + ".zip")
    $fs = [IO.File]::Open($path,[IO.FileMode]::CreateNew)
    try {
        $zip = [IO.Compression.ZipArchive]::new($fs,[IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($item in @($fixed+$Extra) | Where-Object { $_ -cne $Omit }) {
                $e = $zip.CreateEntry($item)
                if ($Link -and $item -ceq ".kinotch/link") { $e.ExternalAttributes = (-1610612736) } # Unix symlink
                $w = $e.Open()
                try { $w.WriteByte(65) } finally { $w.Dispose() }
            }
            $e = $zip.CreateEntry("reference-bundle.json")
            $w = $e.Open()
            try {
                $bytes = [Text.Encoding]::UTF8.GetBytes((@{schema_version=1;source_commit=$Commit;release_tag=$tag}|ConvertTo-Json -Compress))
                $w.Write($bytes,0,$bytes.Length)
            } finally { $w.Dispose() }
        } finally { $zip.Dispose() }
    } finally { $fs.Dispose() }
    return $path
}
function Inspect([string]$File,[string]$Digest="",[long]$Size=0,[string]$Tag=$tag) {
    if (-not $Digest) { $Digest = "sha256:"+(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant() }
    if ($Size -eq 0) { $Size = (Get-Item -LiteralPath $File).Length }
    Test-KntReferenceBundle -Path $File -ExpectedDigest $Digest -ExpectedSize $Size -ExpectedCommit $commit -ExpectedTag $Tag
}
function Assert-Reject([scriptblock]$Action,[string]$Pattern) {
    try { & $Action | Out-Null }
    catch { if ($_.Exception.Message -match $Pattern) { return }; throw }
    throw "Expected rejection: $Pattern"
}
try {
    $good = New-Fixture "good"
    $r = Inspect $good
    if ($r.entries -ne 10 -or $r.source_commit -cne $commit) { throw "Valid bundle rejected" }
    Assert-Reject { Inspect $good -Digest ("sha256:"+("0"*64)) } "digest mismatch"
    Assert-Reject { Inspect $good -Size 1 } "size mismatch"
    Assert-Reject { Inspect $good -Tag "base-ref-v1-00000002" } "identity mismatch"
    $bad = New-Fixture "commit" -Commit ("b"*40)
    Assert-Reject { Inspect $bad } "identity mismatch"
    $bad = New-Fixture "traversal" -Extra ".kinotch/../escape"
    Assert-Reject { Inspect $bad } "Unsafe bundle path"
    $bad = New-Fixture "case" -Extra ".kinotch/base_version"
    Assert-Reject { Inspect $bad } "case-colliding"
    $bad = New-Fixture "prefix" -Extra @(".kinotch/file",".kinotch/file/child")
    Assert-Reject { Inspect $bad } "file-parent"
    $bad = New-Fixture "device" -Extra ".kinotch/CON.txt"
    Assert-Reject { Inspect $bad } "Unsafe bundle path"
    $bad = New-Fixture "root" -Extra "project/secret.txt"
    Assert-Reject { Inspect $bad } "Unexpected bundle root"
    $bad = New-Fixture "link" -Extra ".kinotch/link" -Link
    Assert-Reject { Inspect $bad } "Non-regular"
    $bad = New-Fixture "missing" -Omit ".kinotch/scripts/knt.ps1"
    Assert-Reject { Inspect $bad } "Missing required"
    Write-Host "[PASS] Reference bundle inspection: 12 synthetic cases, no extraction or execution"
} finally { Remove-Item -LiteralPath $root -Recurse -Force }
exit 0
