$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ContainmentHelper = Join-Path $RepoRoot ".kinotch/scripts/path-containment.ps1"
$McpHelper = Join-Path $RepoRoot ".kinotch/templates/defaults/mcp/tools/mcp-default.ps1"
. $ContainmentHelper
. $McpHelper

$Passed = 0
$Failed = 0
$Skipped = 0

function Pass([string]$Name) { $script:Passed++; Write-Host "[PASS] $Name" }
function Fail([string]$Name, [string]$Message) { $script:Failed++; Write-Host "[FAIL] $Name :: $Message" -ForegroundColor Red }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-mcp-path-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $tempRoot "project"
$outsideRoot = Join-Path $tempRoot "outside"
New-Item -ItemType Directory -Path (Join-Path $projectRoot "src") -Force | Out-Null
New-Item -ItemType Directory -Path $outsideRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $outsideRoot "secret.txt") -Value "outside" -NoNewline

try {
    try {
        $resolved = Resolve-McpProjectPath -ProjectRoot $projectRoot -RelativePath "src"
        if ($resolved -eq (Resolve-Path -LiteralPath (Join-Path $projectRoot "src")).Path) { Pass "normal Project path resolves" }
        else { Fail "normal Project path resolves" "unexpected path: $resolved" }
    }
    catch { Fail "normal Project path resolves" $_.Exception.Message }

    $lexicalRejected = $false
    try { [void](Resolve-McpProjectPath -ProjectRoot $projectRoot -RelativePath "../outside") }
    catch { $lexicalRejected = $true }
    if ($lexicalRejected) { Pass "lexical Project escape is rejected" }
    else { Fail "lexical Project escape is rejected" "../outside was accepted" }

    $absoluteRejected = $false
    try { [void](Resolve-McpProjectPath -ProjectRoot $projectRoot -RelativePath (Join-Path $outsideRoot "secret.txt")) }
    catch { $absoluteRejected = $true }
    if ($absoluteRejected) { Pass "absolute Project path is rejected" }
    else { Fail "absolute Project path is rejected" "absolute outside path was accepted" }

    $linkPath = Join-Path $projectRoot "external-link"
    $linkCreated = $false
    try {
        if ($env:OS -eq "Windows_NT") {
            New-Item -ItemType Junction -Path $linkPath -Target $outsideRoot -ErrorAction Stop | Out-Null
        }
        else {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $outsideRoot -ErrorAction Stop | Out-Null
        }
        $linkCreated = $true
    }
    catch {
        Write-Host "[SKIP] MCP link traversal: link creation unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
        $Skipped++
    }

    if ($linkCreated) {
        $linkRejected = $false
        $linkError = ""
        try { [void](Resolve-McpProjectPath -ProjectRoot $projectRoot -RelativePath "external-link/secret.txt") }
        catch {
            $linkRejected = $true
            $linkError = $_.Exception.Message
        }
        if ($linkRejected -and $linkError -match "symlink|junction|reparse|boundary") {
            Pass "MCP path rejects link traversal outside Project"
        }
        elseif ($linkRejected) {
            Fail "MCP path rejects link traversal outside Project" "rejected for unexpected reason: $linkError"
        }
        else {
            Fail "MCP path rejects link traversal outside Project" "link traversal was accepted"
        }
    }
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "MCP path regression summary: passed=$Passed failed=$Failed skipped=$Skipped"
if ($Failed -gt 0) { exit 1 }
exit 0
