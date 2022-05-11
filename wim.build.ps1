#Requires -Version 7.2

# -------------------------------------------------------------------------------------------------------------------- #
# INITIALIZATION.
# -------------------------------------------------------------------------------------------------------------------- #

function Start-BuildInit() {
  # Run.
  New-BuildImage
}

# -------------------------------------------------------------------------------------------------------------------- #
# BUILD IMAGE.
# -------------------------------------------------------------------------------------------------------------------- #

function New-BuildImage() {
  $d_drv = "$($PSScriptRoot)\drivers"
  $d_log = "$($PSScriptRoot)\logs"
  $d_mnt = "$($PSScriptRoot)\mount"
  $d_upd = "$($PSScriptRoot)\updates"
  $d_wim = "$($PSScriptRoot)\wim"
  $ts = Get-Date -Format "yyyy-MM-dd.HH-mm-ss"
  [int]$sleep = 5

  if ( ! ( Test-Path "$($d_drv)" ) ) {
    New-Item -Path "$($d_drv)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($d_log)" ) ) {
    New-Item -Path "$($d_log)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($d_mnt)" ) ) {
    New-Item -Path "$($d_mnt)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($d_upd)" ) ) {
    New-Item -Path "$($d_upd)" -ItemType "Directory"
  }

  if ( ! ( Test-Path "$($d_wim)" ) ) {
    New-Item -Path "$($d_wim)" -ItemType "Directory"
  }

  # Start build log.
  Start-Transcript -Path "$($d_log)\wim.build.$($ts).log"

  while ( $true ) {
    # Check WIM file.
    if ( ! ( Test-Path -Path "$($d_wim)\install.wim" -PathType leaf ) ) { break }

    # Get Windows image info.
    Write-Host "--- Get Windows Image Info..."
    Get-WindowsImage -ImagePath "$($d_wim)\install.wim"
    [int]$wim_index = Read-Host "Enter WIM index (Press [ENTER] to EXIT)"
    if ( ! $wim_index ) { break }

    # Mount Windows image.
    Write-Host "--- Mount Windows Image..."
    Mount-WindowsImage -ImagePath "$($d_wim)\install.wim" -Path "$($d_mnt)" -Index $wim_index -CheckIntegrity
    Start-Sleep -s $sleep

    # Add packages.
    Write-Host "--- Add Windows Packages..."
    Add-WindowsPackage -Path "$($d_mnt)" -PackagePath "$($d_upd)" -IgnoreCheck
    Start-Sleep -s $sleep

    # Get packages.
    Write-Host "--- Get Windows Packages..."
    Get-WindowsPackage -Path "$($d_mnt)"
    Start-Sleep -s $sleep

    # Add drivers.
    Write-Host "--- Add Windows Drivers..."
    Add-WindowsDriver -Path "$($d_mnt)" -Driver "$($d_drv)" -Recurse
    Start-Sleep -s $sleep

    # Reset Windows image.
    Write-Host "--- Reset Windows Image..."
    Repair-WindowsImage -Path "$($d_mnt)" -StartComponentCleanup -ResetBase
    Start-Sleep -s $sleep

    # Scan health Windows image.
    Write-Host "--- Scan Health Windows Image..."
    Repair-WindowsImage -Path "$($d_mnt)" -ScanHealth
    Start-Sleep -s $sleep

    # Save & dismount Windows image.
    Write-Host "--- Save & Dismount Windows Image..."
    Dismount-WindowsImage -Path "$($d_mnt)" -Save
    Start-Sleep -s $sleep

    # Export ESD.
    Write-Host "--- Export Windows Image to ESD Format..."
    Dism /Export-Image /SourceImageFile:"$($d_wim)\install.wim" /SourceIndex:$wim_index /DestinationImageFile:"$($d_wim)\install.esd" /Compress:recovery /CheckIntegrity
    Start-Sleep -s $sleep
  }

  # Stop build log.
  Stop-Transcript
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildInit
