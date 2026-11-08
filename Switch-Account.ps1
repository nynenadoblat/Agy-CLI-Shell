param(
    [Parameter(Mandatory=$true)][string]$AgyPath,
    [int]$DelaySeconds = 4
)
# Открывает agy и сам вводит команду /logout в этом окне, после чего agy предлагает способы входа.
# agy принимает /logout только как команду, введённую в интерактивном окне (через -i она уходит модели как текст),
# поэтому ввод делаем нажатием клавиш в окне этого процесса.
$host.UI.RawUI.WindowTitle = "Смена аккаунта: /logout вводится автоматически, затем войдите в нужный аккаунт и закройте окно"

$ownPid = $PID
$helperCmd = @"
Start-Sleep -Seconds $DelaySeconds
`$shell = New-Object -ComObject WScript.Shell
if (`$shell.AppActivate($ownPid)) {
    Start-Sleep -Milliseconds 500
    `$shell.SendKeys('/logout{ENTER}')
}
"@
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $helperCmd)

& $AgyPath
