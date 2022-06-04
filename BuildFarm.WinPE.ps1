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
  [Parameter(HelpMessage="Enter ADK path.")]
  [Alias("ADKP")]
  [string]$ADKPath = "$($PSScriptRoot)\Apps\ADK",

  [Parameter(HelpMessage="Enter WIM language.")]
  [Alias("WL")]
  [string]$WimLanguage = "en-us",

  [Parameter(HelpMessage="")]
  [ValidateSet("amd64", "x86", "arm64")]
  [Alias("ARCH")]
  [string]$Arch = "amd64",

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

  [Parameter(HelpMessage="Saves the changes to a Windows image.")]
  [Alias("SI")]
  [switch]$SaveImage = $false,
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
  $F_WIM_ORIGINAL = "$($WimLanguage)\boot.wim"
  $F_WIM_CUSTOM = "$($WimLanguage)\boot.custom.$($TS).wim"

  # Sleep time.
  [int]$SLEEP = 10

  # New line separator.
  $NL = [Environment]::NewLine

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
  if ( -not ( Test-Path "$($D_APP)" ) ) { New-Item -Path "$($D_APP)" -ItemType "Directory" }
  if ( -not ( Test-Path "$($D_DRV)" ) ) { New-Item -Path "$($D_DRV)" -ItemType "Directory" }
  if ( -not ( Test-Path "$($D_LOG)" ) ) { New-Item -Path "$($D_LOG)" -ItemType "Directory" }
  if ( -not ( Test-Path "$($D_MNT)" ) ) { New-Item -Path "$($D_MNT)" -ItemType "Directory" }
  if ( -not ( Test-Path "$($D_TMP)" ) ) { New-Item -Path "$($D_TMP)" -ItemType "Directory" }
  if ( -not ( Test-Path "$($D_UPD)" ) ) { New-Item -Path "$($D_UPD)" -ItemType "Directory" }
  if ( -not ( Test-Path "$($D_WIM)" ) ) { New-Item -Path "$($D_WIM)" -ItemType "Directory" }

  # Start build log.
  Start-Transcript -Path "$($D_LOG)\wim.build.$($TS).log"

  while ( $true ) {

    # Check WIM file exist.
    if ( -not ( Test-Path -Path "$($D_WIM)\$($F_WIM_ORIGINAL)" -PathType "Leaf" ) ) { break }

    # Get Windows image hash.
    if ( -not $NoWimHash ) { Get-BFImageHash }

    # Get Windows image info.
    Write-BFMsg -Title -Message "--- Get Windows Image Info..."

    Dism /Get-ImageInfo /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /ScratchDir:"$($D_TMP)"
    [int]$WIM_INDEX = Read-Host "Enter WIM index (Press [ENTER] to EXIT)"
    if ( -not $WIM_INDEX ) { break }

    # Mount Windows image.
    Mount-BFImage

    if ( ( $AddPackages ) -and ( -not ( Get-ChildItem "$($D_UPD)" | Measure-Object ).Count -eq 0 ) ) {
      # Add packages.
      Add-BFPackages

      # Get packages.
      Get-BFPackages
    }

    # Add drivers.
    if ( ( $AddDrivers ) -and ( -not ( Get-ChildItem "$($D_DRV)" | Measure-Object ).Count -eq 0 ) ) {
      Add-BFDrivers
    }

    # Reset Windows image.
    if ( $ResetBase ) { Start-BFResetBase }

    # Dismount Windows image.
    if ( $SaveImage ) {
      Dismount-BFImage_Commit
    } else {
      Dismount-BFImage_Discard
    }

    # Export Windows image to custom WIM format.
    Export-BFImage_WIM

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
  Write-BFMsg -Title -Message "--- Import DISM Module..."

  $DismPath = "$($ADKPath)\Assessment and Deployment Kit\Deployment Tools\$($Arch)\DISM"

  if ( Get-Module -Name "Dism" ) {
    Write-Warning "DISM module is already loaded in this session. Please restart your PowerShell session." -WarningAction Stop
  }

  if ( -not ( Test-Path -Path "$($DismPath)\dism.exe" -PathType "Leaf" ) ) {
    Write-Warning "DISM in '$($DismPath)' not found. Please install DISM from 'https://go.microsoft.com/fwlink/?linkid=2196127'." -WarningAction Stop
  }

  $Env:Path = "$($DismPath)"
  Import-Module "$($DismPath)"
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

  Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-WMI_en-us.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFX.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-NetFX_en-us.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PowerShell.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-StorageWMI.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-DismCmdlets.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab" /ScratchDir:"$($D_TMP)"
  Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-FMAPI.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Dot3Svc.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-Dot3Svc_en-us.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PPPoE.cab" /PackagePath:"E:\BuildFarm\Windows.10\Apps\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-PPPoE_en-us.cab" /ScratchDir:"$($D_TMP)"
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

function Export-BFImage_WIM() {
  Write-BFMsg -Title -Message "--- Export Windows Image to Custom WIM Format..."

  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM)" /Compress:max /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Compress-BFImage() {
  Write-BFMsg -Title -Message "--- Create Windows Image Archive..."

  if ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM).esd" -PathType "Leaf" ) {
    Compress-7z -App "$($D_APP)\7z\7za.exe" -In "$($D_WIM)\$($F_WIM_CUSTOM).esd" -Out "$($D_WIM)\$($F_WIM_CUSTOM).esd.7z"
  } elseif ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM)" -PathType "Leaf" ) {
    Compress-7z -App "$($D_APP)\7z\7za.exe" -In "$($D_WIM)\$($F_WIM_CUSTOM)" -Out "$($D_WIM)\$($F_WIM_CUSTOM).7z"
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
    Write-Host "$($NL)$($Message)" -ForegroundColor Blue
  } else {
    Write-Host "$($Message)"
  }
}

function Compress-7z() {
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