<#
.SYNOPSIS
    Быстрый легковесный шлюз проверки целостности Antigravity Launcher (< 2 секунд).
.DESCRIPTION
    1. Автоматически проверяет и накладывает UTF-8 BOM на все .ps1 файлы.
    2. Проверяет синтаксис PowerShell через AST-парсер (0 ошибок).
    3. Валидирует структуру launcher_config.json.
    4. Запускает AntigravityGUI.ps1 в изолированном headless-режиме (-Headless).
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$launcherDir = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "AntigravityGUI.ps1"))) {
    $PSScriptRoot
} else {
    "H:\IGROSTROY\Agy-CLI-Shell"
}

Write-Host "=== [FAST-CHECK] Запуск быстрой проверки целостности Launcher ===" -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# 1. Проверка и автоматическое наложение UTF-8 BOM на все .ps1 файлы
$psFiles = Get-ChildItem -Path $launcherDir -Filter "*.ps1" -File
$utf8Bom = [byte[]]@(0xEF, 0xBB, 0xBF)
$bomFixedCount = 0

foreach ($f in $psFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if (-not $hasBom) {
        $newBytes = New-Object byte[] ($bytes.Length + 3)
        [System.Buffer]::BlockCopy($utf8Bom, 0, $newBytes, 0, 3)
        [System.Buffer]::BlockCopy($bytes, 0, $newBytes, 3, $bytes.Length)
        [System.IO.File]::WriteAllBytes($f.FullName, $newBytes)
        $bomFixedCount++
        Write-Host "  [BOM FIX] Добавлен UTF-8 BOM: $($f.Name)" -ForegroundColor Yellow
    }
}
Write-Host "[OK] UTF-8 BOM проверен для $($psFiles.Count) файлов (исправлено: $bomFixedCount)." -ForegroundColor Green

# 2. Проверка синтаксиса через AST-парсер
foreach ($f in $psFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        Write-Error "Синтаксическая ошибка в $($f.Name) ($($errors.Count)):"
        foreach ($err in $errors) {
            Write-Host "  Строка $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
        }
        exit 1
    }
}
Write-Host "[OK] Синтаксис всех $($psFiles.Count) .ps1 файлов валиден (0 ошибок AST)." -ForegroundColor Green

# 3. Валидация файла конфигурации launcher_config.json
$cfgPath = Join-Path (Join-Path $env:APPDATA "AntigravityLauncher") "launcher_config.json"
if (-not (Test-Path $cfgPath)) {
    Write-Error "Файл launcher_config.json не найден!"
    exit 1
}
try {
    $rawCfg = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
    $cfgObj = $rawCfg | ConvertFrom-Json
    if (-not $cfgObj -or -not $cfgObj.tabs) {
        Write-Error "Файл launcher_config.json поврежден или не содержит массив tabs!"
        exit 1
    }
    Write-Host "[OK] launcher_config.json валиден (открыто вкладок: $($cfgObj.tabs.Count))." -ForegroundColor Green
} catch {
    Write-Error "Ошибка чтения JSON конфигурации: $_"
    exit 1
}

# 4. Изолированный запуск AntigravityGUI.ps1 в Headless-режиме
$scratchDir = Join-Path $launcherDir "scratch"
if (-not (Test-Path $scratchDir)) { [void](New-Item -ItemType Directory -Path $scratchDir -Force) }
$isolatedCfgPath = Join-Path $scratchDir "test_headless_config.json"
$env:ANTIGRAVITY_CONFIG_PATH = $isolatedCfgPath

try {
    # Создаем минимальный тестовый конфиг
    $testCfg = @{
        fontSize = 16
        windowWidth = 1150
        windowHeight = 850
        isMaximized = $true
        activeTabIndex = 0
        tabs = @(
            @{ title = "Тестовый диалог"; conversationId = $null; workspace = $launcherDir; model = "gemini-3.8-flash-high"; mode = "auto"; effort = "auto"; skipPerms = $true }
        )
    }
    [System.IO.File]::WriteAllText($isolatedCfgPath, ($testCfg | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)

    $guiPs1 = Join-Path $launcherDir "AntigravityGUI.ps1"
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guiPs1 -Headless 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AntigravityGUI.ps1 -Headless завершился с ошибкой (код $LASTEXITCODE):`r`n$output"
        exit 1
    }
    Write-Host "[OK] Запуск Headless-режима успешен (код 0)." -ForegroundColor Green
} finally {
    Remove-Item Env:\ANTIGRAVITY_CONFIG_PATH -ErrorAction SilentlyContinue
    if (Test-Path $isolatedCfgPath) {
        Remove-Item $isolatedCfgPath -Force -ErrorAction SilentlyContinue
    }
}

$sw.Stop()
Write-Host "=== [FAST-CHECK SUCCESS] Все быстрые проверки пройдены за $($sw.ElapsedMilliseconds) мс! ===" -ForegroundColor Green
exit 0
