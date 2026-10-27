Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\Users\Olden\Desktop\IGROSTROY\AntigravityLauncher"
WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\Users\Olden\Desktop\IGROSTROY\AntigravityLauncher\AntigravityGUI.ps1""", 0, False