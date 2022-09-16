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
  [string]$P_ADK = "$($PSScriptRoot)\_META\ADK",

  [Parameter(HelpMessage="CPU architecture.")]
  [ValidateSet("x86", "amd64", "arm", "arm64")]
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

  [Parameter(HelpMessage="Add .cab or .msu files to offline Windows image.")]
  [Alias("AP")]
  [switch]$P_AddPackages = $false,

  [Parameter(HelpMessage="Add drivers to offline Windows image.")]
  [Alias("AD")]
  [switch]$P_AddDrivers = $false,

  [Parameter(HelpMessage="Add apps to offline Windows image.")]
  [Alias("AA")]
  [switch]$P_AddApps = $false,

  [Parameter(HelpMessage="Reset base of superseded components to further reduce component store size.")]
  [Alias("RB")]
  [switch]$P_ResetBase = $false,

  [Parameter(HelpMessage="Scan image for component store corruption. This operation will take several minutes.")]
  [Alias("SH")]
  [switch]$P_ScanHealth = $false,

  [Parameter(HelpMessage="Save changes to Windows image.")]
  [Alias("SI")]
  [switch]$P_SaveImage = $false,

  [Parameter(HelpMessage="Export WIM to ESD format.")]
  [Alias("ESD")]
  [switch]$P_ExportToESD = $false,

  [Parameter(HelpMessage="Add single .cab or .msu file to offline Windows image from Windows ADK.")]
  [Alias("WPE_AP")]
  [switch]$P_WinPE_AddPackages = $false
)

# -------------------------------------------------------------------------------------------------------------------- #
# CONFIGURATION.
# -------------------------------------------------------------------------------------------------------------------- #

# Timestamp.
$TS = Get-Date -Format "yyyy-MM-dd.HH-mm-ss"

# Sleep time.
[int]$SLEEP = 10

# New line separator.
$NL = [Environment]::NewLine

# Directories.
$D_APP = "$($PSScriptRoot)\Apps"
$D_DRV = "$($PSScriptRoot)\Drivers"
$D_LOG = "$($PSScriptRoot)\Logs"
$D_MNT = "$($PSScriptRoot)\Mount"
$D_TMP = "$($PSScriptRoot)\Temp"
$D_UPD = "$($PSScriptRoot)\Updates"
$D_WIM = "$($PSScriptRoot)\WIM"

# WIM path.
$F_WIM_ORIGINAL = "$($P_Language)\$($P_Name).wim"
$F_WIM_CUSTOM = "$($P_Language)\$($P_Name).custom.$($TS).wim"

# Load functions.
. "$($PSScriptRoot)\BuildFarm.Functions.ps1"

# -------------------------------------------------------------------------------------------------------------------- #
# INITIALIZATION.
# -------------------------------------------------------------------------------------------------------------------- #

function Start-BuildFarm() {
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
      Write-BFMsg -T "W" -A "Stop" -M "'$($F_WIM_ORIGINAL)' not found!"
      break
    }

    # Get Windows image hash.
    if ( -not $P_NoWimHash ) { Get-BFImageHash }

    # Get Windows image info.
    Write-BFMsg -T "HL" -M "Get Windows Image Info..."

    Dism /Get-ImageInfo /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /ScratchDir:"$($D_TMP)"
    [int]$WIM_INDEX = Read-Host "Enter WIM index (Press [ENTER] to EXIT)"
    if ( -not $WIM_INDEX ) { break }

    # Mount Windows image.
    Mount-BFImage

    # Add ADK WinPE packages.
    if ( ( $P_WinPE_AddPackages ) -and ( $P_Name -eq "boot" ) ) { Add-BFPackages_WinPE }

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

    # Add drivers.
    if ( ( $P_AddApps ) -and ( -not ( Get-ChildItem "$($D_APP)" | Measure-Object ).Count -eq 0 ) ) {
      Add-BFApps
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
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildFarm
