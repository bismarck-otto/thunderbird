# ChatGPT for bismarck-otto 2026-05-01 to List Thunderbird Largest Files
#
# Copyright (c) 2026 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.
#
# Thunderbird Largest Files
# =====================================================
# Scans all Thunderbird profiles under %APPDATA%\Thunderbird\Profiles
# Recursively searches for all files in profile folders
# Sorts files by size in descending order
# Displays the 30 largest files found
# Outputs full file path and file size in GB
# Useful for identifying oversized mail folders, caches, and attachments

Get-ChildItem "$env:APPDATA\Thunderbird\Profiles" -Recurse -File |
Sort-Object Length -Descending |
Select-Object -First 30 FullName,
    @{N='SizeGB';E={[math]::Round($_.Length/1GB,2)}}
