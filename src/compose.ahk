#Requires AutoHotkey >= 2
A_MaxHotkeysPerInterval := 150
A_HotkeyInterval := 1000
SetMouseDelay 1
SetDefaultMouseSpeed 2
SetKeyDelay -1
ProcessSetPriority "A"
FileEncoding "UTF-8" ; https://www.autohotkey.com/docs/v2/lib/File.htm#Encoding

if FileExist("compose.txt") == ""
{
	FileAppend "
	(
	; This file is used to create Compose key pairs
	; For details, specification, and guide of modification, refer to https://github.com/CarrieForle/xarty/wiki/Xarty-with-AHK#composetxt

	=btw=By the way
	=name=CarrieForle
	=lol=(ﾟ∀。)
	)", "compose.txt"
}

if FileExist("compose_config.ini") == ""
{
	FileAppend "
	(
	; This file is used to configure Compose behavior
	
	
	
	[compose-global]
	; Determine which key on your keyboard is Compose key.
	;
	; The value must be a letter, 
	; or special key defined here: https://www.autohotkey.com/docs/v2/KeyList.htm
	composeKey = RWin
	
	; Determine the interval window to wait for the press
	; of Compose key after a sequence is completed typing.
	;
	; The value must be a positive integer, indicating the window in milliseconds
	; or 0 to wait indefinitely (i.e. indefinte window)
	validComposeInterval = 5000
	
	; Determine the maximum length for a sequence to be valid.
	;
	; The value must be a positive integer, indicating the maximum valid length
	; or 0 to let the script do it for you. However, 0 will result in a slower startup.
	maximumComposeKeyLength = 20
	)", "compose_config.ini", "UTF-16"
}

activateCompose(hk) {
	if A_PriorHotKey !== hk
		onKeyDown(ih, GetKeyVK(hk), getKeySC(hk))
	KeyWait hk
}

try
{
	composeKey := IniRead("compose_config.ini", "compose-global", "composeKey"),
	intervalAllowedForComposeValidation := IniRead("compose_config.ini", "compose-global", "validComposeInterval")
	maximumComposeKeyLength := IniRead("compose_config.ini", "compose-global", "maximumComposeKeyLength")
	
	if !isInteger(intervalAllowedForComposeValidation)
		throw TypeError("validComposeInterval is not 0 or an positive integer")
	if !isInteger(maximumComposeKeyLength)
		throw TypeError("maximumComposeKeyLength is not 0 or an positive integer")
	if intervalAllowedForComposeValidation < 0
		throw ValueError("validComposeInterval cannot be negative")
	if maximumComposeKeyLength < 0
		throw ValueError("maximumComposeKeyLength cannot be negative")
	
	Hotkey(composeKey, activateCompose),
	intervalAllowedForComposeValidation := Integer(intervalAllowedForComposeValidation),
	maximumComposeKeyLength := Integer(maximumComposeKeyLength)
}

catch Error as e
{
	MsgBox "An error found in compose.ini`n" . e.Message 
	ExitApp
}

timeSinceLastKey := -intervalAllowedForComposeValidation - 1,
wordList := Array()

if maximumComposeKeyLength == 0
{
	Loop Read "compose.txt"
	{
		if A_LoopReadLine == ""
			continue
		delimiterChar := SubStr(A_LoopReadLine, 1, 1)
		if delimiterChar == ";" ||
		delimiterChar == "`n" ||
		delimiterChar == A_Tab ||
		delimiterChar == A_Space
			continue
		keypair := StrSplit(A_LoopReadLine, delimiterChar,, 3)
		if keypair.Length < 3 || keypair[2] == "" ||keypair[3] == ""
		{
			if "No" == MsgBox(A_LoopReadLine " is not a valid compose keypair.`n`nClick `"Yes`" to cuntinue and ignore this keypair.`nClick `"No`" to terminate the script.", "Error in compose.txt", 4)
				ExitApp
		}
		else if maximumComposeKeyLength < StrLen(keypair[2]) 
		{
			maximumComposeKeyLength := StrLen(keypair[2])
		}
	}
}

wordList.Length := wordList.Capacity := maximumComposeKeyLength

loop wordList.Length
	wordList[A_Index] := Map()

Loop Read "compose.txt"
{
	if A_LoopReadLine == ""
		continue
	delimiterChar := SubStr(A_LoopReadLine, 1, 1)
	if delimiterChar == ";" ||
	delimiterChar == "`n" ||
	delimiterChar == A_Tab ||
	delimiterChar == A_Space
		continue
	keypair := StrSplit(A_LoopReadLine, delimiterChar,, 3)
	if keypair.Length < 3 || keypair[2] == "" ||keypair[3] == ""
	{
		if "No" == MsgBox(A_LoopReadLine " is not a valid compose keypair.`n`nClick `"Yes`" to cuntinue and ignore this keypair.`nClick `"No`" to terminate the script.", "Error in compose.txt", 4)
			ExitApp
	}
	else if StrLen(keypair[2]) > maximumComposeKeyLength
	{
		if "No" == MsgBox(A_LoopReadLine " is too long for a key (> 10).`n`nClick `"Yes`" to cuntinue and ignore this keypair.`nClick `"No`" to terminate the script.", "Error in compose.txt", 4)
			ExitApp
	}
	else
	{
		wordList[maximumComposeKeyLength - StrLen(keypair[2]) + 1].Set(keypair[2], keypair[3])
	}
}

VarSetStrCapacity &keypair, 0

#SuspendExempt
RAlt & LAlt::
LAlt & RAlt::Suspend -1
^+sc006::Reload
^+sc029::ExitApp
#SuspendExempt false

ih := InputHook("V L" . maximumComposeKeyLength, "{Left}{Up}{Right}{Down}{Home}{PgUp}{End}{PgDn}"),
oldBuffer := ""

~Backspace::
~+Backspace::
{
	global oldBuffer
	if ih.Input == "" && oldBuffer != ""
		oldBuffer := SubStr(oldBuffer, 1, StrLen(oldBuffer) - 1)
}
~!Backspace::
~*^Backspace::
{
	if A_PriorHotKey != "~!Backspace" && A_PriorHotKey != "~*^Backspace"
	{
		ih.Stop(),
		ih.Start()
	}
}

onChar(ih, ch)
{
	global timeSinceLastKey := A_TickCount
}

onKeyDown(ih, vk, sc)
{
	global timeSinceLastKey
	
	if intervalAllowedForComposeValidation > 0 && A_TickCount - timeSinceLastKey > intervalAllowedForComposeValidation
	{
		ih.Stop(),
		ih.Start()
	}
	
	else if intervalAllowedForComposeValidation == 0 || A_TickCount - timeSinceLastKey <= intervalAllowedForComposeValidation
	{
		inpBuffer := oldBuffer . ih.Input
		for words in wordList
		{
			for key, val in words
			{
				if key == SubStr(inpBuffer, -StrLen(key))
				{
					ih.Stop(),
					SendInput("{Backspace " StrLen(key) "}")
					if InStr(composeKey, "#") || InStr(composeKey, "Win", false)
						SendText val
					else
						SendInput val
					ih.Start()
					return
				}
			}
		}
	}
}

onEnd(ih)
{
	global oldBuffer
	if ih.EndReason == "Max"
	{
		oldBuffer := ih.Input
		ih.Start()
	}
	else
	{
		if ih.EndReason == "EndKey"
			ih.Start()
		oldBuffer := ""
	}
}

ih.OnKeyDown := onKeyDown,
ih.OnEnd := onEnd,
ih.OnChar := onChar,
ih.Start()