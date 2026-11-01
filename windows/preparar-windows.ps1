#Requires -RunAsAdministrator
# loq-dots: deja el Windows nuevo listo para convivir con Debian. Córrelo UNA vez, como administrador,
# ANTES de instalar Debian:   powershell -ExecutionPolicy Bypass -File .\preparar-windows.ps1
#  1. Apaga el Inicio rápido / hibernación: si no, Windows deja los discos NTFS "en uso" y Linux
#     solo puede abrir D: en modo lectura (y a veces bloquea el Wi-Fi al reiniciar).
#  2. Reloj en UTC, igual que Linux.
#  3. Muestra el estado de BitLocker / cifrado del dispositivo y cuánto espacio libre queda en el disco.
$ErrorActionPreference = 'Stop'

Write-Host '==> Apagando Inicio rápido e hibernación' -ForegroundColor Cyan
powercfg /h off
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord

Write-Host '==> Reloj del BIOS en UTC' -ForegroundColor Cyan
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name RealTimeIsUniversal -Value 1 -Type DWord

Write-Host '==> BitLocker / cifrado del dispositivo' -ForegroundColor Cyan
try {
    Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus | Format-Table -AutoSize
    if (Get-BitLockerVolume | Where-Object ProtectionStatus -eq 'On') {
        Write-Host '   Hay cifrado activo. Guarda la clave de recuperación ANTES de seguir:' -ForegroundColor Yellow
        Write-Host '   https://account.microsoft.com/devices/recoverykey  (o: manage-bde -protectors -get C:)' -ForegroundColor Yellow
        Write-Host '   Instalar Debian cambia el arranque y Windows puede pedirte esa clave.' -ForegroundColor Yellow
    }
} catch { manage-bde -status }

Write-Host '==> Discos' -ForegroundColor Cyan
Get-Disk | Select-Object Number, FriendlyName, BusType, @{n='GB';e={[math]::Round($_.Size/1GB)}} | Format-Table -AutoSize
Get-Partition -DiskNumber (Get-Partition -DriveLetter C).DiskNumber |
    Select-Object PartitionNumber, DriveLetter, Type, @{n='GB';e={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize
Write-Host 'Listo. El espacio "sin asignar" del disco interno es donde va Debian.' -ForegroundColor Green
