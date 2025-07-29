# ChatGPT for bismarck-otto 2025-07-29 to Remove-Unused-Servers.ps1

# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Locate Thunderbird profile folder
$tbProfilesPath = Join-Path $env:APPDATA "Thunderbird\Profiles"
$profileFolder = Get-ChildItem $tbProfilesPath -Directory | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1

if (-not $profileFolder) {
    Write-Host "❌ No profile ending in '.default-release' found." -ForegroundColor Red
    exit 1
}

$prefsPath = Join-Path $profileFolder.FullName "prefs.js"

if (-not (Test-Path $prefsPath)) {
    Write-Host "❌ prefs.js not found in: $($profileFolder.FullName)" -ForegroundColor Red
    exit 1
}

# Read prefs.js
$prefsLines = Get-Content $prefsPath

# Find highest used account, identity, and server numbers
$accountMax = ($prefsLines -match 'mail\.account\.account(\d+)') | ForEach-Object { [int]($_ -replace '^.*account(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$identityMax = ($prefsLines -match 'mail\.identity\.(?:identity|id)(\d+)') | ForEach-Object { [int]($_ -replace '^.*(?:identity|id)(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$serverMax = ($prefsLines -match 'mail\.server\.server(\d+)') | ForEach-Object { [int]($_ -replace '^.*server(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$smtpMax = ($prefsLines -match 'mail\.smtpserver\.smtp(\d+)') | ForEach-Object { [int]($_ -replace '^.*smtp(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum


if (-not $serverMax) {
    Write-Host "⚠️ No existing server entries found — exiting." -ForegroundColor Red
    exit 1
}

# Show max values
Write-Host "`n📊 Current maximums found:" -ForegroundColor Cyan
Write-Host "  Account max : $accountMax"
Write-Host "  Identity max: $identityMax"
Write-Host "  Server max  : $serverMax"
Write-Host "  SMPT max    : $smtpMax"

# Compute the greater of the two
$maxUsedIndex = [Math]::Max($accountMax, $identityMax)

Write-Host "`n➡️  Max used index (account/identity): $maxUsedIndex"

# 🔽 New: Prompt user for first server index to delete
$startCleanupInput = Read-Host "`n👉 Enter the first server index to delete (must be greater than $maxUsedIndex)"
if (-not ($startCleanupInput -as [int]) -or [int]$startCleanupInput -le $maxUsedIndex) {
    Write-Host "❌ Invalid input. Must be a number greater than $maxUsedIndex." -ForegroundColor Red
    exit 1
}

# 🔽 New: Prompt user for first smtpserver index to delete
$startSmtpCleanupInput = Read-Host "`n👉 Enter the first smtpserver index to delete (must be greater than $smtpMax)"
if (-not ($startSmtpCleanupInput -as [int]) -or [int]$startSmtpCleanupInput -le $smtpMax) {
    Write-Host "❌ Invalid input. Must be a number greater than $smtpMax." -ForegroundColor Red
    exit 1
}

# Clean-up of serverX
$startCleanup = [int]$startCleanupInput
$endCleanup = 99
$targetServers = $startCleanup..$endCleanup | ForEach-Object { "server$_" }

Write-Host "`n🔍 Searching for lines with server$startCleanup to server$endCleanup..."

# Find candidate lines
$candidates = $prefsLines | Where-Object {
    foreach ($target in $targetServers) {
        if ($_ -match "\b$target\b") { return $true }
    }
    return $false
}

# Display matches
if ($candidates.Count -eq 0) {
    Write-Host "✅ No matching server lines found in suggested cleanup range."
} else {
    Write-Host "`n⚠️  The following server lines are candidates for removal:" -ForegroundColor Yellow
    $candidates | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
}

# Clean-up of smtpserver.smtpX
$startCleanup = [int]$startSmtpCleanupInput
$endCleanup = 99
$targetServers = $startCleanup..$endCleanup | ForEach-Object { "smtpserver.smtp$_" }

Write-Host "`n🔍 Searching for lines with smtpserver.smtp$startCleanup to smtpserver.smtp$endCleanup..."

# Find candidate lines
$candidateSmtp = $prefsLines | Where-Object {
    foreach ($target in $targetServers) {
        if ($_ -match "\b$target\b") { return $true }
    }
    return $false
}

# Display matches
if ($candidateSmtp.Count -eq 0) {
    Write-Host "✅ No matching smtpserver lines found in suggested cleanup range."
} else {
    Write-Host "`n⚠️  The following smtpserver lines are candidates for removal:" -ForegroundColor Yellow
    $candidateSmtp | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
}

# Prompt
if (($candidates.Count -eq 0) -and ($candidateSmtp.Count -eq 0)) {
    Write-Host "`n✅ No matching lines at all found in suggested cleanup range."
    Write-Host "❌ Aborted. No changes to make."
    exit 0
} else {
    $confirm = Read-Host "`nDo you want to remove these lines from prefs.js? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "❌ Aborted. No changes made."
        exit 0
    }
}

# Backup prefs.js
$prefsBackup = "$prefsPath.bak"
Copy-Item $prefsPath $prefsBackup -Force
Write-Host "📦 Backup created: $prefsBackup"

if ( -not ($candidates.Count -eq 0)) {

    # Remove matched lines and write updated prefs.js
    $prefsLines | Where-Object { $_ -notin $candidates } | Set-Content $prefsPath -Encoding UTF8

    # Write log file
    $scriptName = $MyInvocation.MyCommand.Name
    $logFileName = [System.IO.Path]::ChangeExtension($scriptName, ".log")
    $logPath = Join-Path $PSScriptRoot $logFileName
    Set-Content -Path $logPath -Value $candidates -Encoding UTF8

    Write-Host "`n✅ Removed $($candidates.Count) server lines."
}

if ( -not ($candidateSmtp.Count -eq 0)) {

    # Remove matched lines and write updated prefs.js
    $prefsLines | Where-Object { $_ -notin $candidateSmtp } | Set-Content $prefsPath -Encoding UTF8

    # Write (append) to log file
    $scriptName = $MyInvocation.MyCommand.Name
    $logFileName = [System.IO.Path]::ChangeExtension($scriptName, ".log")
    $logPath = Join-Path $PSScriptRoot $logFileName

    # Append or write the candidates to the existing log
    if ($candidates.Count -eq 0) {
        Set-Content -Path $logPath -Value $candidateSmtp -Encoding UTF8
    } else {
        Add-Content -Path $logPath -Value $candidateSmtp -Encoding UTF8
    }

    Write-Host "`n✅ Removed $($candidateSmtp.Count) smtpserver lines."
 }

Write-Host "📝 Log written to: $logPath"
