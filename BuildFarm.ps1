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
  [Parameter(HelpMessage="ADK path.")]
  [Alias("ADK")]
  [string]$P_ADKPath = "$($PSScriptRoot)\Apps\ADK",

  [Parameter(HelpMessage="CPU architecture.")]
  [ValidateSet("x86", "amd64", "arm64")]
  [Alias("CPU")]
  [string]$P_CPU = "amd64",

  [Parameter(HelpMessage="WIM name.")]
  [Alias("WN")]
  [string]$P_Name = "install",

  [Parameter(HelpMessage="WIM language.")]
  [Alias("WL")]
  [string]$P_Language = "en-us",

  [Parameter(HelpMessage="Disable hash value for a WIM file.")]
  [Alias("NoWH")]
  [switch]$P_NoWimHash = $false,

  [Parameter(HelpMessage="Add ADK WinPE packages to WinPE image.")]
  [Alias("AP_ADK")]
  [switch]$P_AddPackages_ADK_WinPE = $false,

  [Parameter(HelpMessage="Adds a single .cab or .msu file to a Windows image.")]
  [Alias("AP")]
  [switch]$P_AddPackages = $false,

  [Parameter(HelpMessage="Adds a driver to an offline Windows image.")]
  [Alias("AD")]
  [switch]$P_AddDrivers = $false,

  [Parameter(HelpMessage="Resets the base of superseded components to further reduce the component store size.")]
  [Alias("RB")]
  [switch]$P_ResetBase = $false,

  [Parameter(HelpMessage="Scans the image for component store corruption. This operation will take several minutes.")]
  [Alias("SH")]
  [switch]$P_ScanHealth = $false,

  [Parameter(HelpMessage="Saves the changes to a Windows image.")]
  [Alias("SI")]
  [switch]$P_SaveImage = $false,

  [Parameter(HelpMessage="Export WIM to ESD format.")]
  [Alias("ESD")]
  [switch]$P_ExportToESD = $false
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
  $F_WIM_ORIGINAL = "$($P_Language)\$($P_Name).wim"
  $F_WIM_CUSTOM = "$($P_Language)\$($P_Name).custom.$($TS).wim"

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
  # Start build log.
  Start-Transcript -Path "$($D_LOG)\wim.build.$($TS).log"

  # Import DISM module.
  Import-BFModule_DISM

  # Check directories.
  Set-BFDirs

  while ( $true ) {

    # Check WIM file exist.
    if ( -not ( Test-Path -Path "$($D_WIM)\$($F_WIM_ORIGINAL)" -PathType "Leaf" ) ) {
      Write-Warning "'$($F_WIM_ORIGINAL)' not found!" -WarningAction Stop
      break
    }

    # Get Windows image hash.
    if ( -not $P_NoWimHash ) { Get-BFImageHash }

    # Get Windows image info.
    Write-BFMsg -T -M "--- Get Windows Image Info..."

    Dism /Get-ImageInfo /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /ScratchDir:"$($D_TMP)"
    [int]$WIM_INDEX = Read-Host "Enter WIM index (Press [ENTER] to EXIT)"
    if ( -not $WIM_INDEX ) { break }

    # Mount Windows image.
    Mount-BFImage

    # Add ADK WinPE packages.
    if ( ( $P_AddPackages_ADK_WinPE ) -and ( $P_Name -eq "boot" ) ) { Add-BFPackages_ADK_WinPE }

    if ( ( $P_AddPackages ) -and ( -not ( Get-ChildItem "$($D_UPD)" | Measure-Object ).Count -eq 0 ) ) {
      # Add packages.
      Add-BFPackages

      # Get packages.
      Get-BFPackages
    }

    # Add drivers.
    if ( ( $P_AddDrivers ) -and ( -not ( Get-ChildItem "$($D_DRV)" | Measure-Object ).Count -eq 0 ) ) {
      Add-BFDrivers
    }

    # Reset Windows image.
    if ( $P_ResetBase ) { Start-BFResetBase }

    # Scan health Windows image.
    if ( $P_ScanHealth ) { Start-BFScanHealth }

    # Dismount Windows image.
    if ( $P_SaveImage ) {
      Dismount-BFImage_Commit
    } else {
      Dismount-BFImage_Discard
    }

    if ( $P_ExportToESD ) {
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
  Write-BFMsg -T -M "--- Import DISM Module..."

  $DISM_Path = "$($P_ADKPath)\Assessment and Deployment Kit\Deployment Tools\$($P_CPU)\DISM"

  if ( Get-Module -Name "Dism" ) {
    Write-Warning "DISM module is already loaded in this session. Please restart your PowerShell session." -WarningAction Stop
  }

  if ( -not ( Test-Path -Path "$($DISM_Path)\dism.exe" -PathType "Leaf" ) ) {
    Write-Warning "DISM in '$($DISM_Path)' not found. Please install DISM from 'https://go.microsoft.com/fwlink/?linkid=2196127'." -WarningAction Stop
  }

  $Env:Path = "$($DISM_Path)"
  Import-Module "$($DISM_Path)"
}

function Set-BFDirs() {
  Write-BFMsg -T -M "--- Check & Create Directories..."

  $Dirs = @(
    "$($D_APP)"
    "$($D_DRV)"
    "$($D_LOG)"
    "$($D_MNT)"
    "$($D_TMP)"
    "$($D_UPD)"
    "$($D_WIM)"
  )

  foreach ($Dir in $Dirs) {
    if ( -not ( Test-Path "$($Dir)" ) ) { New-Item -Path "$($Dir)" -ItemType "Directory" }
  }
}

function Get-BFImageHash() {
  Write-BFMsg -T -M "--- Get Windows Image Hash..."

  Get-FileHash "$($D_WIM)\$($F_WIM_ORIGINAL)" -Algorithm "SHA256" | Format-List
  Start-Sleep -s $SLEEP
}

function Mount-BFImage() {
  Write-BFMsg -T -M "--- Mount Windows Image..."

  Dism /Mount-Image /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /MountDir:"$($D_MNT)" /Index:$WIM_INDEX /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFPackages_ADK_WinPE() {
  Write-BFMsg -T -M "--- Add ADK WinPE Packages..."

  $WinPE_Path = "$($P_ADKPath)\Assessment and Deployment Kit\Windows Preinstallation Environment\$($P_CPU)\WinPE_OCs"

  if ( -not ( Test-Path -Path "$($WinPE_Path)" ) ) {
    Write-Warning "WinPE in '$($WinPE_Path)' not found. Please install WinPE from 'https://go.microsoft.com/fwlink/?linkid=2196224'." -WarningAction Stop
  }

  $WinPE_Pkgs = @(
    "WinPE-WMI"
    "WinPE-NetFX"
    "WinPE-Scripting"
    "WinPE-PowerShell"
    "WinPE-StorageWMI"
    "WinPE-DismCmdlets"
    "WinPE-FMAPI"
    "WinPE-Dot3Svc"
    "WinPE-PPPoE"
  )

  foreach ($WinPE_Pkg in $WinPE_Pkgs) {
    Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($WinPE_Path)\$($WinPE_Pkg).cab" /ScratchDir:"$($D_TMP)"
    if ( Test-Path -Path "$($WinPE_Path)\$($P_Language)\$($WinPE_Pkg)_$($P_Language).cab" -PathType "Leaf" ) {
      Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($WinPE_Path)\$($P_Language)\$($WinPE_Pkg)_$($P_Language).cab" /ScratchDir:"$($D_TMP)"
    }
  }

  Start-Sleep -s $SLEEP
}

function Add-BFPackages() {
  Write-BFMsg -T -M "--- Add Windows Packages..."

  Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($D_UPD)" /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Get-BFPackages() {
  Write-BFMsg -T -M "--- Get Windows Packages..."

  Dism /Image:"$($D_MNT)" /Get-Packages /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFDrivers() {
  Write-BFMsg -T -M "--- Add Windows Drivers..."

  Dism /Image:"$($D_MNT)" /Add-Driver /Driver:"$($D_DRV)" /Recurse /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Start-BFResetBase() {
  Write-BFMsg -T -M "--- Reset Windows Image..."

  Dism /Image:"$($D_MNT)" /Cleanup-Image /StartComponentCleanup /ResetBase /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Start-BFScanHealth() {
  Write-BFMsg -T -M "--- Scan Health Windows Image..."

  Dism /Image:"$($D_MNT)" /Cleanup-Image /ScanHealth /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Dismount-BFImage_Commit() {
  Write-BFMsg -T -M "--- Save & Dismount Windows Image..."

  Write-Warning "WIM file will be save and dismount. Make additional edits to image." -WarningAction Inquire
  Dism /Unmount-Image /MountDir:"$($D_MNT)" /Commit /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Dismount-BFImage_Discard() {
  Write-BFMsg -T -M "--- Discard & Dismount Windows Image..."

  Write-Warning "WIM file will be discard and dismount. All changes will be lost." -WarningAction Inquire
  Dism /Unmount-Image /MountDir:"$($D_MNT)" /Discard /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Export-BFImage_ESD() {
  Write-BFMsg -T -M "--- Export Windows Image to Custom ESD Format..."

  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM).esd" /Compress:recovery /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Export-BFImage_WIM() {
  Write-BFMsg -T -M "--- Export Windows Image to Custom WIM Format..."

  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM)" /Compress:max /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Compress-BFImage() {
  Write-BFMsg -T -M "--- Create Windows Image Archive..."

  if ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM).esd" -PathType "Leaf" ) {
    Compress-7z -A "$($D_APP)\7z\7za.exe" -I "$($D_WIM)\$($F_WIM_CUSTOM).esd" -O "$($D_WIM)\$($F_WIM_CUSTOM).esd.7z"
  } elseif ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM)" -PathType "Leaf" ) {
    Compress-7z -A "$($D_APP)\7z\7za.exe" -I "$($D_WIM)\$($F_WIM_CUSTOM)" -O "$($D_WIM)\$($F_WIM_CUSTOM).7z"
  } else {
    Write-Host "Not Found: '$($F_WIM_CUSTOM)' or '$($F_WIM_CUSTOM).esd'."
  }
  Start-Sleep -s $SLEEP
}

function Write-BFMsg() {
  param (
    [Alias("M")]
    [string]$Message,
    [Alias("T")]
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
    [Alias("A")]
    [string]$App,
    [Alias("I")]
    [string]$In,
    [Alias("O")]
    [string]$Out
  )

  $7zParams = "a", "-t7z", "$($Out)", "$($In)"
  & "$($App)" @7zParams
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildFarm
