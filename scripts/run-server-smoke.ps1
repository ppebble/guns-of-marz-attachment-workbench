param(
    [switch]$Legacy,
    [string]$DedicatedRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Project Zomboid Dedicated Server'
)
$ErrorActionPreference = 'Stop'
$cache = & (Join-Path $PSScriptRoot 'prepare-server-smoke.ps1') -Legacy:$Legacy
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $DedicatedRoot 'jre64/bin/java.exe'
$start.WorkingDirectory = $DedicatedRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardInput = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.Arguments = '-Djava.awt.headless=true -Dzomboid.steam=0 -Xms512m -Xmx3g -Djava.library.path=natives/ -cp "java/;java/projectzomboid.jar" zombie.network.GameServer -nosteam -cachedir="' + $cache + '" -servername gmaw-smoke -adminusername gmaw-probe -adminpassword isolated-local-probe-only'
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $start
$null = $process.Start()
$output = $process.StandardOutput.ReadToEndAsync()
$errors = $process.StandardError.ReadToEndAsync()
$passed = $false
try {
    $deadline = (Get-Date).AddMinutes(3)
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $log = Join-Path $cache 'server-console.txt'
        if (Test-Path $log) {
            # Startup rotates/reopens the log briefly with exclusive sharing.
            try { $text = Get-Content -LiteralPath $log -Raw -ErrorAction Stop } catch { continue }
            if ($text.Contains('[GMAW-SERVER-SMOKE] PASS')) { $passed=$true; break }
            if ($text.Contains('[GMAW-SERVER-SMOKE] FAIL')) { break }
        }
    }
    if (-not $process.HasExited) {
        $process.StandardInput.WriteLine('quit')
        $process.StandardInput.Flush()
        if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.WaitForExit() }
    }
    [IO.File]::WriteAllText((Join-Path $cache 'launcher-stdout.txt'), $output.Result)
    [IO.File]::WriteAllText((Join-Path $cache 'launcher-stderr.txt'), $errors.Result)
    Write-Output "Evidence: $cache"
    if (-not $passed) { throw 'Dedicated runtime smoke did not pass; see isolated server-console.txt' }
    Write-Output 'PASS real dedicated-server startup and catalog probe; no connected-player gameplay claimed.'
} finally {
    # Only this helper's own isolated process is eligible for cleanup.
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose()
}
