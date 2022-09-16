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

# -------------------------------------------------------------------------------------------------------------------- #
# MESSAGES.
# -------------------------------------------------------------------------------------------------------------------- #

function Write-BFMsg() {
  param (
    [Alias("M")]
    [string]$Message,

    [Alias("T")]
    [string]$Type,

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

# -------------------------------------------------------------------------------------------------------------------- #
# 7Z ARCHIVE: COMPRESS.
# -------------------------------------------------------------------------------------------------------------------- #

function Compress-7z() {
  param (
    [Alias("I")]
    [string]$In,

    [Alias("O")]
    [string]$Out,

    [Alias("T")]
    [string]$Type = "7z"
  )

  $7zParams = "a", "-t$($Type)", "$($Out)", "$($In)"
  & "$($PSScriptRoot)\_META\7z\7za.exe" @7zParams
}

# -------------------------------------------------------------------------------------------------------------------- #
# 7Z ARCHIVE: EXPAND.
# -------------------------------------------------------------------------------------------------------------------- #

function Expand-7z() {
  param (
    [Alias("I")]
    [string]$In,

    [Alias("O")]
    [string]$Out
  )

  $7zParams = "x", "$($In)", "-o$($Out)", "-aoa"
  & "$($PSScriptRoot)\_META\7z\7za.exe" @7zParams
}
