# B0 probe: external schema reference only; never a production admission path.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BaseDir = Join-Path $RepoRoot ".kinotch"
$Router = Join-Path $BaseDir "scripts/knt.ps1"
$HostExe = if ($PSVersionTable.PSEdition -eq "Desktop") {
    (Get-Command powershell -ErrorAction Stop).Source
} else {
    (Get-Command pwsh -ErrorAction Stop).Source
}

function Get-TreeFingerprint([string]$Root) {
    $entries = @(Get-ChildItem -LiteralPath $Root -Force -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
        if ($_.PSIsContainer) { "D $relative" }
        else { "F $relative $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    } | Sort-Object)
    return ($entries -join [Environment]::NewLine)
}

function Invoke-Probe([string]$Consumer, [string]$ExternalBase, [string[]]$Arguments, [int]$Expected, [string]$Pattern) {
    $output = @(& $HostExe -NoProfile -ExecutionPolicy Bypass -File $Router -RootOverride $Consumer -BaseOverride $ExternalBase @Arguments 2>&1)
    $code = $LASTEXITCODE
    $message = $output -join [Environment]::NewLine
    if ($code -ne $Expected -or $message -notmatch $Pattern) {
        throw "Expected exit $Expected and diagnostic '$Pattern', got $code : $message"
    }
}

$Temp = Join-Path ([IO.Path]::GetTempPath()) ("kinotch-reference-probe-" + [guid]::NewGuid().ToString("N"))
$Consumer = Join-Path $Temp "consumer"
$OldBase = Join-Path $Temp "synthetic-old-base"
New-Item -ItemType Directory -Path $Consumer -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $BaseDir "tests/fixtures/valid-minimal") -Destination (Join-Path $Consumer "project") -Recurse
    Copy-Item -LiteralPath $BaseDir -Destination $OldBase -Recurse
    $schemaPath = Join-Path $OldBase "schemas/project.schema.json"
    $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $name = (Get-Content -LiteralPath (Join-Path $Consumer "project/project.json") -Raw -Encoding UTF8 | ConvertFrom-Json).project.name
    $minimum = $name.Length + 1
    $schema.properties.project.properties.name.minLength = $minimum
    [IO.File]::WriteAllText($schemaPath, ($schema | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $Consumer "user-owned.txt"), "preserve me")
    $before = Get-TreeFingerprint $Consumer

    # A: synthetic overly strict schema; B: existing canonical schema.
    # Only the external Base path changes; the consumer stays byte-identical.
    Invoke-Probe -Consumer $Consumer -ExternalBase $OldBase -Arguments @("doctor") -Expected 1 -Pattern "project\.name must have at least $minimum characters"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Old schema probe modified consumer" }
    Invoke-Probe -Consumer $Consumer -ExternalBase $BaseDir -Arguments @("doctor") -Expected 0 -Pattern "Base version:"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Updated schema probe modified consumer" }

    Invoke-Probe -Consumer $Consumer -ExternalBase $BaseDir -Arguments @("migrate", "--apply") -Expected 2 -Pattern "BaseOverride is read-only"
    if ((Get-TreeFingerprint $Consumer) -cne $before) { throw "Denied external migration modified consumer" }
    if (Test-Path -LiteralPath (Join-Path $Consumer ".kinotch")) { throw "Probe materialized local Base" }
    Write-Host "[PASS] External schema change affects doctor; consumer tree unchanged; external apply denied"
}
finally {
    Remove-Item -LiteralPath $Temp -Recurse -Force
}
