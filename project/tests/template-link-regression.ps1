$ErrorActionPreference = "Stop"

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $TestDir)
$TemplateRoot = Join-Path $RepoRoot ".kinotch/templates/project"

if (-not (Test-Path -LiteralPath $TemplateRoot -PathType Container)) {
    throw "Project template root not found: $TemplateRoot"
}

$broken = New-Object System.Collections.Generic.List[string]
$linkPattern = '\[[^\]]+\]\(([^)]+)\)'

foreach ($markdown in @(Get-ChildItem -LiteralPath $TemplateRoot -Recurse -File -Filter "*.md" -Force)) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $markdown.FullName
    foreach ($match in [regex]::Matches($text, $linkPattern)) {
        $target = [string]$match.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        if ($target -match '^(?:https?://|mailto:|#)') { continue }

        $pathPart = ($target -split '[?#]', 2)[0]
        if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }

        $candidate = [IO.Path]::GetFullPath((Join-Path $markdown.DirectoryName $pathPart))
        $templateRootFull = [IO.Path]::GetFullPath($TemplateRoot)
        $comparison = if ($env:OS -eq "Windows_NT") { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
        $prefix = $templateRootFull.TrimEnd([char[]]@('/', '\\')) + [IO.Path]::DirectorySeparatorChar
        if (-not $candidate.StartsWith($prefix, $comparison)) {
            [void]$broken.Add("$($markdown.FullName): link escapes template root: $target")
            continue
        }
        if (-not (Test-Path -LiteralPath $candidate)) {
            [void]$broken.Add("$($markdown.FullName): missing relative link target: $target")
        }
    }
}

if ($broken.Count -gt 0) {
    throw "Broken Base project-template Markdown links:`n - " + ($broken -join "`n - ")
}

Write-Host "Template link regression: PASS" -ForegroundColor Green
