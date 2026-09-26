from pathlib import Path

path = Path('.kinotch/scripts/knt.ps1')
text = path.read_text(encoding='utf-8')
old = '''                $errorCountBefore = $Error.Count
                $commandOutput = @(Invoke-Expression $spec.run 2>&1)
                $powerShellSucceeded = $?
                $nativeExitCode = $LASTEXITCODE
                $newErrorCount = [Math]::Max(0, $Error.Count - $errorCountBefore)
                $newErrors = if ($newErrorCount -gt 0) { @($Error | Select-Object -First $newErrorCount) } else { @() }
                $nonNativeErrors = @($newErrors | Where-Object { [string]$_.FullyQualifiedErrorId -notlike 'NativeCommandError*' })
'''
new = '''                # Capture the legacy expression's terminal status inside the evaluated
                # scope. A shared object preserves the captured values after Invoke-Expression
                # returns, without letting the caller-side assignment overwrite `$?`.
                $legacyStatus = [pscustomobject]@{
                    PowerShellSucceeded = $null
                    NativeExitCode = $null
                }
                $legacyStatusScript = [string]$spec.run + [Environment]::NewLine +
                    '$legacyStatus.PowerShellSucceeded = $?' + [Environment]::NewLine +
                    '$legacyStatus.NativeExitCode = $LASTEXITCODE'
                $commandOutput = @(Invoke-Expression $legacyStatusScript 2>&1)
                $powerShellSucceeded = ($legacyStatus.PowerShellSucceeded -eq $true)
                $nativeExitCode = $legacyStatus.NativeExitCode

                # Only errors actually emitted to the merged error stream count as
                # unhandled PowerShell errors. `$Error` also records intentionally handled
                # `-ErrorAction SilentlyContinue` errors and must not be used as the result gate.
                $emittedErrors = @($commandOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
                $nonNativeErrors = @($emittedErrors | Where-Object { [string]$_.FullyQualifiedErrorId -notlike 'NativeCommandError*' })
'''
if old not in text:
    raise SystemExit('legacy result block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')

Path('.kinotch/BASE_VERSION').write_text('0.5.7\n', encoding='utf-8', newline='\n')

readme = Path('.kinotch/README_BASE.md')
r = readme.read_text(encoding='utf-8')
r = r.replace('Base version: `0.5.6`', 'Base version: `0.5.7`', 1)
oldp = 'Base v0.5.6は、v0.5.5のProject command結果判定を維持しつつ、MCP Project path解決を共通のphysical link/reparse境界へ統一し、symlink・junction経由でProject外へ到達するpathを拒否する保守releaseである。'
newp = 'Base v0.5.7は、v0.5.6の安全境界を維持しつつ、legacy Project commandの終端PowerShell状態とnative exit codeを実行式内で採取し、compound expression内のnative failureの保持と、処理済みPowerShell errorの分離を修正した保守releaseである。'
if oldp not in r:
    raise SystemExit('README v0.5.6 release paragraph not found')
readme.write_text(r.replace(oldp, newp, 1), encoding='utf-8', newline='\n')

tests = Path('.kinotch/tests/run-tests.ps1')
t = tests.read_text(encoding='utf-8')
old_bump = 'Set-Content -LiteralPath (Join-Path $root ".kinotch/BASE_VERSION") -Value "0.5.7" -NoNewline'
old_assert = 'Assert-Equal "0.5.6" $baseVersion "Base version"'
if old_bump not in t or old_assert not in t:
    raise SystemExit('Base version self-test markers not found')
t = t.replace(old_bump, 'Set-Content -LiteralPath (Join-Path $root ".kinotch/BASE_VERSION") -Value "0.5.8" -NoNewline', 1)
t = t.replace(old_assert, 'Assert-Equal "0.5.7" $baseVersion "Base version"', 1)
tests.write_text(t, encoding='utf-8', newline='\n')

for temporary in [
    Path('.github/workflows/issue17-apply.yml'),
    Path('.github/workflows/issue17-probe.yml'),
    Path('project/tools/issue17-apply.py'),
]:
    if temporary.exists():
        temporary.unlink()
