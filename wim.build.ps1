#Requires -Version 7.2

# -------------------------------------------------------------------------------------------------------------------- #
# INITIALIZATION.
# -------------------------------------------------------------------------------------------------------------------- #

function Start-BuildInit() {
  # Run.
  New-BuildImage
}

# -------------------------------------------------------------------------------------------------------------------- #
# WIM: NEW IMAGE.
# -------------------------------------------------------------------------------------------------------------------- #

function New-BuildImage() {
  $dir_drv = "$($PSScriptRoot)\drivers"
  $dir_log = "$($PSScriptRoot)\logs"
  $dir_mnt = "$($PSScriptRoot)\mount"
  $dir_upd = "$($PSScriptRoot)\updates"
  $dir_wim = "$($PSScriptRoot)\wim"
  $ts = Get-Date -Format "yyyy-MM-dd.HH-mm"
  [int]$sleep = 5

  if ( ! ( Test-Path "$($dir_drv)" ) ) {
    New-Item -Path "$($dir_drv)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($dir_log)" ) ) {
    New-Item -Path "$($dir_log)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($dir_mnt)" ) ) {
    New-Item -Path "$($dir_mnt)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($dir_upd)" ) ) {
    New-Item -Path "$($dir_upd)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($dir_wim)" ) ) {
    New-Item -Path "$($dir_wim)" -ItemType "Directory"
  }

  # Start build log.
  Start-Transcript -Path "$($PSScriptRoot)\$($dir_log)\wim.build.$($ts).log"

  while ( $true ) {
    # Check WIM file.
    if ( ! ( Test-Path -Path "$($dir_wim)\install.wim" -PathType leaf ) ) { break }

    # Get Windows image info.
    Write-Host "--- Get Windows Image Info..."
    Get-WindowsImage -ImagePath "$($dir_wim)\install.wim"
    [int]$wim_index = Read-Host "Enter WIM index (CTRL+C to EXIT)"
    if ( ! $wim_index ) { break }

    # Mount Windows image.
    Write-Host "--- Mount Windows Image..."
    Mount-WindowsImage -ImagePath "$($dir_wim)\install.wim" -Path "$($dir_mnt)" -Index $wim_index -CheckIntegrity
    Start-Sleep -s $sleep

    # Add packages.
    Write-Host "--- Add Windows Packages..."
    Add-WindowsPackage -Path "$($dir_mnt)" -PackagePath "$($dir_upd)" -IgnoreCheck
    Start-Sleep -s $sleep

    # Get packages.
    Write-Host "--- Get Windows Packages..."
    Get-WindowsPackage -Path "$($dir_mnt)"
    Start-Sleep -s $sleep

    # Add drivers.
    Write-Host "--- Add Windows Drivers..."
    Add-WindowsDriver -Path "$($dir_mnt)" -Driver "$($dir_drv)" -Recurse
    Start-Sleep -s $sleep

    # Reset Windows image.
    Write-Host "--- Reset & Save Windows Image..."
    Repair-WindowsImage -Path "$($dir_mnt)" -StartComponentCleanup -ResetBase
    Start-Sleep -s $sleep

    # Scan health Windows image.
    Write-Host "--- Scan Health Windows Image..."
    Repair-WindowsImage -Path "$($dir_mnt)" -ScanHealth
    Start-Sleep -s $sleep

    # Save & dismount Windows image.
    Write-Host "--- Dismount Windows Image..."
    Dismount-WindowsImage -Path "$($dir_mnt)" -Save
    Start-Sleep -s $sleep

    # Export ESD.
    Write-Host "--- Export Windows Image to ESD Format..."
    Dism /Export-Image /SourceImageFile:"$($dir_wim)\install.wim" /SourceIndex:$wim_index /DestinationImageFile:"$($dir_wim)\install.esd" /Compress:recovery /CheckIntegrity
    Start-Sleep -s $sleep
  }

  # Stop build log.
  Stop-Transcript
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildInit
