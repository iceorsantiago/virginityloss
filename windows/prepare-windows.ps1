#Requires -RunAsAdministrator
# loq-dots: gets the fresh Windows install ready to live alongside Debian. Run it ONCE, as administrator,
# BEFORE installing Debian:   powershell -ExecutionPolicy Bypass -File .\prepare-windows.ps1
#  1. Turns off Fast Startup / hibernation: otherwise Windows leaves the NTFS disks "in use" and Linux
#     can only open D: read-only (and it sometimes blocks the Wi-Fi on reboot).
#  2. Clock in UTC, same as Linux.
#  3. Shows the BitLocker / device encryption status and how much free space is left on the disk.
$ErrorActionPreference = 'Stop'

Write-Host '==> Turning off Fast Startup and hibernation' -ForegroundColor Cyan
powercfg /h off
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord

Write-Host '==> BIOS clock in UTC' -ForegroundColor Cyan
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name RealTimeIsUniversal -Value 1 -Type DWord

Write-Host '==> BitLocker / device encryption' -ForegroundColor Cyan
try {
    Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus | Format-Table -AutoSize
    if (Get-BitLockerVolume | Where-Object ProtectionStatus -eq 'On') {
        Write-Host '   Encryption is on. Save the recovery key BEFORE you continue:' -ForegroundColor Yellow
        Write-Host '   https://account.microsoft.com/devices/recoverykey  (or: manage-bde -protectors -get C:)' -ForegroundColor Yellow
        Write-Host '   Installing Debian changes the boot setup and Windows may ask you for that key.' -ForegroundColor Yellow
    }
} catch { manage-bde -status }

Write-Host '==> Disks' -ForegroundColor Cyan
Get-Disk | Select-Object Number, FriendlyName, BusType, @{n='GB';e={[math]::Round($_.Size/1GB)}} | Format-Table -AutoSize
Get-Partition -DiskNumber (Get-Partition -DriveLetter C).DiskNumber |
    Select-Object PartitionNumber, DriveLetter, Type, @{n='GB';e={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize
Write-Host 'Done. The "unallocated" space on the internal disk is where Debian goes.' -ForegroundColor Green
