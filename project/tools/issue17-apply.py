from pathlib import Path

path = Path('.kinotch/scripts/knt.ps1')
text = path.read_text(encoding='utf-8')

old_reset = '''            $ErrorActionPreference = "Continue"
            $LASTEXITCODE = $null
            if ($spec.mode -eq "structured") {
'''
new_reset = '''            $ErrorActionPreference = "Continue"
            # Reset the process-wide automatic variable without creating a
            # function-local LASTEXITCODE that would shadow native updates.
            $global:LASTEXITCODE = $null
            if ($spec.mode -eq "structured") {
'''
if old_reset not in text:
    raise SystemExit('project command LASTEXITCODE reset block not found')
text = text.replace(old_reset, new_reset, 1)

old = '''                $errorCountBefore = $Error.Count
                $commandOutput = @(Invoke-Expression $spec.run 2>&1)
                $powerShellSucceeded = $?
                $nativeExitCode = $LASTEXITCODE
                $newErrorCount = [Math]::Max(0, $Error.Count - $errorCountBefore)
                $newErrors = if ($newErrorCount -gt 0) { @($Error | Select-Object -First $newErrorCount) } else { @() }
                $nonNativeErrors = @($newErrors | Where-Object { [string]$_.FullyQualifiedErrorId -notlike 'NativeCommandError*' })
'''
new = '''                # Capture the legacy expression's terminal status inside the evaluated
                # scope before caller-side output capture can overwrite `$?`.
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

                # `$Error` also records intentionally handled errors such as
                # -ErrorAction SilentlyContinue. Only ErrorRecords that actually reached
                # the merged error stream are unhandled command errors here.
                $emittedErrors = @($commandOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
                $nonNativeErrors = @($emittedErrors | Where-Object { [string]$_.FullyQualifiedErrorId -notlike 'NativeCommandError*' })
'''
if old not in text:
    raise SystemExit('legacy result block not found')
text = text.replace(old, new, 1)
text = text.replace(
    'elseif ($newErrors.Count -gt 0 -and $nonNativeErrors.Count -eq 0) {',
    'elseif ($emittedErrors.Count -gt 0 -and $nonNativeErrors.Count -eq 0) {',
    1,
)
path.write_text(text, encoding='utf-8', newline='\n')

Path('.kinotch/BASE_VERSION').write_text('0.5.7\n', encoding='utf-8', newline='\n')

readme = Path('.kinotch/README_BASE.md')
r = readme.read_text(encoding='utf-8')
r = r.replace('Base version: `0.5.6`', 'Base version: `0.5.7`', 1)
oldp = 'Base v0.5.6は、v0.5.5のProject command結果判定を維持しつつ、MCP Project path解決を共通のphysical link/reparse境界へ統一し、symlink・junction経由でProject外へ到達するpathを拒否する保守releaseである。'
newp = 'Base v0.5.7は、v0.5.6の安全境界を維持しつつ、Project commandのLASTEXITCODE resetをprocess-wide automatic variableへ統一し、legacy commandの終端PowerShell状態・native exit code・実際に出力されたErrorRecordを分離して判定する保守releaseである。'
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
