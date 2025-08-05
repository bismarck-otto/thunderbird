# ChatGPT for bismarck-otto 2025-08-06 to Clean-Thunderbird-Mail.ps1

# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Thunderbird Cleanup Script with Logging and Safe Move
# =====================================================
# Moves orphan folders and matching .msf files to quarantine folders
# Skips "Mail\Local Folders"
# Logs all actions to a .log file named after the script

# CONFIGURATION
$profilePath = "$env:APPDATA\Thunderbird\Profiles"
$defaultProfile = Get-ChildItem $profilePath | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1
$prefsFile = Join-Path $defaultProfile.FullName "prefs.js"
$mailDir = Join-Path $defaultProfile.FullName "Mail"
$imapDir = Join-Path $defaultProfile.FullName "ImapMail"

if (-not (Test-Path $prefsFile)) {
    Write-Host "prefs.js not found. Is Thunderbird initialized?" -ForegroundColor Red
    return
}

# LOGGING SETUP
$scriptPath = $MyInvocation.MyCommand.Path
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
$scriptDir = [System.IO.Path]::GetDirectoryName($scriptPath)
$logPath = Join-Path $scriptDir "$scriptName.log"
$quarantineDir = Join-Path $scriptDir "$scriptName.files"
$quarantineMail = Join-Path $quarantineDir "Mail"
$quarantineImap = Join-Path $quarantineDir "ImapMail"

New-Item -ItemType Directory -Force -Path $quarantineMail | Out-Null
New-Item -ItemType Directory -Force -Path $quarantineImap | Out-Null

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp $message"
}

# STEP 1: Extract account → server
$accountServers = @{}
Get-Content $prefsFile | ForEach-Object {
    if ($_ -match 'user_pref\("mail\.account\.account(\d+)\.server",\s*"(server\d+)"\)') {
        $accountServers[$matches[1]] = $matches[2]
    }
}

# STEP 2: Extract server → hostname + type
$serverHostnames = @{}
$serverTypes = @{}
Get-Content $prefsFile | ForEach-Object {
    if ($_ -match 'user_pref\("mail\.server\.(server\d+)\.hostname",\s*"(.*?)"\)') {
        $serverHostnames[$matches[1]] = $matches[2].ToLower()
    }
    if ($_ -match 'user_pref\("mail\.server\.(server\d+)\.type",\s*"(.*?)"\)') {
        $serverTypes[$matches[1]] = $matches[2].ToLower()
    }
}

# STEP 3: Build expected folders
function GetExpectedFolderNames {
    param ([hashtable]$hostTable, [hashtable]$typeTable, [string]$matchType)
    $expected = @()
    foreach ($serverId in $hostTable.Keys) {
        $hostname = $hostTable[$serverId]
        $type = $typeTable[$serverId]
        if ($type -eq $matchType) {
            for ($i = 0; $i -le 3; $i++) {
                $expected += if ($i -eq 0) { $hostname } else { "$hostname-$i" }
            }
        }
    }
    return $expected | Sort-Object -Unique
}

$expectedMailFolders = GetExpectedFolderNames -hostTable $serverHostnames -typeTable $serverTypes -matchType "pop3"
$expectedImapFolders = GetExpectedFolderNames -hostTable $serverHostnames -typeTable $serverTypes -matchType "imap"

# STEP 4: Detect unlinked folders
function Get-UnlinkedFolders {
    param (
        [string]$targetDir,
        [array]$expectedNames,
        [string]$skipFolder = ""
    )
    if (-not (Test-Path $targetDir)) { return @() }

    $existing = Get-ChildItem -Path $targetDir -Directory | ForEach-Object { $_.Name.ToLower() }

    return $existing | Where-Object {
        ($_ -ne $skipFolder.ToLower()) -and ($_ -notin $expectedNames)
    }
}

$mailUnlinked = Get-UnlinkedFolders -targetDir $mailDir -expectedNames $expectedMailFolders -skipFolder "Local Folders"
$imapUnlinked = Get-UnlinkedFolders -targetDir $imapDir -expectedNames $expectedImapFolders

# STEP 5: Find orphan .msf files that match unlinked folders only
function Get-MsfFilesLinkedToUnlinkedFolders {
    param (
        [string]$targetDir,
        [array]$unlinkedFolderNames
    )
    if (-not (Test-Path $targetDir)) { return @() }

    $msfFiles = Get-ChildItem -Path $targetDir -Filter "*.msf" | ForEach-Object { $_.Name }
    $orphanMsfs = @()

    foreach ($msf in $msfFiles) {
        $basename = [System.IO.Path]::GetFileNameWithoutExtension($msf).ToLower()
        if ($unlinkedFolderNames -contains $basename) {
            $orphanMsfs += $msf
        }
    }
    return $orphanMsfs
}

$mailOrphanMsfs = Get-MsfFilesLinkedToUnlinkedFolders -targetDir $mailDir -unlinkedFolderNames $mailUnlinked
$imapOrphanMsfs = Get-MsfFilesLinkedToUnlinkedFolders -targetDir $imapDir -unlinkedFolderNames $imapUnlinked

# STEP 6: Report
Write-Host "`n--- Unlinked Mail Folders ---" -ForegroundColor Cyan
$mailUnlinked | ForEach-Object { Write-Host "Mail\$_" }

Write-Host "`n--- Unlinked ImapMail Folders ---" -ForegroundColor Cyan
$imapUnlinked | ForEach-Object { Write-Host "ImapMail\$_" }

Write-Host "`n--- .msf Files Corresponding to Unlinked Mail Folders ---" -ForegroundColor Cyan
$mailOrphanMsfs | ForEach-Object { Write-Host "Mail\$_" }

Write-Host "`n--- .msf Files Corresponding to Unlinked ImapMail Folders ---" -ForegroundColor Cyan
$imapOrphanMsfs | ForEach-Object { Write-Host "ImapMail\$_" }

# STEP 7: Confirm deletion
if ($mailUnlinked.Count -eq 0 -and $imapUnlinked.Count -eq 0 -and $mailOrphanMsfs.Count -eq 0 -and $imapOrphanMsfs.Count -eq 0) {
    Write-Host "`n✅ Nothing to delete. Clean state!" -ForegroundColor Green
    Write-Log "No changes made. Nothing to delete."
    return
}

$confirm = Read-Host "`nDo you want to DELETE the listed folders and .msf files (they will be moved to quarantine)? (y/n)"
if ($confirm -eq 'y') {
    foreach ($folder in $mailUnlinked) {
        $src = Join-Path $mailDir $folder
        $dest = Join-Path $quarantineMail $folder
        Move-Item -Force -Path $src -Destination $dest
        Write-Host "Deleted: Mail\$folder"
        Write-Log "Deleted folder: Mail\$folder"
    }
    foreach ($folder in $imapUnlinked) {
        $src = Join-Path $imapDir $folder
        $dest = Join-Path $quarantineImap $folder
        Move-Item -Force -Path $src -Destination $dest
        Write-Host "Deleted: ImapMail\$folder"
        Write-Log "Deleted folder: ImapMail\$folder"
    }
    foreach ($msf in $mailOrphanMsfs) {
        $src = Join-Path $mailDir $msf
        $dest = Join-Path $quarantineMail $msf
        Move-Item -Force -Path $src -Destination $dest
        Write-Host "Deleted: Mail\$msf"
        Write-Log "Deleted file: Mail\$msf"
    }
    foreach ($msf in $imapOrphanMsfs) {
        $src = Join-Path $imapDir $msf
        $dest = Join-Path $quarantineImap $msf
        Move-Item -Force -Path $src -Destination $dest
        Write-Host "Deleted: ImapMail\$msf"
        Write-Log "Deleted file: ImapMail\$msf"
    }
    Write-Host "`n🧹 Cleanup complete. Files moved to $quarantineDir" -ForegroundColor Green
    Write-Log "Cleanup complete. Items moved to quarantine."
} else {
    Write-Host "`nNo changes made." -ForegroundColor Yellow
    Write-Log "User canceled deletion. No changes made."
}
# END OF SCRIPT