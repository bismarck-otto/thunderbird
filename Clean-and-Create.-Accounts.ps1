# bismarck-otto 2025-07-29 to Clean-and-Create.-Accounts.ps1

# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# Thunderbird Cleanup and Create Account Script user-draft.js
# ================================================================

# user.js is loaded every time Thunderbird starts and overrides prefs.js
# If you forget to remove it after the accounts are added,
# you risk Thunderbird being stuck in a loop or not saving new changes.
# =======================================================================

$readmePath = ".\README.txt"

if (Test-Path $readmePath) {
    Get-Content $readmePath | more
}else {
    Write-Host @"
# Copyright (c) 2025 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.

# user.js is loaded every time Thunderbird starts and overrides prefs.js
# If you forget to remove it after the accounts are added,
# you risk Thunderbird being stuck in a loop or not saving new changes.
# =======================================================================
"@
}

.\Clean-Thunderbird-Mail.ps1
.\Remove-Unused-Servers.ps1
.\Get-TB-Accounts.ps1
.\Generate-UserJS-Draft.ps1
