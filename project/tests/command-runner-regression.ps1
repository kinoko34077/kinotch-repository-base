$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Router = Join-Path $RepoRoot ".kinotch/scripts/knt.ps1"
$BaseDir = Join-Path $RepoRoot ".kinotch"
$PowerShellExecutable = $null
if ($PSVersionTable.PSEdition -eq "Desktop") {
    $PowerShellExecutable = (Get-Command powershell -ErrorAction Stop | Select-Object -First 1).Source
}
else {
    $PowerShellExecutable = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ([string]::IsNullOrWhiteSpace($PowerShellExecutable)) {
        $PowerShellExecutable = (Get-Command powershell -ErrorAction Stop | Select-Object -First 1).Source
    }
}

$Passed = 0
$Failed = 0

function Assert-Exit {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Prepare,
        [Parameter(Mandatory=$true)][string]$Command,
        [Parameter(Mandatory=$true)][scriptblock]$AcceptExit
    )

    $root = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-command-result-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path (Join-Path $root "project") -Force | Out-Null
    try {
        $manifest = [pscustomobject]@{
            schema_version = 1
            project = [pscustomobject]@{ name = "command-result-regression"; type = "test" }
            profile = "minimal"
            runtime = [pscustomobject]@{ modules = @() }
            surfaces = [pscustomobject]@{
                cli = $false; gui_windows = $false; web = $false; api = $false; mcp = $false; agent = $false; library = $false
            }
            commands = [pscustomobject]@{
                setup = ""; dev = ""; test = ""; build = ""; verify = ""; smoke = ""; deploy = ""
            }
            paths = [pscustomobject]@{}
        }
        & $Prepare $manifest $root
        [IO.File]::WriteAllText(
            (Join-Path $root "project/project.json"),
            (ConvertTo-Json $manifest -Depth 20) + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false))
        )

        $output = @(& $PowerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $Router -RootOverride $root -BaseOverride $BaseDir $Command 2>&1)
        $exitCode = [int]$LASTEXITCODE
        if (& $AcceptExit $exitCode) {
            $script:Passed++
            Write-Host "[PASS] $Name"
        }
        else {
            $script:Failed++
            Write-Host "[FAIL] $Name exit=$exitCode output=$($output -join ' | ')" -ForegroundColor Red
        }
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Assert-Exit -Name "legacy non-terminating PowerShell error is non-zero" -Command "test" -Prepare {
    param($manifest, $root)
    $manifest.commands.test = [pscustomobject]@{ run = "Write-Error 'legacy-failure'"; cwd = "." }
} -AcceptExit { param($code) $code -ne 0 }

Assert-Exit -Name "structured PowerShell command error is non-zero" -Command "test" -Prepare {
    param($manifest, $root)
    $manifest.commands.test = [pscustomobject]@{
        exec = "Write-Error"
        args = @("structured-failure")
        cwd = "."
        forward_args = $false
    }
} -AcceptExit { param($code) $code -ne 0 }

Assert-Exit -Name "handled SilentlyContinue error remains successful" -Command "test" -Prepare {
    param($manifest, $root)
    $manifest.commands.test = [pscustomobject]@{
        run = "Get-Item '__kinotch_missing_expected__' -ErrorAction SilentlyContinue | Out-Null; Write-Output 'handled'"
        cwd = "."
    }
} -AcceptExit { param($code) $code -eq 0 }

Assert-Exit -Name "native stderr with successful exit remains zero" -Command "test" -Prepare {
    param($manifest, $root)
    $manifest.commands.test = [pscustomobject]@{
        exec = $PowerShellExecutable
        args = @("-NoProfile", "-Command", "[Console]::Error.WriteLine('diagnostic')")
        cwd = "."
        forward_args = $false
    }
} -AcceptExit { param($code) $code -eq 0 }

Assert-Exit -Name "stale native exit does not poison later PowerShell success" -Command "test" -Prepare {
    param($manifest, $root)
    $escapedHost = $PowerShellExecutable.Replace("'", "''")
    $manifest.commands.test = [pscustomobject]@{
        run = "& '$escapedHost' -NoProfile -Command 'exit 7'; Write-Output 'success-after-native'"
        cwd = "."
    }
} -AcceptExit { param($code) $code -eq 0 }

Assert-Exit -Name "compound legacy branch preserves native exit 7" -Command "test" -Prepare {
    param($manifest, $root)
    $escapedHost = $PowerShellExecutable.Replace("'", "''")
    $manifest.commands.test = [pscustomobject]@{
        run = "if (`$true) { & '$escapedHost' -NoProfile -Command 'exit 7' } else { Write-Output 'unused' }"
        cwd = "."
    }
} -AcceptExit { param($code) $code -eq 7 }

Assert-Exit -Name "verify fallback preserves compound native exit 9" -Command "verify" -Prepare {
    param($manifest, $root)
    $escapedHost = $PowerShellExecutable.Replace("'", "''")
    $manifest.commands.test = [pscustomobject]@{ run = "Write-Output 'test-ok'"; cwd = "." }
    $manifest.commands.build = [pscustomobject]@{
        run = "if (`$true) { & '$escapedHost' -NoProfile -Command 'exit 9' } else { Write-Output 'unused' }"
        cwd = "."
    }
} -AcceptExit { param($code) $code -eq 9 }

Assert-Exit -Name "verify cannot pass an unhandled PowerShell error" -Command "verify" -Prepare {
    param($manifest, $root)
    $manifest.commands.verify = [pscustomobject]@{ run = "Write-Error 'verify-failure'"; cwd = "." }
} -AcceptExit { param($code) $code -ne 0 }

Write-Host "Command-runner regression summary: passed=$Passed failed=$Failed"
if ($Failed -gt 0) { exit 1 }
exit 0
