# ChatGPT for bismarck-otto 2025-08-06 to Generate-UserJS-Draft.ps1

# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Default values
$defaultFullName   = "New User"
$defaultUsername   = "User"
$defaultEmail      = "new.user@example.com"
$defaultServer     = "mail.example.com"
$defaultSmtpServer = "smtp.example.com"
$defaultIMAPport   =  993  # SSL/TLS
$defaultPOPport    =  995  # SSL/TLS
$defaultSMTPport   =  465  # SSL/TLS

$today = Get-Date -Format "yyyy-MM-dd"
Write-Host "`n--- Generate Thunderbird Draft Configuration File ---" -ForegroundColor Cyan

# Locate profile folder
$tbProfilesPath = Join-Path $env:APPDATA "Thunderbird\Profiles"
$profileFolder = Get-ChildItem $tbProfilesPath -Directory | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1

if (-not $profileFolder) {
    Write-Host "❌ No Thunderbird profile ending in '.default-release' found." -ForegroundColor Red
    exit 1
}

$prefsPath = Join-Path $profileFolder.FullName "prefs.js"
if (-not (Test-Path $prefsPath)) {
    Write-Host "❌ prefs.js not found in: $($profileFolder.FullName)" -ForegroundColor Red
    exit 1
}

# Prompt user to choose POP or IMAP
do {
    $mailType = Read-Host "`n📬 Choose mail type to generate (POP or IMAP)"
    $mailType = $mailType.ToUpper()
} while ($mailType -ne "POP" -and $mailType -ne "IMAP")

# Prompt with defaults

$newFullName = Read-Host "`nEnter your full name ($defaultFullName)"
if ([string]::IsNullOrWhiteSpace($newFullName)) { $newFullName = $defaultFullName }

$newUsername = Read-Host "Enter your username ($defaultUsername)"
if ([string]::IsNullOrWhiteSpace($newUsername)) { $newUsername = $defaultUsername }

$newEmail = Read-Host "Enter your email address ($defaultEmail)"
if ([string]::IsNullOrWhiteSpace($newEmail)) { $newEmail = $defaultEmail }

$newServer = Read-Host "Enter the $mailType server address ($defaultServer)"
if ([string]::IsNullOrWhiteSpace($newServer)) { $newServer = $defaultServer }

$newSmtpServer = Read-Host "Enter the SMTP server address ($defaultSmtpServer)"
if ([string]::IsNullOrWhiteSpace($newSmtpServer)) { $newSmtpServer = $defaultSmtpServer }

# Optional: Display the collected input
Write-Host "`nCollected Information:"
Write-Host "Full Name:    $newFullName"
Write-Host "Username:     $newUsername"
Write-Host "Email:        $newEmail"
if ($mailType -eq "POP") {
Write-Host "POP Server:   $newServer"
} else {
Write-Host "IMAP Server:  $newServer"
}
Write-Host "SMTP Server:  $newSmtpServer"

# Set parameters based on mail type
if ($mailType -eq "POP") {
    $protocol = "pop3"
    $port = $defaultPOPport
    $serverHost = $newServer
} else {
    $protocol = "imap"
    $port = $defaultIMAPport
    $serverHost = $newServer
}

# Read prefs.js lines
$prefsLines = Get-Content $prefsPath

# Find highest used indexes
$accountMax = ($prefsLines -match 'mail\.account\.account(\d+)') | ForEach-Object { [int]($_ -replace '^.*account(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$serverMax  = ($prefsLines -match 'mail\.server\.server(\d+)')   | ForEach-Object { [int]($_ -replace '^.*server(\d+).*$', '$1') }   | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$identityMax = ($prefsLines -match 'mail\.identity\.(?:identity|id)(\d+)') | ForEach-Object { [int]($_ -replace '^.*(?:identity|id)(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$smtpMax = ($prefsLines -match 'mail\.smtpserver\.smtp(\d+)') | ForEach-Object { [int]($_ -replace '^.*smtp(\d+).*$', '$1') } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

# Compute next unused values
$nextAccount  = if ($accountMax)  { $accountMax + 1 } else { 1 }
$nextServer   = if ($serverMax)   { $serverMax + 1 }  else { 1 }
$nextIdentity = if ($identityMax) { $identityMax + 1 } else { 1 }
$nextSMTP = if ($smtpMax) { $smtpMax + 1 } else { 1 }

# Extract the existing mail.accountmanager.accounts line (if any)
$accountManagerLine = $prefsLines | Where-Object { $_ -match 'mail\.accountmanager\.accounts' }

# Extract existing accounts from the matched line
$existingAccounts = @()
#if ($accountManagerLine -match '"accountmanager\.accounts",\s*"([^"]+)"') {
if ($accountManagerLine -match 'accountmanager\.accounts",\s*"([^"]+)"') {
    $existingAccounts = $matches[1].Split(',') | ForEach-Object { $_.Trim() }
}

# Extract the existing mail.smtpservers line (if any)
$smtpserversLine = $prefsLines | Where-Object { $_ -match 'mail\.smtpservers' }

# Extract existing smtp servers from the matched line
$existingSMTPs = @()
#if ($smtpserversLine -match '"mail\.smtpservers",\s*"([^"]+)"') {
if ($smtpserversLine -match 'mail\.smtpservers",\s*"([^"]+)"') {
    $existingSMTPs = $matches[1].Split(',') | ForEach-Object { $_.Trim() }
}

# Now construct a valid user_pref line - mail.identity.identityX
if ($mailType -eq "POP") {
    $identityEntry = @"
user_pref("mail.identity.id$nextIdentity.organization", "");
user_pref("mail.identity.id$nextIdentity.reply_to", "");
"@  
} else {
    $identityEntry = @"
user_pref("mail.identity.id$nextIdentity.archive_folder", "imap://$newEmail/Archives");
user_pref("mail.identity.id$nextIdentity.draft_folder", "imap://$newEmail/Drafts");
user_pref("mail.identity.id$nextIdentity.fcc_folder", "imap://$newEmail/Sent");
user_pref("mail.identity.id$nextIdentity.trash_folder", "imap://$newEmail/Trash");
"@
}

# Now construct a valid user_pref line - mail.account.accountX
if ($mailType -eq "POP") {
    $accountEntry = @"
user_pref("mail.account.account$nextAccount.identities", "id$nextIdentity");
user_pref("mail.account.account$nextAccount.server", "server$nextServer");
"@  
} else {
    $accountEntry = @"
user_pref("mail.account.account$nextAccount.identities", "id$nextIdentity");
user_pref("mail.account.account$nextAccount.server", "server$nextServer");
"@
}

# Now construct a valid lastKey_pref line
$lastKeyEntry = @"
user_pref("mail.account.lastKey", $nextAccount);
"@

# Now construct a valid user_pref line - mail.server.server
if ($mailType -eq "POP") {
    $serverEntry = @"
user_pref("mail.server.server$nextServer.socketType", 3); // SSL/TLS
user_pref("mail.server.server$nextServer.authMethod", 3); // Normal password
"@  
} else {
    $serverEntry = @"
user_pref("mail.server.server$nextServer.isSecure", true); // SSL/TLS
"@
}

# Now construct a valid user_pref line - mail.accountmanager.accounts
$accountManagerEntry = 'user_pref("mail.accountmanager.accounts", "' + ($existingAccounts -join ",") + ',account' + $nextAccount + '");'

# Now construct a valid user_pref line - mail.smtpservers
$SMTPserversEntry = 'user_pref("mail.smtpservers", "' + ($existingSMTPs -join ",") + ',smtp' + $nextSMTP + '");'

# Compose user.js draft
$userJS = @"
// Draft user-draft.js script generated $today
// ChatGPT for bismarck-otto 2025-08-05 to set up new accounts

// Copyright (c) 2025 Otto von Bismarck
// This project includes portions generated using OpenAI’s ChatGPT.
// All code is released under the MIT License.

// user.js is loaded every time Thunderbird starts and overrides prefs.js
// If you forget to remove it after the accounts are added,
// you risk Thunderbird being stuck in a loop or not saving new changes.
// =======================================================================

// Draft user.js - safe to append

// Bypass setup wizard
user_pref("mail.provider.enabled", false);
user_pref("mail.rights.version", 1);
user_pref("mail.shell.checkDefaultClient", false);

// Identity for account$nextAccount
user_pref("mail.identity.id$nextIdentity.fullName", "$newFullName");
user_pref("mail.identity.id$nextIdentity.useremail", "$newEmail");
user_pref("mail.identity.id$nextIdentity.smtpServer", "smtp$nextSMTP");
$identityEntry

// Account$nextAccount - $mailType
$accountEntry

// LastKey in mail.account.lastKey
$lastKeyEntry

// $mailType Server $nextServer
user_pref("mail.server.server$nextServer.hostname", "$serverHost");
user_pref("mail.server.server$nextServer.type", "$protocol");
user_pref("mail.server.server$nextServer.port", $port);
user_pref("mail.server.server$nextServer.userName", "$newUsername");
user_pref("mail.server.server$nextServer.name", "$newEmail");
$serverEntry

// Shared SMTP Server $nextSMTP
user_pref("mail.smtpserver.smtp$nextSMTP.hostname", "$newSmtpServer");
user_pref("mail.smtpserver.smtp$nextSMTP.port", $defaultSMTPport);
user_pref("mail.smtpserver.smtp$nextSMTP.authMethod", 3); // Normal password
user_pref("mail.smtpserver.smtp$nextSMTP.socketType", 3); // SSL/TLS
user_pref("mail.smtpserver.smtp$nextSMTP.try_ssl", 3); 
user_pref("mail.smtpserver.smtp$nextSMTP.username", "$newUsername");

// SMTP servers
$SMTPserversEntry

// Account manager
$accountManagerEntry
"@

# Write to file
$draftPath = Join-Path $PSScriptRoot "user-draft.js"
$userJS | Set-Content -Encoding UTF8 $draftPath

Write-Host "`n✅ Draft user.js for $mailType written to: $draftPath"
