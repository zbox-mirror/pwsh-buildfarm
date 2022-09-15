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
# ------------------------------------------------< COMMON FUNCTIONS >------------------------------------------------ #
# -------------------------------------------------------------------------------------------------------------------- #

function Import-BFModule_DISM() {
  Write-BFMsg -T "HL" -M "Import DISM Module..."

  $D_DISM = "$($P_ADK)\Assessment and Deployment Kit\Deployment Tools\$($P_CPU)\DISM"

  if ( Get-Module -Name "Dism" ) {
    Write-BFMsg -T "W" -A "Stop" -M "DISM module is already loaded in this session. Please restart your PowerShell session."
  }

  if ( -not ( Test-Path -Path "$($D_DISM)\dism.exe" -PathType "Leaf" ) ) {
    Write-BFMsg -T "W" -A "Stop" -M "DISM in '$($D_DISM)' not found. Please install DISM from 'https://go.microsoft.com/fwlink/?linkid=2196127'."
  }

  $Env:Path = "$($D_DISM)"
  Import-Module "$($D_DISM)"
}

function Set-BFDirs() {
  Write-BFMsg -T "HL" -M "Check & Create Directories..."

  $DIRs = @(
    "$($D_APP)"
    "$($D_DRV)"
    "$($D_LOG)"
    "$($D_MNT)"
    "$($D_TMP)"
    "$($D_UPD)"
    "$($D_WIM)"
  )

  foreach ( $DIR in $DIRs ) {
    if ( -not ( Test-Path "$($DIR)" ) ) { New-Item -Path "$($DIR)" -ItemType "Directory" }
  }
}

function Get-BFImageHash() {
  Write-BFMsg -T "HL" -M "Get Windows Image Hash..."

  Get-FileHash "$($D_WIM)\$($F_WIM_ORIGINAL)" -Algorithm "SHA256" | Format-List
  Start-Sleep -s $SLEEP
}

function Mount-BFImage() {
  Write-BFMsg -T "HL" -M "Mount Windows Image..."

  Dism /Mount-Image /ImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /MountDir:"$($D_MNT)" /Index:$WIM_INDEX /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFPackages_WinPE() {
  Write-BFMsg -T "HL" -M "Add ADK WinPE Packages..."

  $D_WPE = "$($P_ADK)\Assessment and Deployment Kit\Windows Preinstallation Environment\$($P_CPU)\WinPE_OCs"

  if ( -not ( Test-Path -Path "$($D_WPE)" ) ) {
    Write-BFMsg -T "W" -A "Stop" -M "WinPE in '$($D_WPE)' not found. Please install WinPE from 'https://go.microsoft.com/fwlink/?linkid=2196224'."
  }

  $PKGs = @(
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

  foreach ( $PKG in $PKGs ) {
    Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($D_WPE)\$($PKG).cab" /ScratchDir:"$($D_TMP)"
    if ( Test-Path -Path "$($D_WPE)\$($P_Language)\$($PKG)_$($P_Language).cab" -PathType "Leaf" ) {
      Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($D_WPE)\$($P_Language)\$($PKG)_$($P_Language).cab" /ScratchDir:"$($D_TMP)"
    }
  }

  Start-Sleep -s $SLEEP
}

function Add-BFPackages() {
  Write-BFMsg -T "HL" -M "Add Windows Packages..."

  Dism /Image:"$($D_MNT)" /Add-Package /PackagePath:"$($D_UPD)" /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Get-BFPackages() {
  Write-BFMsg -T "HL" -M "Get Windows Packages..."

  Dism /Image:"$($D_MNT)" /Get-Packages /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFDrivers() {
  Write-BFMsg -T "HL" -M "Add Windows Drivers..."

  Dism /Image:"$($D_MNT)" /Add-Driver /Driver:"$($D_DRV)" /Recurse /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Add-BFApps() {
  Write-BFMsg -T "HL" -M "Add Windows Apps..."

  $Apps = Get-ChildItem -Path "$($D_APP)" -Filter "*.7z" -Recurse
  foreach ( $App in $Apps ) {
    Expand-7z -I "$($App.FullName)" -O "$($D_MNT)\_DATA\Apps"
  }
  Start-Sleep -s $SLEEP
}

function Start-BFResetBase() {
  Write-BFMsg -T "HL" -M "Reset Windows Image..."

  Dism /Image:"$($D_MNT)" /Cleanup-Image /StartComponentCleanup /ResetBase /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Start-BFScanHealth() {
  Write-BFMsg -T "HL" -M "Scan Health Windows Image..."

  Dism /Image:"$($D_MNT)" /Cleanup-Image /ScanHealth /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Dismount-BFImage_Commit() {
  Write-BFMsg -T "HL" -M "Save & Dismount Windows Image..."

  Write-BFMsg -T "W" -A "Inquire" -M "WIM file will be save and dismount. Make additional edits to image."
  Dism /Unmount-Image /MountDir:"$($D_MNT)" /Commit /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Dismount-BFImage_Discard() {
  Write-BFMsg -T "HL" -M "Discard & Dismount Windows Image..."

  Write-BFMsg -T "W" -A "Inquire" -M "WIM file will be discard and dismount. All changes will be lost."
  Dism /Unmount-Image /MountDir:"$($D_MNT)" /Discard /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Export-BFImage_ESD() {
  Write-BFMsg -T "HL" -M "Export Windows Image to Custom ESD Format..."

  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM).esd" /Compress:recovery /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Export-BFImage_WIM() {
  Write-BFMsg -T "HL" -M "Export Windows Image to Custom WIM Format..."

  Dism /Export-Image /SourceImageFile:"$($D_WIM)\$($F_WIM_ORIGINAL)" /SourceIndex:$WIM_INDEX /DestinationImageFile:"$($D_WIM)\$($F_WIM_CUSTOM)" /Compress:max /CheckIntegrity /ScratchDir:"$($D_TMP)"
  Start-Sleep -s $SLEEP
}

function Compress-BFImage() {
  Write-BFMsg -T "HL" -M "Create Windows Image Archive..."

  if ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM).esd" -PathType "Leaf" ) {
    Compress-7z -I "$($D_WIM)\$($F_WIM_CUSTOM).esd" -O "$($D_WIM)\$($F_WIM_CUSTOM).esd.7z"
  } elseif ( Test-Path -Path "$($D_WIM)\$($F_WIM_CUSTOM)" -PathType "Leaf" ) {
    Compress-7z -I "$($D_WIM)\$($F_WIM_CUSTOM)" -O "$($D_WIM)\$($F_WIM_CUSTOM).7z"
  } else {
    Write-BFMsg -T "W" -M "Not Found: '$($F_WIM_CUSTOM)' or '$($F_WIM_CUSTOM).esd'."
  }
  Start-Sleep -s $SLEEP
}

function Write-BFMsg() {
  param (
    [Alias("M")]
    [string]$Message,

    [Alias("T")]
    [string]$Type = "",

    [Alias("A")]
    [string]$Action = "Continue"
  )

  switch ( $Type ) {
    "HL" {
      Write-Host "$($NL)--- $($Message)" -ForegroundColor Blue
    }
    "I" {
      Write-Information -MessageData "$($Message)" -InformationAction "$($Action)"
    }
    "W" {
      Write-Warning -Message "$($Message)" -WarningAction "$($Action)"
    }
    "E" {
      Write-Error -Message "$($Message)" -ErrorAction "$($Action)"
    }
    default {
      Write-Host "$($Message)"
    }
  }
}

function Compress-7z() {
  param (
    [Alias("I")]
    [string]$In = "",

    [Alias("O")]
    [string]$Out = "",

    [Alias("T")]
    [string]$Type = "7z"
  )

  $7zParams = "a", "-t$($Type)", "$($Out)", "$($In)"
  & "$($PSScriptRoot)\_META\7z\7za.exe" @7zParams
}

function Expand-7z() {
  param (
    [Alias("I")]
    [string]$In = "",

    [Alias("O")]
    [string]$Out = ""
  )

  $7zParams = "x", "$($In)", "-o$($Out)", "-aoa"
  & "$($PSScriptRoot)\_META\7z\7za.exe" @7zParams
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

Start-BuildFarm
