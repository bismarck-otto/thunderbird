# ChatGPT for bismarck-otto 2026-05-01 to List Thunderbird Disk Usage
#
# Copyright (c) 2026 Otto von Bismarck
# This project includes portions generated using OpenAI’s ChatGPT.
# All code is released under the MIT License.
#
# Thunderbird Disk Usage
# =====================================================
# Lists all Thunderbird profiles under %APPDATA%\Thunderbird\Profiles
# Calculates total disk usage per profile, including subfolders
# Includes hidden/system files where accessible
# Ignores files that cannot be read because of access or path errors
# Outputs profile name and size in GB

$tb = "$env:APPDATA\Thunderbird\Profiles"
Get-ChildItem $tb -Directory | % {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum
    [PSCustomObject]@{
        Profile = $_.Name
        SizeGB = [math]::Round($size / 1GB, 2)
    }
}
