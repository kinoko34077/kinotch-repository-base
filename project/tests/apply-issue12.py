from pathlib import Path

path = Path('.kinotch/scripts/knt.ps1')
text = path.read_text(encoding='utf-8')
start = text.index('function Invoke-ProjectCommand($Manifest, [string]$Name) {')
end = text.index('\nfunction Invoke-Verify($Manifest) {', start)
replacement = r'''function Invoke-ProjectCommand($Manifest, [string]$Name) {
    $spec = Resolve-Command $Manifest $Name
    if (-not $spec) {
        Write-Knt "Command '$Name' is not configured for this project."
        return 0
    }
    try {
        $cwd = Resolve-KntCommandWorkingDirectory -RelativePath ([string]$spec.cwd) -CommandName $Name
    }
    catch {
        Write-Host "[command] $($_.Exception.Message)" -ForegroundColor Red
        return 1
    }
    if (-not (Test-Path -LiteralPath $cwd -PathType Container)) {
        Write-Host "[doctor] MISSING command cwd: $($spec.cwd)" -ForegroundColor Red
        return 1
    }
    Push-Location $cwd
    try {
        $commandOutput = @()
        $commandExitCode = 0
        $commandErrorActionPreference = $ErrorActionPreference
        try {
            # Windows PowerShell 5.1 can surface native stderr merged by 2>&1
            # as NativeCommandError even when the native process exits 0.
            # Keep native process exit semantics separate from PowerShell
            # ErrorRecord semantics so stderr diagnostics do not become
            # failures and PowerShell errors do not become false successes.
            $ErrorActionPreference = "Continue"
            $LASTEXITCODE = $null
            if ($spec.mode -eq "structured") {
                $forwardedArgs = @($RemainingArgs | Where-Object { $null -ne $_ })
                if ($forwardedArgs.Count -gt 0 -and -not $spec.forward_args) {
                    throw "Structured command '$Name' must set forward_args=true to accept forwarded arguments"
                }
                $invokeArgs = @($spec.args)
                if ($spec.forward_args) { $invokeArgs += $forwardedArgs }
                Write-Knt "$Name -> $($spec.exec)"

                $resolvedCommand = Get-Command -Name $spec.exec -ErrorAction Stop | Select-Object -First 1
                while ($resolvedCommand.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
                    $resolvedCommand = $resolvedCommand.ResolvedCommand
                }
                $isNativeCommand = $resolvedCommand.CommandType -eq [System.Management.Automation.CommandTypes]::Application
                $errorCountBefore = $Error.Count
                $commandOutput = @(& $spec.exec @invokeArgs 2>&1)
                $powerShellSucceeded = $?
                $nativeExitCode = $LASTEXITCODE
                $newErrorCount = [Math]::Max(0, $Error.Count - $errorCountBefore)

                if ($isNativeCommand) {
                    $commandExitCode = if ($null -ne $nativeExitCode) { [int]$nativeExitCode } elseif ($powerShellSucceeded) { 0 } else { 1 }
                }
                else {
                    $commandExitCode = if ($powerShellSucceeded -and $newErrorCount -eq 0) { 0 } else { 1 }
                }
            }
            else {
                $forwardedArgs = @($RemainingArgs | Where-Object { $null -ne $_ })
                if ($forwardedArgs.Count -gt 0) {
                    throw "Legacy command '$Name' cannot safely forward arguments; use structured exec/args with forward_args=true"
                }
                Write-Knt "$Name -> $($spec.run)"
                $errorCountBefore = $Error.Count
                $commandOutput = @(Invoke-Expression $spec.run 2>&1)
                $powerShellSucceeded = $?
                $nativeExitCode = $LASTEXITCODE
                $newErrorCount = [Math]::Max(0, $Error.Count - $errorCountBefore)
                $newErrors = if ($newErrorCount -gt 0) { @($Error | Select-Object -First $newErrorCount) } else { @() }
                $nonNativeErrors = @($newErrors | Where-Object { [string]$_.FullyQualifiedErrorId -notlike 'NativeCommandError*' })

                if ($nonNativeErrors.Count -gt 0) {
                    $commandExitCode = 1
                }
                elseif ($powerShellSucceeded) {
                    # A successful final PowerShell operation must not inherit
                    # a stale LASTEXITCODE from an earlier native process.
                    $commandExitCode = 0
                }
                elseif ($null -ne $nativeExitCode -and [int]$nativeExitCode -ne 0) {
                    $commandExitCode = [int]$nativeExitCode
                }
                elseif ($newErrors.Count -gt 0 -and $nonNativeErrors.Count -eq 0) {
                    # Windows PowerShell 5.1 native stderr with exit 0.
                    $commandExitCode = 0
                }
                else {
                    $commandExitCode = 1
                }
            }
        }
        finally {
            $ErrorActionPreference = $commandErrorActionPreference
        }
        foreach ($outputLine in $commandOutput) { Write-Host $outputLine }
        return $commandExitCode
    }
    finally {
        Pop-Location
    }
}
'''
path.write_text(text[:start] + replacement + text[end:], encoding='utf-8', newline='\n')

version = Path('.kinotch/BASE_VERSION')
version.write_text('0.5.5\n', encoding='utf-8', newline='\n')

tests = Path('.kinotch/tests/run-tests.ps1')
test_text = tests.read_text(encoding='utf-8')
old_bump = 'Set-Content -LiteralPath (Join-Path $root ".kinotch/BASE_VERSION") -Value "0.5.5" -NoNewline'
new_bump = 'Set-Content -LiteralPath (Join-Path $root ".kinotch/BASE_VERSION") -Value "0.5.6" -NoNewline'
if old_bump not in test_text:
    raise SystemExit('expected version-bump self-test text not found')
test_text = test_text.replace(old_bump, new_bump, 1)
old_assert = 'Assert-Equal "0.5.4" $baseVersion "Base version"'
new_assert = 'Assert-Equal "0.5.5" $baseVersion "Base version"'
if old_assert not in test_text:
    raise SystemExit('expected Base version assertion not found')
test_text = test_text.replace(old_assert, new_assert, 1)
tests.write_text(test_text, encoding='utf-8', newline='\n')

readme = Path('.kinotch/README_BASE.md')
readme_text = readme.read_text(encoding='utf-8')
readme_text = readme_text.replace('Base version: `0.5.4`', 'Base version: `0.5.5`', 1)
old_para = 'Base v0.5.4は、v0.5.3の安全境界に加え、Windows PowerShell 5.1を含むnative command stderrの安全な捕捉を修正した保守releaseである。'
new_para = 'Base v0.5.5は、v0.5.4のnative command stderr互換性を維持しつつ、Project commandのnative process exitとPowerShell ErrorRecordの判定を分離し、PowerShell errorの偽成功とstale LASTEXITCODEの誤伝播を防ぐ保守releaseである。'
if old_para not in readme_text:
    raise SystemExit('expected README release paragraph not found')
readme_text = readme_text.replace(old_para, new_para, 1)
readme.write_text(readme_text, encoding='utf-8', newline='\n')

Path('.github/workflows/issue12-apply.yml').unlink()
Path('project/tests/apply-issue12.py').unlink()
