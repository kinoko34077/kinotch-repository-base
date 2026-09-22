$ErrorActionPreference = "Stop"

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $TestDir)
$FixtureRoot = Join-Path $RepoRoot ".kinotch/tests/fixtures"
$Passed = 0
$Failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) {
        throw "$Message expected=[$Expected] actual=[$Actual]"
    }
}

function Get-FixtureProtectedPaths([string]$Root) {
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
    return @($fixed + $common | Sort-Object)
}

function Set-FixtureBaseIndex([string]$Root) {
    $entries = @(Get-FixtureProtectedPaths $Root | ForEach-Object {
        [pscustomobject]@{
            path = $_
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root $_)).Hash.ToLowerInvariant()
        }
    })
    $index = [pscustomobject]@{
        schema_version = 1
        base_version = (Get-Content -Raw -LiteralPath (Join-Path $Root ".kinotch/BASE_VERSION")).Trim()
        files = $entries
    }
    $json = ConvertTo-Json $index -Depth 10
    [IO.File]::WriteAllText((Join-Path $Root ".kinotch/base-files.json"), $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-FixtureAsBase([string]$Root) {
    $manifestPath = Join-Path $Root "project/project.json"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $manifest.project.type = "repository-base"
    [IO.File]::WriteAllText($manifestPath, (ConvertTo-Json $manifest -Depth 20) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-KntFixture {
    param(
        [string]$Name,
        [string]$Command,
        [int]$ExpectedExit = 0,
        [scriptblock]$AssertOutput,
        [scriptblock]$Prepare
    )
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-base-test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        Get-ChildItem -Force $RepoRoot | Where-Object {
            $_.Name -notin @(".git", ".superpowers")
        } | Copy-Item -Destination $tempRoot -Recurse -Force
        Remove-Item -LiteralPath (Join-Path $tempRoot "project") -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $FixtureRoot $Name) -Destination (Join-Path $tempRoot "project") -Recurse -Force
        if ($Prepare) { & $Prepare $tempRoot }
        $router = Join-Path $tempRoot ".kinotch/scripts/knt.ps1"
        $outputLines = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $router -RootOverride $tempRoot $Command 2>&1)
        $exitCode = $LASTEXITCODE
        $output = $outputLines -join [Environment]::NewLine
        Assert-Equal $ExpectedExit $exitCode "$Name $Command exit code"
        if ($AssertOutput) { & $AssertOutput $tempRoot $output }
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-TestCase([string]$Name, [scriptblock]$Body) {
    try {
        & $Body
        $script:Passed++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host "[FAIL] $Name :: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Invoke-TestCase "valid minimal project passes doctor" {
    Invoke-KntFixture -Name "valid-minimal" -Command "doctor" -ExpectedExit 0
}
Invoke-TestCase "invalid manifest is rejected by schema" {
    Invoke-KntFixture -Name "invalid-manifest" -Command "doctor" -ExpectedExit 1 -AssertOutput {
        param($root, $output)
        Assert-True ($output -match "Schema validation failed") "schema error was not reported"
    }
}
Invoke-TestCase "invalid action registry is rejected by schema" {
    Invoke-KntFixture -Name "invalid-actions" -Command "doctor" -ExpectedExit 1 -AssertOutput {
        param($root, $output)
        Assert-True ($output -match "Schema validation failed") "action schema heading was not reported"
        Assert-True ($output -match "actions") "action schema path was not reported"
    }
}
Invoke-TestCase "invalid surface registry is rejected by schema" {
    Invoke-KntFixture -Name "invalid-surfaces" -Command "doctor" -ExpectedExit 1 -AssertOutput {
        param($root, $output)
        Assert-True ($output -match "Schema validation failed") "surface schema heading was not reported"
        Assert-True ($output -match "surfaces") "surface schema path was not reported"
    }
}
Invoke-TestCase "invalid JSON returns parse exit code" {
    Invoke-KntFixture -Name "invalid-json" -Command "doctor" -ExpectedExit 2 -AssertOutput {
        param($root, $output)
        Assert-True ($output -match "JSON parse error") "JSON parse error was not reported"
    }
}
Invoke-TestCase "missing required path is rejected" {
    Invoke-KntFixture -Name "missing-files" -Command "doctor" -ExpectedExit 1 -AssertOutput {
        param($root, $output)
        Assert-True ($output -match "MISSING path.*docs|docs.*MISSING path") "missing path was not reported"
    }
}
Invoke-TestCase "unknown command returns two" {
    Invoke-KntFixture -Name "valid-minimal" -Command "unknown-command" -ExpectedExit 2 -AssertOutput {
        param($root, $output)
        Assert-True ($output -match "Unknown command") "unknown command was not reported"
    }
}
Invoke-TestCase "project command exit code propagates" {
    Invoke-KntFixture -Name "command-failure" -Command "test" -ExpectedExit 7
}
Invoke-TestCase "verify fallback runs test then build" {
    Invoke-KntFixture -Name "verify-fallback" -Command "verify" -ExpectedExit 0 -AssertOutput {
        param($root, $output)
        $marker = Join-Path $root "project/command-order.txt"
        Assert-True (Test-Path $marker) "verify marker was not created"
        Assert-Equal ("test" + [Environment]::NewLine + "build") ((Get-Content -Raw $marker).Trim()) "verify order"
    }
}
Invoke-TestCase "command runs in declared cwd" {
    Invoke-KntFixture -Name "command-cwd" -Command "test" -ExpectedExit 0 -AssertOutput {
        param($root, $output)
        $marker = Join-Path $root "project/command-cwd.marker"
        Assert-True (Test-Path $marker) "cwd marker was not created"
        $actual = (Get-Content -Raw $marker).Trim()
        $expected = (Resolve-Path (Join-Path $root "project")).Path
        Assert-Equal $expected $actual "command cwd"
    }
}

Invoke-TestCase "changed Base file fails base-check" {
    Invoke-KntFixture -Name "valid-minimal" -Command "base-check" -ExpectedExit 1 -Prepare {
        param($root)
        Set-FixtureBaseIndex $root
        Add-Content -LiteralPath (Join-Path $root ".kinotch/README_BASE.md") -Value "changed for test"
    }
}

Invoke-TestCase "base-refresh indexes new common file" {
    Invoke-KntFixture -Name "valid-minimal" -Command "base-refresh" -ExpectedExit 0 -Prepare {
        param($root)
        Set-FixtureAsBase $root
        Set-FixtureBaseIndex $root
        Set-Content -LiteralPath (Join-Path $root ".kinotch/new-common.txt") -Value "new common file" -NoNewline
        $router = Join-Path $root ".kinotch/scripts/knt.ps1"
        $before = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $router -RootOverride $root base-check 2>&1)
        if ($LASTEXITCODE -eq 0) { throw "unindexed Base file was not rejected: $($before -join ' ')" }
    } -AssertOutput {
        param($root, $output)
        $router = Join-Path $root ".kinotch/scripts/knt.ps1"
        @(& powershell -NoProfile -ExecutionPolicy Bypass -File $router -RootOverride $root base-check 2>&1) | Out-Null
        Assert-Equal 0 $LASTEXITCODE "base-check after refresh"
    }
}

Write-Host "Self-test summary: passed=$Passed failed=$Failed"
if ($Failed -gt 0) { exit 1 }
exit 0
