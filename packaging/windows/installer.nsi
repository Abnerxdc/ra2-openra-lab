Unicode true
!include "MUI2.nsh"
Name "RA2 Lab Preview"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\RA2Lab"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "0.1.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "RA2 Lab Preview"
VIAddVersionKey /LANG=1033 "FileDescription" "RA2 Lab Windows setup (acceptance pending)"
VIAddVersionKey /LANG=1033 "FileVersion" "0.1.0"
VIAddVersionKey /LANG=1033 "LegalCopyright" "OpenRA and RA2 mod contributors; project contributors"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  IfFileExists "$INSTDIR\Uninstall.exe" 0 done
    MessageBox MB_OK|MB_ICONINFORMATION "请先卸载现有 RA2 Lab。卸载保留已导入资源与设置。"
    Abort
  done:
FunctionEnd

Section "Application"
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD_DIR}\*.*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\RA2 Lab"
  CreateShortcut "$SMPROGRAMS\RA2 Lab\RA2 Lab.lnk" "$INSTDIR\RA2Lab.exe" "" "$INSTDIR\RA2Lab.exe"
  CreateShortcut "$SMPROGRAMS\RA2 Lab\卸载.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\RA2 Lab.lnk" "$INSTDIR\RA2Lab.exe" "" "$INSTDIR\RA2Lab.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab" "DisplayName" "RA2 Lab Preview"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab" "DisplayVersion" "0.1.0-preview"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  !include "${OWNED_FILES}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\RA2 Lab.lnk"
  Delete "$SMPROGRAMS\RA2 Lab\RA2 Lab.lnk"
  Delete "$SMPROGRAMS\RA2 Lab\卸载.lnk"
  RMDir "$SMPROGRAMS\RA2 Lab"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\RA2Lab"
  ; User data in LOCALAPPDATA\RA2Lab is deliberately preserved.
SectionEnd
