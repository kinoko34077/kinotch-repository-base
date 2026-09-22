param(
    [Parameter(Mandatory=$true)][ValidateSet("open", "save", "save_as")][string]$Action,
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Content,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$resolved = [IO.Path]::GetFullPath((Join-Path $Root $Path))
$rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]@("/", "\")) + [IO.Path]::DirectorySeparatorChar
if (-not $resolved.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "File path is outside the Project root"
    exit 1
}

if ($Action -eq "open") {
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { Write-Error "File not found: $Path"; exit 1 }
    Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved
    exit 0
}

$parent = Split-Path -Parent $resolved
New-Item -ItemType Directory -Path $parent -Force | Out-Null
[IO.File]::WriteAllText($resolved, [string]$Content, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "File $Action: $Path"
exit 0
