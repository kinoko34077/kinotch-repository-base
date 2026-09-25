from pathlib import Path

helper = Path('.kinotch/templates/defaults/mcp/tools/mcp-default.ps1')
text = helper.read_text(encoding='utf-8')
old = '''    $repositoryRoot = Split-Path -Parent $ProjectRoot
    $containmentPath = Join-Path $repositoryRoot ".kinotch/scripts/path-containment.ps1"
    if (-not (Get-Command Test-KntProjectPathContained -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path -LiteralPath $containmentPath -PathType Leaf)) {
            throw "KiNoTch path containment helper is missing"
        }
        . $containmentPath
    }
    $candidate = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $RelativePath))
    if (-not (Test-KntProjectPathContained -Root $ProjectRoot -Candidate $candidate -AllowRoot)) {
        throw "MCP Project path escapes the Project boundary: $RelativePath"
    }
    return $candidate
'''
new = '''    $repositoryRoot = Split-Path -Parent $ProjectRoot
    $containmentPath = Join-Path $repositoryRoot ".kinotch/scripts/path-containment.ps1"
    if (-not (Get-Command Assert-KntSafePath -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path -LiteralPath $containmentPath -PathType Leaf)) {
            throw "KiNoTch path containment helper is missing"
        }
        . $containmentPath
    }
    $candidate = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $RelativePath))
    return (Assert-KntSafePath -Root $ProjectRoot -Candidate $candidate -Description "MCP Project path" -AllowRoot)
'''
if old not in text:
    raise SystemExit('expected MCP path helper block not found')
helper.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')

Path('.kinotch/BASE_VERSION').write_text('0.5.6\n', encoding='utf-8', newline='\n')

tests = Path('.kinotch/tests/run-tests.ps1')
test_text = tests.read_text(encoding='utf-8')
old_bump = 'Set-Content -LiteralPath (Join-Path $root ".kinotch/BASE_VERSION") -Value "0.5.6" -NoNewline'
new_bump = 'Set-Content -LiteralPath (Join-Path $root ".kinotch/BASE_VERSION") -Value "0.5.7" -NoNewline'
if old_bump not in test_text:
    raise SystemExit('expected version-bump self-test text not found')
test_text = test_text.replace(old_bump, new_bump, 1)
old_assert = 'Assert-Equal "0.5.5" $baseVersion "Base version"'
new_assert = 'Assert-Equal "0.5.6" $baseVersion "Base version"'
if old_assert not in test_text:
    raise SystemExit('expected Base version assertion not found')
test_text = test_text.replace(old_assert, new_assert, 1)
tests.write_text(test_text, encoding='utf-8', newline='\n')

readme = Path('.kinotch/README_BASE.md')
readme_text = readme.read_text(encoding='utf-8')
readme_text = readme_text.replace('Base version: `0.5.5`', 'Base version: `0.5.6`', 1)
old_para = 'Base v0.5.5は、v0.5.4のnative command stderr互換性を維持しつつ、Project commandのnative process exitとPowerShell ErrorRecordの判定を分離し、PowerShell errorの偽成功とstale LASTEXITCODEの誤伝播を防ぐ保守releaseである。'
new_para = 'Base v0.5.6は、v0.5.5のProject command結果判定を維持しつつ、MCP Project path解決を共通のphysical link/reparse境界へ統一し、symlink・junction経由でProject外へ到達するpathを拒否する保守releaseである。'
if old_para not in readme_text:
    raise SystemExit('expected README release paragraph not found')
readme_text = readme_text.replace(old_para, new_para, 1)
readme.write_text(readme_text, encoding='utf-8', newline='\n')

Path('.github/workflows/issue13-apply.yml').unlink()
Path('project/tests/apply-issue13.py').unlink()
