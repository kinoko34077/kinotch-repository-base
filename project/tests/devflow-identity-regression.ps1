$ErrorActionPreference = "Stop"

# Issue #14 regression contract: Base bootstrap references must use the live devflow identity.
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$CurrentIdentity = "kinoko34077/devflow"
$FormerIdentity = "kinoko34077/devflow-test"

$targets = @(
    ".kinotch/meta/08_GITHUB_DEVELOPMENT_CONTROL.md",
    ".kinotch/AGENT_RULES.md",
    ".kinotch/README_BASE.md",
    "AGENTS.md",
    "README.md"
)

$failed = 0
foreach ($relative in $targets) {
    $path = Join-Path $RepoRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($text -match [regex]::Escape($FormerIdentity)) {
        Write-Host "[FAIL] stale current-use devflow identity remains in $relative" -ForegroundColor Red
        $failed++
    }
}

$control = Get-Content -LiteralPath (Join-Path $RepoRoot ".kinotch/meta/08_GITHUB_DEVELOPMENT_CONTROL.md") -Raw -Encoding UTF8
$agentRules = Get-Content -LiteralPath (Join-Path $RepoRoot ".kinotch/AGENT_RULES.md") -Raw -Encoding UTF8
$expectedRepositoryLine = 'Repository: `' + $CurrentIdentity + '`'

if ($control -notmatch [regex]::Escape($expectedRepositoryLine)) {
    Write-Host "[FAIL] integration canon does not identify the current devflow repository" -ForegroundColor Red
    $failed++
}
if ($agentRules -notmatch [regex]::Escape("$CurrentIdentity/docs/spec/CROSS_REPOSITORY_DEVELOPMENT_CONTROL.md")) {
    Write-Host "[FAIL] Agent rules do not point to the current devflow canonical specification" -ForegroundColor Red
    $failed++
}

if ($failed -gt 0) { exit 1 }
Write-Host "[PASS] current devflow identity is canonical throughout Base entry references"
exit 0
