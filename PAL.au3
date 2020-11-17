;Portable Application Launcher Beta
;Copyright 2011 Konstantinos Asimakis
;http://inshame.blogspot.com
;You may use the binary in any way you want.
;You may redistribute this code and the binary version UNMODIFIED ONLY but
;if you make modifications you can either send them to me to incorporate them
;to the original version or, at your option, you may use this code and binaries under the GNU/GPL v3 terms.

#NoTrayIcon
#include <File.au3>
Opt("ExpandEnvStrings", 1)

FileChangeDir(@ScriptFullPath)

Dim $types[11]
$types[0] = "REG_NONE"
$types[1] = "REG_SZ"
$types[2] = "REG_EXPAND_SZ"
$types[3] = "REG_BINARY"
$types[4] = "REG_DWORD"
$types[5] = "REG_DWORD_BIG_ENDIAN"
$types[6] = "REG_LINK"
$types[7] = "REG_MULTI_SZ"
$types[8] = "REG_RESOURCE_LIST"
$types[9] = "REG_FULL_RESOURCE_DESCRIPTOR"
$types[10] = "REG_RESOURCE_REQUIREMENTS_LIST"

Func hex2str($from)
	Local $to = ""
	For $i = 1 To BinaryLen($from) Step 2
		Local $number = Dec(BinaryToString(BinaryMid($from, $i, 2)))
		If Not @error Then $to &= Chr($number)
	Next
	Return $to
EndFunc   ;==>hex2str

Func str2hex($from)
	Local $to = ""
	For $i = 1 To BinaryLen($from)
		$to &= Hex(BinaryMid($from, $i, 1))
	Next
	Return $to
EndFunc   ;==>str2hex

;while True
;	msgbox(0,"",hex2str(inputbox("","")))
;	ClipPut(str2hex(inputbox("in","")))
;WEnd

Func RegKeyLoad($regfile)
	$h = FileOpen($regfile, 0)
	Do
		$keyname = FileReadLine($h)
		$valuename = FileReadLine($h)
		$type = FileReadLine($h)
		If $type == 3 Then
			$value = hex2str(FileReadLine($h))
		Else
			$value = FileReadLine($h)
		EndIf
		RegWrite($keyname, $valuename, $types[$type], $value)
		;Switch @error
		;case 1
		;	msgbox(48,"Error","Unable to open requested key. " & $regfile)
		;case 2
		;	msgbox(48,"Error","Unable to open requested main key. " & $regfile)
		;case 3
		;	msgbox(48,"Error","Unable to remote connect to the registry. " & $regfile)
		;case -1
		;	msgbox(48,"Error","Unable to open requested value. " & $regfile)
		;case -2
		;	msgbox(48,"Error","Value type not supported. " & $regfile)
		;EndSwitch
	Until @error <> 0
	FileClose($h)
EndFunc   ;==>RegKeyLoad

Func RegKeySave($key, $regfile)
	$h = FileOpen($regfile, 1)
	$instance = 1
	Do
		$value = RegEnumVal($key, $instance)
		$type = @extended
		If @error <> 0 Then ExitLoop
		FileWriteLine($h, $key)
		FileWriteLine($h, $value)
		FileWriteLine($h, $type)
		If $type == 3 Then
			FileWriteLine($h, str2hex(RegRead($key, $value)))
		Else
			FileWriteLine($h, RegRead($key, $value))
		EndIf
		$instance += 1
	Until False
	$instance = 1
	Do
		$newkey = RegEnumKey($key, $instance)
		If @error <> 0 Then ExitLoop
		ConsoleWrite("New subkey: " & $key & "\" & $newkey & @CRLF)
		RegKeySave($key & "\" & $newkey, $regfile)
		$instance += 1
	Until False
	FileClose($h)
EndFunc   ;==>RegKeySave

Func restore()
	ConsoleWrite("EXIT" & @CRLF)
	If ProcessExists($pid) Then
		ProgressOn("PAL", "Waiting for portable program to exit...")
		ProcessWaitClose($pid, 30)
		ProcessClose($pid)
		ProgressOff()
	EndIf
	ProgressOn("PAL", "Saving portable application data...")
	DirRemove(@ScriptDir & "\PortableData", 1)
	DirCopy($filespath, @ScriptDir & "\PortableData", 0)
	FileDelete("PortableRegistry.dat")
	RegKeySave($regpath, "PortableRegistry.dat")
	DirRemove($filespath, 1)
	DirCopy(@ScriptDir & "\LocalData", $filespath, 0)
	DirRemove(@ScriptDir & "\LocalData", 1)
	RegDelete($regpath)
	RegKeyLoad("LocalRegistry.dat")
	FileDelete("LocalRegistry.dat")
	ProgressOff()
EndFunc   ;==>restore

OnAutoItExitRegister("restore")

$cmdl = ""
For $i = 1 To $cmdline[0]
	$cmdl &= " " & $cmdline[$cmdline[0]]
Next
$exe = IniRead("PAL.ini", "PALOptions", "Executable", "") & $cmdl
If $exe == "" Then
	MsgBox(16, "PAL", "You have not setup the main executable in the INI file.")
	Exit 2
EndIf
$regpath = IniRead("PAL.ini", "PALOptions", "RegistryPath", "")
$filespath = IniRead("PAL.ini", "PALOptions", "FilesPath", "")

Dim $drive, $dir, $filename, $ext
_PathSplit($exe, $drive, $dir, $filename, $ext)

ProgressOn("PAL", "Loading portable application data...")
If Not FileExists("LocalRegistry.dat") And Not FileExists("LocalData") Then
	ConsoleWrite("OK" & @CRLF)
	DirCopy($filespath, @ScriptDir & "\LocalData", 0)
	RegKeySave($regpath, "LocalRegistry.dat")
	DirRemove($filespath, 1)
	RegDelete($regpath)
	DirCopy(@ScriptDir & "\PortableData", $filespath, 1)
	RegKeyLoad("PortableRegistry.dat")
	RegKeyLoad("PortableRegistryConsts.dat")
EndIf
ProgressOff()

ConsoleWrite(@WorkingDir & " " & $dir & @CRLF)
$pid = RunWait($exe)
Exit 0
