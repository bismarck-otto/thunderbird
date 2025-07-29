# ChatGPT for bismarck-otto 2025-07-28 to Get-TB-Accounts.ps1

# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Locate Thunderbird profile folder ending with .default-release
$tbProfilesPath = Join-Path $env:APPDATA "Thunderbird\Profiles"
$profileFolder = Get-ChildItem $tbProfilesPath -Directory | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1

if (-not $profileFolder) {
    Write-Host "❌ No Thunderbird profile ending in '.default-release' was found." -ForegroundColor Red
    exit 1
}

$prefsPath = Join-Path $profileFolder.FullName "prefs.js"

if (-not (Test-Path $prefsPath)) {
    Write-Host "❌ prefs.js not found in: $($profileFolder.FullName)" -ForegroundColor Red
    exit 1
}

# Load prefs.js lines
$prefsLines = Get-Content $prefsPath

# Extract account, server, and identity IDs
$accounts = @()
$servers = @()
$identities = @()
$smtpservers = @()

foreach ($line in $prefsLines) {
    if ($line -match 'mail\.account\.account(\d+)') {
        $accounts += "account$($matches[1])"
    }
    if ($line -match 'mail\.server\.server(\d+)') {
        $servers += "server$($matches[1])"
    }
    if ($line -match 'mail\.identity\.(?:identity|id)(\d+)') {
        $identities += "id$($matches[1])"
    }
    if ($line -match 'mail\.smtpserver\.smtp(\d+)') {
        $smtpservers += "smtp$($matches[1])"
    }
}

# Remove duplicates and sort
$accounts = $accounts | Sort-Object -Unique
$servers = $servers | Sort-Object -Unique
$identities = $identities | Sort-Object -Unique
$smtpservers = $smtpservers | Sort-Object -Unique

# Optional: Show existing mail.accountmanager.accounts line
$accountManagerLine = $prefsLines | Where-Object { $_ -match 'mail\.accountmanager\.accounts' }

# Extract existing accounts from the matched line
$existingAccounts = @()
#if ($accountManagerLine -match '"accountmanager\.accounts",\s*"([^"]+)"') {
if ($accountManagerLine -match 'accountmanager\.accounts",\s*"([^"]+)"') {
    $existingAccounts = $matches[1].Split(',') | ForEach-Object { $_.Trim() }
}

# Output summary
Write-Host "`n--- Thunderbird Account Configuration Summary ---" -ForegroundColor Cyan
Write-Host "Profile   : $($profileFolder.Name)"
Write-Host "Accounts  : $($accounts -join ', ')"
Write-Host "Servers   : $($servers -join ', ')"
Write-Host "SMTP      : $($smtpservers -join ', ')"
Write-Host "Identities: $($identities -join ', ')"
Write-Host "`nManager   : $($existingAccounts -join ",")"
Write-Host "`n"
