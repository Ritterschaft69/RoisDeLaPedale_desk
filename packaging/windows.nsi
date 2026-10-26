Unicode True
!include "MUI2.nsh"
!define PRODUCT "Rois de la Pédale"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\RoisDeLaPedale"
Name "${PRODUCT} 0.5.1"
OutFile "${__FILEDIR__}/../build/RoisDeLaPedale-0.5.1-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\RoisDeLaPedale"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "0.5.1.0"
VIAddVersionKey "ProductName" "${PRODUCT}"
VIAddVersionKey "FileDescription" "Installation du prototype de simulation cycliste"
VIAddVersionKey "FileVersion" "0.5.1.0"
VIAddVersionKey "LegalCopyright" "Contributeurs du projet — GPL-2.0"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${__FILEDIR__}/../LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "French"

Section "Application"
 SetShellVarContext current
 SetOutPath "$INSTDIR"
 File "${__FILEDIR__}/../build/windows/RoisDeLaPedale.exe"
 File "${__FILEDIR__}/../build/windows/RoisDeLaPedale.pck"
 File "${__FILEDIR__}/../build/windows/LICENSE"
 File "${__FILEDIR__}/../build/windows/THIRD_PARTY.md"
 File "${__FILEDIR__}/../build/windows/OpenSans-LICENSE.txt"
 File "${__FILEDIR__}/../build/windows/Apache-2.0.txt"
 File "${__FILEDIR__}/../build/windows/Godot-LICENSE.txt"
 File "${__FILEDIR__}/../build/windows/Godot-COPYRIGHT.txt"
 File "${__FILEDIR__}/../build/windows/IGN-Licence-Ouverte.md"
 File "${__FILEDIR__}/../build/windows/LISEZMOI.txt"
 WriteUninstaller "$INSTDIR\Desinstaller.exe"
 CreateDirectory "$SMPROGRAMS\Rois de la Pédale"
 CreateShortCut "$SMPROGRAMS\Rois de la Pédale\Rois de la Pédale.lnk" "$INSTDIR\RoisDeLaPedale.exe"
 CreateShortCut "$SMPROGRAMS\Rois de la Pédale\Désinstaller.lnk" "$INSTDIR\Desinstaller.exe"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT}"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "0.5.1"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Desinstaller.exe$\"'
 WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
 WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
 SetShellVarContext current
 Delete "$INSTDIR\RoisDeLaPedale.exe"
 Delete "$INSTDIR\RoisDeLaPedale.pck"
 Delete "$INSTDIR\LICENSE"
 Delete "$INSTDIR\THIRD_PARTY.md"
 Delete "$INSTDIR\OpenSans-LICENSE.txt"
 Delete "$INSTDIR\Apache-2.0.txt"
 Delete "$INSTDIR\Godot-LICENSE.txt"
 Delete "$INSTDIR\Godot-COPYRIGHT.txt"
 Delete "$INSTDIR\IGN-Licence-Ouverte.md"
 Delete "$INSTDIR\LISEZMOI.txt"
 Delete "$INSTDIR\Desinstaller.exe"
 Delete "$SMPROGRAMS\Rois de la Pédale\Rois de la Pédale.lnk"
 Delete "$SMPROGRAMS\Rois de la Pédale\Désinstaller.lnk"
 RMDir "$SMPROGRAMS\Rois de la Pédale"
 RMDir "$INSTDIR"
 DeleteRegKey HKCU "${UNINSTALL_KEY}"
 ; User settings and activities are intentionally preserved in AppData.
SectionEnd
