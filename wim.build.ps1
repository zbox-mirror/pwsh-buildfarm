#Requires -Version 7.2
#Requires -RunAsAdministrator

Param(
  [Parameter(HelpMessage="Adds a single .cab or .msu file to a Windows image.")]
  [Alias("AP")]
  [switch]$AddPackages = $false,

  [Parameter(HelpMessage="Adds a driver to an offline Windows image.")]
  [Alias("AD")]
  [switch]$AddDrivers = $false,

  [Parameter(HelpMessage="Resets the base of superseded components to further reduce the component store size.")]
  [Alias("RB")]
  [switch]$ResetBase = $false,

  [Parameter(HelpMessage="Scans the image for component store corruption. This operation will take several minutes.")]
  [Alias("SH")]
  [switch]$ScanHealth = $false,

  [Parameter(HelpMessage="Saves the changes to a Windows image.")]
  [Alias("SI")]
  [switch]$SaveImage = $false,

  [Parameter(HelpMessage="Export WIM to ESD format.")]
  [Alias("ESD")]
  [switch]$ExportToESD = $false
)

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
  $d_app = "$($PSScriptRoot)\Apps"
  $d_drv = "$($PSScriptRoot)\Drivers"
  $d_log = "$($PSScriptRoot)\Logs"
  $d_mnt = "$($PSScriptRoot)\Mount"
  $d_tmp = "$($PSScriptRoot)\Temp"
  $d_upd = "$($PSScriptRoot)\Updates"
  $d_wim = "$($PSScriptRoot)\WIM"
  $ts = Get-Date -Format "yyyy-MM-dd.HH-mm-ss"
  [int]$sleep = 5

  if ( ! ( Test-Path "$($d_app)" ) ) { New-Item -Path "$($d_app)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($d_drv)" ) ) { New-Item -Path "$($d_drv)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($d_log)" ) ) { New-Item -Path "$($d_log)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($d_mnt)" ) ) { New-Item -Path "$($d_mnt)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($d_tmp)" ) ) { New-Item -Path "$($d_tmp)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($d_upd)" ) ) { New-Item -Path "$($d_upd)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($d_wim)" ) ) { New-Item -Path "$($d_wim)" -ItemType "Directory" }

  # Start build log.
  Start-Transcript -Path "$($d_log)\wim.build.$($ts).log"

  while ( $true ) {
    # Check WIM file exist.
    if ( ! ( Test-Path -Path "$($d_wim)\install.wim" -PathType Leaf ) ) { break }

    # Get Windows image hash.
    Write-BuildMsg -Title -Message "--- Get Windows Image Hash..."
    Get-FileHash "$($d_wim)\install.wim" -Algorithm "SHA256" | Format-List
    Start-Sleep -s $sleep

    # Get Windows image info.
    Write-BuildMsg -Title -Message "--- Get Windows Image Info..."
    Get-WindowsImage -ImagePath "$($d_wim)\install.wim" -ScratchDirectory "$($d_tmp)"
    [int]$wim_index = Read-Host "Enter WIM index (Press [ENTER] to EXIT)"
    if ( ! $wim_index ) { break }

    # Mount Windows image.
    Write-BuildMsg -Title -Message "--- Mount Windows Image..."
    Mount-WindowsImage -ImagePath "$($d_wim)\install.wim" -Path "$($d_mnt)" -Index $wim_index -CheckIntegrity -ScratchDirectory "$($d_tmp)"
    Start-Sleep -s $sleep

    if ( ( $AddPackages ) -and ( ! ( Get-ChildItem "$($d_upd)" | Measure-Object ).Count -eq 0 ) ) {
      # Add packages.
      Write-BuildMsg -Title -Message "--- Add Windows Packages..."
      Add-WindowsPackage -Path "$($d_mnt)" -PackagePath "$($d_upd)" -IgnoreCheck -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep

      # Get packages.
      Write-BuildMsg -Title -Message "--- Get Windows Packages..."
      Get-WindowsPackage -Path "$($d_mnt)" -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    }

    # Add drivers.
    if ( ( $AddDrivers ) -and ( ! ( Get-ChildItem "$($d_drv)" | Measure-Object ).Count -eq 0 ) ) {
      Write-BuildMsg -Title -Message "--- Add Windows Drivers..."
      Add-WindowsDriver -Path "$($d_mnt)" -Driver "$($d_drv)" -Recurse -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    }

    # Reset Windows image.
    if ( $ResetBase ) {
      Write-BuildMsg -Title -Message "--- Reset Windows Image..."
      Repair-WindowsImage -Path "$($d_mnt)" -StartComponentCleanup -ResetBase -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    }

    # Scan health Windows image.
    if ( $ScanHealth ) {
      Write-BuildMsg -Title -Message "--- Scan Health Windows Image..."
      Repair-WindowsImage -Path "$($d_mnt)" -ScanHealth -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    }

    # Dismount Windows image.
    if ( $SaveImage ) {
      Write-BuildMsg -Title -Message "--- Save & Dismount Windows Image..."
      Dismount-WindowsImage -Path "$($d_mnt)" -Save -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    } else {
      Write-BuildMsg -Title -Message "--- Discard & Dismount Windows Image..."
      Dismount-WindowsImage -Path "$($d_mnt)" -Discard -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    }

    if ( $ExportToESD ) {
      # Export Windows image to custom ESD format.
      Write-BuildMsg -Title -Message "--- Export Windows Image to Custom ESD Format..."
      Dism /Export-Image /SourceImageFile:"$($d_wim)\install.wim" /SourceIndex:$wim_index /DestinationImageFile:"$($d_wim)\install.custom.esd" /Compress:recovery /CheckIntegrity /ScratchDir:"$($d_tmp)"
      Start-Sleep -s $sleep
    } else {
      # Export Windows image to custom WIM format.
      Write-BuildMsg -Title -Message "--- Export Windows Image to Custom WIM Format..."
      Export-WindowsImage -SourceImagePath "$($d_wim)\install.wim" -SourceIndex $wim_index -DestinationImagePath "$($d_wim)\install.custom.wim" -CompressionType "max" -CheckIntegrity -ScratchDirectory "$($d_tmp)"
      Start-Sleep -s $sleep
    }

    # Create Windows image archive.
    Write-BuildMsg -Message "--- Create Windows Image Archive..."
    if ( ! ( Test-Path -Path "$($d_wim)\install.custom.esd" -PathType Leaf ) ) {
      "$($d_app)\7z\7za.exe" a -t7z "$($d_wim)\install.custom.esd" "$($d_wim)\install.custom.esd.7z"
    } elseif ( ! ( Test-Path -Path "$($d_wim)\install.custom.wim" -PathType Leaf ) ) {
      "$($d_app)\7z\7za.exe" a -t7z "$($d_wim)\install.custom.wim" "$($d_wim)\install.custom.wim.7z"
    } else {
      Write-Host "Not Found: 'install.custom.esd' or 'install.custom.wim'."
    }
    Start-Sleep -s $sleep
  }

  # Stop build log.
  Stop-Transcript
}

# -------------------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------< COMMON FUNCTIONS >------------------------------------------------ #
# -------------------------------------------------------------------------------------------------------------------- #

function Write-BuildMsg() {
  param (
    [string]$Message,
    [switch]$Title = $false
  )
  if ($Title) {
    Write-Host "$($Message)" -ForegroundColor Blue
  } else {
    Write-Host "$($Message)"
  }
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildInit
