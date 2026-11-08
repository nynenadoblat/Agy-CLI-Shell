<#
.SYNOPSIS
    Создание и обновление ярлыков Antigravity Launcher (в папке проекта и на Рабочем столе).
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$launcherDir = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "Launch-Antigravity.vbs"))) {
    $PSScriptRoot
} else {
    $PWD.Path
}

$vbsRunner = Join-Path $launcherDir "Launch-Antigravity.vbs"
$iconIco   = Join-Path $launcherDir "app_icon.ico"
$wscript   = "$env:SystemRoot\System32\wscript.exe"

if (-not (Test-Path $vbsRunner)) {
    Write-Error "Файл Launch-Antigravity.vbs не найден в '$launcherDir'!"
    exit 1
}
if (-not (Test-Path $iconIco)) {
    Write-Error "Файл иконки app_icon.ico не найден в '$launcherDir'!"
    exit 1
}

$sh = New-Object -ComObject WScript.Shell

$shortcuts = @(
    (Join-Path $launcherDir "Antigravity Launcher.lnk"),
    (Join-Path ([Environment]::GetFolderPath("Desktop")) "Antigravity Launcher.lnk")
)

foreach ($lnkPath in $shortcuts) {
    try {
        $sc = $sh.CreateShortcut($lnkPath)
        $sc.TargetPath = $wscript
        $sc.Arguments = "`"$vbsRunner`""
        $sc.WorkingDirectory = $launcherDir
        $sc.IconLocation = "$iconIco,0"
        $sc.Description = "Antigravity Agent Launcher"
        $sc.Save()
        Write-Host "[OK] Ярлык успешно обновлен: $lnkPath" -ForegroundColor Green
    } catch {
        Write-Warning "Не удалось обновить ярлык '$lnkPath': $_"
    }
}

# Обновление кэша иконок Windows Shell
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ShellNotifyUtil {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@ -ErrorAction SilentlyContinue
    [ShellNotifyUtil]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Host "[OK] Кэш иконок Windows Shell обновлен." -ForegroundColor Green
} catch {}
