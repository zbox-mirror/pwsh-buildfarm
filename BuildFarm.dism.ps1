<#
.SYNOPSIS
  Windows WIM modification script.
.DESCRIPTION
  The script modifies WIM image of operating system.
  Parameters define how the script works.
#>

#Requires -Version 7.2
#Requires -RunAsAdministrator

Param(
  [Parameter(HelpMessage="Enter DISM path.")]
  [Alias("DP")]
  [string]$DismPath = "$($PSScriptRoot)\Apps\ADK\Assessment and Deployment Kit\Deployment Tools\amd64\DISM",

  [Parameter(HelpMessage="Enter WIM language.")]
  [Alias("WL")]
  [string]$WimLanguage = "en-us",

  [Parameter(HelpMessage="Disable hash value for a WIM file.")]
  [Alias("NoWH")]
  [switch]$NoWimHash = $false,

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

function Start-BuildFarm() {
  # Directories.
  $D_APP = "$($PSScriptRoot)\Apps"
  $D_DRV = "$($PSScriptRoot)\Drivers"
  $D_LOG = "$($PSScriptRoot)\Logs"
  $D_MNT = "$($PSScriptRoot)\Mount"
  $D_TMP = "$($PSScriptRoot)\Temp"
  $D_UPD = "$($PSScriptRoot)\Updates"
  $D_WIM = "$($PSScriptRoot)\WIM"

  # Timestamp.
  $TS = Get-Date -Format "yyyy-MM-dd.HH-mm-ss"

  # WIM path.
  $F_WIM_ORIGINAL = "$($WimLanguage)\install.wim"
  $F_WIM_CUSTOM = "$($WimLanguage)\install.custom.$($TS).wim"

  # Sleep time.
  [int]$SLEEP = 10

  # Run.
  Start-BuildImage
}

# -------------------------------------------------------------------------------------------------------------------- #
# BUILD IMAGE.
# -------------------------------------------------------------------------------------------------------------------- #

function Start-BuildImage() {
  # Import DISM module.
  Import-BFModule_DISM

  # Check directories.
  if ( ! ( Test-Path "$($D_APP)" ) ) { New-Item -Path "$($D_APP)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($D_DRV)" ) ) { New-Item -Path "$($D_DRV)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($D_LOG)" ) ) { New-Item -Path "$($D_LOG)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($D_MNT)" ) ) { New-Item -Path "$($D_MNT)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($D_TMP)" ) ) { New-Item -Path "$($D_TMP)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($D_UPD)" ) ) { New-Item -Path "$($D_UPD)" -ItemType "Directory" }
  if ( ! ( Test-Path "$($D_WIM)" ) ) { New-Item -Path "$($D_WIM)" -ItemType "Directory" }

  # Start build log.
  Start-Transcript -Path "$($D_LOG)\wim.build.$($TS).log"

  while ( $true ) {

    # Check WIM file exist.
    if ( ! ( Test-Path -Path "$($D_WIM)\$($F_WIM_ORIGINAL)" -PathType "Leaf" ) ) { break }

    # Get Windows image hash.
    if ( ! $NoWimHash ) {
      Get-BFImageHash
    }

    # Get Windows image info.
    Write-BFMsg -Title -Message "--- Get Windows Image Info..."
    Dism /Get-ImageInfo /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /ScratchDir:"$($D_TMP)"
    [int]$WIM_INDEX = Read-Host "Enter WIM index (Press [ENTER] to EXIT)"
    if ( ! $WIM_INDEX ) { break }

    # Mount Windows image.
    Mount-BFImage

    if ( ( $AddPackages ) -and ( ! ( Get-ChildItem "$($D_UPD)" | Measure-Object ).Count -eq 0 ) ) {
      # Add packages.
      Add-BFPackages

      # Get packages.
      Get-BFPackages
    }

    # Add drivers.
    if ( ( $AddDrivers ) -and ( ! ( Get-ChildItem "$($D_DRV)" | Measure-Object ).Count -eq 0 ) ) {
      Add-BFDrivers
    }

    # Reset Windows image.
    if ( $ResetBase ) {
      Start-BFResetBase
    }

    # Scan health Windows image.
    if ( $ScanHealth ) {
      Start-BFScanHealth
    }

    # Dismount Windows image.
    if ( $SaveImage ) {
      Dismount-BFImage_Commit
    } else {
      Dismount-BFImage_Discard
    }

    if ( $ExportToESD ) {
      # Export Windows image to custom ESD format.
      Export-BFImage_ESD
    } else {
      # Export Windows image to custom WIM format.
      Export-BFImage_WIM
    }

    # Create Windows image archive.
    Compress-BFImage

  }

  # Stop build log.
  Stop-Transcript
}

# -------------------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------< COMMON FUNCTIONS >------------------------------------------------ #
# -------------------------------------------------------------------------------------------------------------------- #

function Import-BFModule_DISM() {
  # Get new DISM.
  Write-BFMsg -Title -Message "--- Get Modules..."
  Get-Module

  Write-BFMsg -Title -Message "--- Import Modules..."
  $DismModuleName = "DISM"
  $Env:Path = "$($DismPath)"
  if ( ! ( Get-Module -Name "$($DismModuleName)" ) ) {
    Import-Module "$($DismPath)"
  } else {
    Remove-Module -Name "$($DismModuleName)"
    Import-Module "$($DismPath)"
  }

  Write-BFMsg -Title -Message "--- Check Modules..."
  Get-Module
}

function Get-BFImageHash() {
  Write-BFMsg -Title -Message "--- Get Windows Image Hash..."
  Get-FileHash "$($D_WIM)\$($F_WIM_ORIGINAL)" -Algorithm "SHA256" | Format-List
  Start-Sleep -s $SLEEP
}

function Mount-BFImage() {
  Write-BFMsg -Title -Message "--- Mount Windows Image..."
  Dism /Mount-Image /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /MountDir:"$($D_MNT)" /Index:$WIM_INDEX /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFPackages() {
  Write-BFMsg -Title -Message "--- Add Windows Packages..."
  Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($D_UPD)" /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Get-BFPackages() {
  Write-BFMsg -Title -Message "--- Get Windows Packages..."
  Dism /Image:"$($D_MNT)" /Get-Packages /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFDrivers() {
  Write-BFMsg -Title -Message "--- Add Windows Drivers..."
  Dism /Image:"$($D_MNT)" /Add-Driver /Driver:"$($D_DRV)" /Recurse /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Start-BFResetBase() {
  Write-BFMsg -Title -Message "--- Reset Windows Image..."
  Dism /Image:"$($D_MNT)" /Cleanup-Image /StartComponentCleanup /ResetBase /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Start-BFScanHealth() {
  Write-BFMsg -Title -Message "--- Scan Health Windows Image..."
  Dism /Image:"$($D_MNT)" /Cleanup-Image /ScanHealth /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Dismount-BFImage_Commit() {
  Write-BFMsg -Title -Message "--- Save & Dismount Windows Image..."
  Dism /Unmount-Image /MountDir:"$($D_MNT)" /Commit /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Dismount-BFImage_Discard() {
  Write-BFMsg -Title -Message "--- Discard & Dismount Windows Image..."
  Dism /Unmount-Image /MountDir:"$($D_MNT)" /Discard /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Export-BFImage_ESD() {
  Write-BFMsg -Title -Message "--- Export Windows Image to Custom ESD Format..."
  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM).esd" /Compress:recovery /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Export-BFImage_WIM() {
  Write-BFMsg -Title -Message "--- Export Windows Image to Custom WIM Format..."
  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM)" /Compress:max /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Compress-BFImage() {
  Write-BFMsg -Title -Message "--- Create Windows Image Archive..."
  if ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM).esd" -PathType "Leaf" ) {
    New-7z -App "$($D_APP)\7z\7za.exe" -In "$($D_WIM)\$($F_WIM_CUSTOM).esd" -Out "$($D_WIM)\$($F_WIM_CUSTOM).esd.7z"
  } elseif ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM)" -PathType "Leaf" ) {
    New-7z -App "$($D_APP)\7z\7za.exe" -In "$($D_WIM)\$($F_WIM_CUSTOM)" -Out "$($D_WIM)\$($F_WIM_CUSTOM).7z"
  } else {
    Write-Host "Not Found: '$($F_WIM_CUSTOM)' or '$($F_WIM_CUSTOM).esd'."
  }
  Start-Sleep -s $SLEEP
}

function Write-BFMsg() {
  param (
    [string]$Message,
    [switch]$Title = $false
  )
  if ( $Title ) {
    Write-Host "$($Message)" -ForegroundColor Blue
  } else {
    Write-Host "$($Message)"
  }
}

function New-7z() {
  param (
    [string]$App,
    [string]$In,
    [string]$Out
  )
  $7zParams = "a", "-t7z", "$($Out)", "$($In)"
  & "$($App)" @7zParams
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildFarm
