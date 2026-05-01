# ChatGPT for bismarck-otto 2026-05-01 to Clean Thunderbird Local IMAP
#
# Copyright (c) 2026 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.
#
# Thunderbird Safe IMAP Cleanup
# =====================================================
# Safely quarantines Thunderbird IMAP offline/cache stores
# Optionally quarantines Thunderbird global search index files
# Never touches Mail\Local Folders
# Requires Thunderbird to be closed before running
# Supports limiting cleanup to one specific profile
# Uses path safety checks to avoid moving files outside the profile
# Moves targets to a timestamped quarantine folder instead of deleting them
# Runs as execute/quarantine mode by default unless changed in parameters

<#
SAFE Thunderbird IMAP cleanup
- Dry-run by default
- Never touches Mail\Local Folders
- Moves to quarantine, does not delete
- Requires Thunderbird to be closed
#>

param(
    [switch]$Execute = $true,
    [switch]$IncludeGlobalIndex = $true,
    [switch]$IncludeImapMail = $true,
    [string]$ProfileName = ""
)

$ErrorActionPreference = "Stop"

function Get-SizeGB($Path) {
    if (!(Test-Path $Path)) { return 0 }
    $sum = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum
    return [math]::Round(($sum / 1GB), 2)
}

function Assert-Inside($Child, $Parent) {
    $childFull = [IO.Path]::GetFullPath($Child)
    $parentFull = [IO.Path]::GetFullPath($Parent)
    if (!$childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing unsafe path: $childFull"
    }
}

$tbRoot = Join-Path $env:APPDATA "Thunderbird"
$profilesRoot = Join-Path $tbRoot "Profiles"

if (!(Test-Path $profilesRoot)) {
    throw "Thunderbird profile folder not found: $profilesRoot"
}

$tbProc = Get-Process thunderbird -ErrorAction SilentlyContinue
if ($tbProc) {
    throw "Thunderbird is running. Close Thunderbird first, then rerun this script."
}

$profiles = Get-ChildItem $profilesRoot -Directory

if ($ProfileName) {
    $profiles = $profiles | Where-Object { $_.Name -eq $ProfileName }
    if (!$profiles) {
        throw "Profile not found: $ProfileName"
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$quarantineRoot = Join-Path $tbRoot "_SAFE_CLEAN_QUARANTINE_$stamp"
New-Item -ItemType Directory -Path $quarantineRoot -Force | Out-Null

Write-Host "`nThunderbird safe cleanup"
Write-Host "Mode: " -NoNewline
if ($Execute) { Write-Host "EXECUTE / quarantine move" -ForegroundColor Yellow }
else { Write-Host "DRY RUN only" -ForegroundColor Cyan }

Write-Host "Quarantine: $quarantineRoot`n"

foreach ($profile in $profiles) {
    $profilePath = $profile.FullName
    Assert-Inside $profilePath $profilesRoot

    Write-Host "Profile: $($profile.Name)"
    Write-Host "Path:    $profilePath"

    $targets = @()

    if ($IncludeImapMail) {
        $imapPath = Join-Path $profilePath "ImapMail"
        if (Test-Path $imapPath) {
            $targets += [PSCustomObject]@{
                Type = "IMAP offline/cache stores"
                Path = $imapPath
            }
        }
    }

    if ($IncludeGlobalIndex) {
        $gloda = Join-Path $profilePath "global-messages-db.sqlite"
        if (Test-Path $gloda) {
            $targets += [PSCustomObject]@{
                Type = "Global search index"
                Path = $gloda
            }
        }

        $glodaShm = Join-Path $profilePath "global-messages-db.sqlite-shm"
        if (Test-Path $glodaShm) {
            $targets += [PSCustomObject]@{
                Type = "Global search index sidecar"
                Path = $glodaShm
            }
        }

        $glodaWal = Join-Path $profilePath "global-messages-db.sqlite-wal"
        if (Test-Path $glodaWal) {
            $targets += [PSCustomObject]@{
                Type = "Global search index sidecar"
                Path = $glodaWal
            }
        }
    }

    if (!$targets) {
        Write-Host "No cleanup targets found.`n"
        continue
    }

    foreach ($t in $targets) {
        Assert-Inside $t.Path $profilePath

        # Extra hard stop: never touch local mail archives
        if ($t.Path -like "*\Mail\Local Folders*") {
            throw "Refusing to touch Local Folders: $($t.Path)"
        }

        $sizeGB = Get-SizeGB $t.Path
        Write-Host "  Target: $($t.Type)"
        Write-Host "  Path:   $($t.Path)"
        Write-Host "  Size:   $sizeGB GB"

        if ($Execute) {
            $safeName = ($profile.Name + "__" + (Split-Path $t.Path -Leaf))
            $dest = Join-Path $quarantineRoot $safeName

            Write-Host "  Moving to quarantine..." -ForegroundColor Yellow
            Move-Item -LiteralPath $t.Path -Destination $dest
            Write-Host "  Moved: $dest"
        } else {
            Write-Host "  DRY RUN: would move to quarantine."
        }

        Write-Host ""
    }
}

Write-Host "Done."
if (!$Execute) {
    Write-Host "`nNo files were changed. Rerun with -Execute to actually quarantine the targets."
} else {
    Write-Host "`nFiles were moved, not deleted. Start Thunderbird and verify everything works."
    Write-Host "After verification, you may manually delete:"
    Write-Host $quarantineRoot
}
