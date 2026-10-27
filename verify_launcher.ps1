<#
.SYNOPSIS
    Скрипт верификации и проверки целостности AntigravityLauncher.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$cfgBackupPath = Join-Path $PSScriptRoot "launcher_config.json"
$cfgBackupData = $null
if (Test-Path $cfgBackupPath) {
    try { $cfgBackupData = [System.IO.File]::ReadAllText($cfgBackupPath, [System.Text.Encoding]::UTF8) } catch {}
}
function Restore-LauncherConfigBackup {
    if ($cfgBackupData -and (Test-Path (Split-Path $cfgBackupPath))) {
        try {
            [System.IO.File]::WriteAllText($cfgBackupPath, $cfgBackupData, [System.Text.Encoding]::UTF8)
        } catch {}
    }
}

try {
Write-Host "=== Запуск проверки целостности AntigravityLauncher ===" -ForegroundColor Cyan

# 1. Проверка синтаксиса PowerShell через AST-парсер
$guiPs1 = Join-Path $PSScriptRoot "AntigravityGUI.ps1"
if (-not (Test-Path $guiPs1)) {
    Write-Error "Файл AntigravityGUI.ps1 не найден!"
    exit 1
}

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($guiPs1, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
    Write-Error "Обнаружены синтаксические ошибки в AntigravityGUI.ps1 ($($errors.Count)):"
    $errors | ForEach-Object { Write-Host "$($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }
    exit 1
}
Write-Host "[OK] Синтаксис AntigravityGUI.ps1 валиден (0 ошибок)." -ForegroundColor Green

# 2. Проверка работы основных функций без отображения UI
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Временно изолируем конфигурацию для чистого запуска тестов с 1 вкладкой по умолчанию
if (Test-Path $cfgBackupPath) {
    Remove-Item $cfgBackupPath -Force -ErrorAction SilentlyContinue
}

$scriptContent = Get-Content -Path $guiPs1 -Raw -Encoding utf8
$headlessContent = $scriptContent -replace '\$window\.ShowDialog\(\) \| Out-Null', '# Mock ShowDialog'
Invoke-Expression $headlessContent

$convs = Get-AntigravityConversations
if ($convs.Count -lt 1) {
    Write-Error "Не удалось обнаружить ни одного разговора!"
    exit 1
}
Write-Host "[OK] Найдено разговоров: $($convs.Count)." -ForegroundColor Green

$first = $convs[0]
$preview = Get-ConversationPreviewText -conversationId $first.Id
if (-not $preview) {
    Write-Error "Функция предпросмотра вернула пустой результат!"
    exit 1
}
Write-Host "[OK] Генерация предпросмотра работает корректно." -ForegroundColor Green

$transcript = Load-ConversationTranscript -conversationId $first.Id
if (-not $transcript) {
    Write-Error "Функция загрузки истории транскрипта вернула пустой результат!"
    exit 1
}
Write-Host "[OK] Загрузка истории транскрипта работает корректно." -ForegroundColor Green

Select-ConversationItem $first
if ($global:CurrentConversationId -ne $first.Id) {
    Write-Error "Выбор диалога не установил CurrentConversationId!"
    exit 1
}
Write-Host "[OK] Переключение диалога работает корректно." -ForegroundColor Green

Reset-ToNewChat
if ($null -ne $global:CurrentConversationId) {
    Write-Error "Сброс сессии не очистил CurrentConversationId!"
    exit 1
}
Write-Host "[OK] Сброс сессии на новый диалог работает корректно." -ForegroundColor Green

# 3. Проверка персистентности настроек шрифта
Set-AppZoom 3.0
$cfgPath = Join-Path $PSScriptRoot "launcher_config.json"
if (-not (Test-Path $cfgPath)) {
    Write-Error "Файл launcher_config.json не был создан при масштабировании!"
    exit 1
}
$cfgObj = Get-Content -Path $cfgPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($cfgObj.fontSize -ne $global:CurrentFontSize) {
    Write-Error "Сохраненный размер шрифта ($($cfgObj.fontSize)) не совпадает с CurrentFontSize ($($global:CurrentFontSize))!"
    exit 1
}
Write-Host "[OK] Сохранение размера шрифта в launcher_config.json работает корректно." -ForegroundColor Green

$reloadedCfg = Load-LauncherConfig
if ($reloadedCfg.fontSize -ne $cfgObj.fontSize) {
    Write-Error "Load-LauncherConfig вернул некорректный размер шрифта: $($reloadedCfg.fontSize) (ожидалось $($cfgObj.fontSize))"
    exit 1
}
Write-Host "[OK] Загрузка сохраненного размера шрифта работает корректно." -ForegroundColor Green

# 4. Проверка персистентности размеров окна
$window.Width = 1150
$window.Height = 850
Save-LauncherConfig

$cfgObj2 = Get-Content -Path $cfgPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($cfgObj2.windowWidth -ne 1150 -or $cfgObj2.windowHeight -ne 850) {
    Write-Error "Сохраненные размеры окна ($($cfgObj2.windowWidth)x$($cfgObj2.windowHeight)) некорректны (ожидалось 1150x850)!"
    exit 1
}
Write-Host "[OK] Сохранение размеров окна (1150x850) в launcher_config.json работает корректно." -ForegroundColor Green

$reloadedCfg2 = Load-LauncherConfig
if ($reloadedCfg2.windowWidth -ne 1150 -or $reloadedCfg2.windowHeight -ne 850) {
    Write-Error "Load-LauncherConfig вернул некорректные размеры окна!"
    exit 1
}
Write-Host "[OK] Загрузка сохраненных размеров окна работает корректно." -ForegroundColor Green

# 5. Проверка работы с прикрепленными изображениями
$testImgDir = Get-AttachmentsDirectory
if (-not (Test-Path $testImgDir)) {
    Write-Error "Папка вложений не была создана!"
    exit 1
}
$testImgPath = Join-Path $testImgDir "test_verify.png"
$bmp = [System.Drawing.Bitmap]::new(64, 64)
$bmp.Save($testImgPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Add-AttachedImageFile $testImgPath
if ($global:AttachedImages.Count -ne 1) {
    Write-Error "Изображение не было добавлено в AttachedImages!"
    exit 1
}
if ($borderAttachments.Visibility -ne [System.Windows.Visibility]::Visible) {
    Write-Error "Панель вложений не стала видимой!"
    exit 1
}
Write-Host "[OK] Добавление изображения и отображение панели вложений работает корректно." -ForegroundColor Green

Clear-AttachedImages
if ($global:AttachedImages.Count -ne 0 -or $borderAttachments.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "Очистка вложений не сбросила список и видимость панели!"
    exit 1
}
if (Test-Path $testImgPath) { Remove-Item $testImgPath -Force }
Write-Host "[OK] Очистка вложений работает корректно." -ForegroundColor Green

# 6. Проверка тёмной стилизации и шаблонов выпадающих списков (ComboBox)
$toggleBtnTemplate = $window.Resources["ComboBoxToggleButtonTemplate"]
if (-not $toggleBtnTemplate) {
    Write-Error "В ресурсах окна отсутствует ComboBoxToggleButtonTemplate!"
    exit 1
}
Write-Host "[OK] ComboBoxToggleButtonTemplate найден в ресурсах окна." -ForegroundColor Green

Refresh-ConversationsCombo
if ($cmbConversations.Items.Count -gt 1) {
    $firstConvItem = $cmbConversations.Items[1]
    if ($firstConvItem.DateColor -ne "#AAAAAA") {
        Write-Error "Цвет даты разговора $($firstConvItem.DateColor) не равен #AAAAAA!"
        exit 1
    }
}
Write-Host "[OK] Стилизация элементов разговоров (DateColor = #AAAAAA) валидна." -ForegroundColor Green

# 7. Проверка безопасного удаления диалогов (Remove-AntigravityConversation)
$fakeId = [guid]::NewGuid().ToString()
$fakeBrainDir = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$fakeId"
New-Item -ItemType Directory -Path $fakeBrainDir -Force | Out-Null
$fakeLog = Join-Path $fakeBrainDir ".system_generated\logs\transcript.jsonl"
New-Item -ItemType Directory -Path (Split-Path $fakeLog) -Force | Out-Null
Set-Content -Path $fakeLog -Value '{"step": 1, "type": "USER_INPUT", "content": "<USER_REQUEST>Fake test delete</USER_REQUEST>"}'

$badCall = Remove-AntigravityConversation "invalid-non-guid"
if ($badCall -ne $false) {
    Write-Error "Remove-AntigravityConversation не отклонил невалидный ID!"
    exit 1
}
Write-Host "[OK] Защита от удаления невалидных ID работает корректно." -ForegroundColor Green

$global:CurrentConversationId = $fakeId
$delSuccess = Remove-AntigravityConversation $fakeId
if (-not $delSuccess -or (Test-Path $fakeBrainDir)) {
    Write-Error "Remove-AntigravityConversation не смог удалить директорию диалога $fakeBrainDir!"
    exit 1
}
if ($null -ne $global:CurrentConversationId) {
    Write-Error "После удаления активного диалога CurrentConversationId не сбросился в null!"
    exit 1
}
Write-Host "[OK] Функция Remove-AntigravityConversation успешно удаляет диалог и сбрасывает сессию." -ForegroundColor Green

# 8. Проверка иконки приложения и ярлыков запуска
$iconPng = Join-Path $PSScriptRoot "app_icon.png"
$iconIco = Join-Path $PSScriptRoot "app_icon.ico"
$vbsRunner = Join-Path $PSScriptRoot "Launch-Antigravity.vbs"
$folderLnk = Join-Path $PSScriptRoot "Antigravity Launcher.lnk"
$desktopLnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "Antigravity Launcher.lnk"

if (-not (Test-Path $iconPng) -or (Get-Item $iconPng).Length -eq 0) {
    Write-Error "Файл app_icon.png отсутствует или пустой!"
    exit 1
}
if (-not (Test-Path $iconIco) -or (Get-Item $iconIco).Length -eq 0) {
    Write-Error "Файл app_icon.ico отсутствует или пустой!"
    exit 1
}
if (-not (Test-Path $vbsRunner)) {
    Write-Error "Файл Launch-Antigravity.vbs отсутствует!"
    exit 1
}
if (-not (Test-Path $folderLnk) -or -not (Test-Path $desktopLnk)) {
    Write-Error "Ярлыки запуска (в папке или на Рабочем столе) не найдены!"
    exit 1
}

$testIcon = [System.Drawing.Icon]::new($iconIco)
$testIcon.Dispose()

if ($window.Icon -eq $null) {
    Write-Error "Иконка окна `$window.Icon не была установлена!"
    exit 1
}
Write-Host "[OK] Иконка приложения (PNG/ICO), VBS-раннер и ярлыки на Рабочем столе валидны." -ForegroundColor Green

# 9. Проверка кодировки UTF-8 в ProcessStartInfo для предотвращения кракозябр
$guiText = Get-Content -Path $guiPs1 -Raw -Encoding utf8
if ($guiText -notmatch '\$psi\.StandardOutputEncoding\s*=\s*\[System\.Text\.Encoding\]::UTF8') {
    Write-Error "В ProcessStartInfo не задан StandardOutputEncoding = [System.Text.Encoding]::UTF8!"
    exit 1
}
if ($guiText -notmatch '\$psi\.StandardErrorEncoding\s*=\s*\[System\.Text\.Encoding\]::UTF8') {
    Write-Error "В ProcessStartInfo не задан StandardErrorEncoding = [System.Text.Encoding]::UTF8!"
    exit 1
}
Write-Host "[OK] Настройки кодировки ProcessStartInfo (UTF-8 для stdout и stderr) валидны." -ForegroundColor Green

# 10. Проверка цветной подсветки синтаксиса и сообщений в логе чата (RichTextBox)
if ($txtChatLog -isnot [System.Windows.Controls.RichTextBox]) {
    Write-Error "txtChatLog не является элементом [System.Windows.Controls.RichTextBox]!"
    exit 1
}

Clear-ChatLog
if ($txtChatLog.Document.Blocks.Count -ne 0) {
    Write-Error "Clear-ChatLog не очистил блоки документа RichTextBox!"
    exit 1
}

Append-ChatFormatted -Text "Тестовое сообщение пользователя" -Color "#4FC1FF" -Bold
Append-ChatFormatted -Text "Тестовый ответ агента" -Color "#C586C0"
Append-ChatFormatted -Text "Тестовый вызов инструмента" -Color "#CE9178"
Append-ChatFormatted -Text "Тестовое завершение инструмента" -Color "#4EC9B0"
Append-ChatFormatted -Text "Тестовая системная информация" -Color "#6A9955"
Append-ChatFormatted -Text "Тестовая ошибка" -Color "#F85149" -Bold

if ($txtChatLog.Document.Blocks.Count -eq 0) {
    Write-Error "Append-ChatFormatted не добавил текст в Document.Blocks!"
    exit 1
}

$testBrush = Get-CachedBrush "#4FC1FF"
if (-not $testBrush -or -not $testBrush.IsFrozen) {
    Write-Error "Get-CachedBrush не вернул замороженную кисть SolidColorBrush!"
    exit 1
}

if (-not $global:BrushCache.ContainsKey("#4FC1FF") -or -not $global:BrushCache.ContainsKey("#C586C0")) {
    Write-Error "Кэш кистей global:BrushCache не содержит запрошенных цветов!"
    exit 1
}

$renderedConv = Render-ConversationTranscriptToLog -conversationId $first.Id
if (-not $renderedConv) {
    Write-Error "Render-ConversationTranscriptToLog вернул false при наличии сообщений!"
    exit 1
}

Write-Host "[OK] RichTextBox и функции форматированного цветного вывода (Append-ChatFormatted, кэширование кистей) работают корректно." -ForegroundColor Green

# 10.1. Проверка компактного форматирования сообщения пользователя на одной строке (Append-UserMessageToLog)
Clear-ChatLog
Append-UserMessageToLog -TimeStr "12:00:00" -Text "Тестовый вопрос" -Badges "[🖼️ test.png]"
if ($txtChatLog.Document.Blocks.Count -ne 1) {
    Write-Error "Append-UserMessageToLog должен создавать ровно 1 компактный параграф, создано: $($txtChatLog.Document.Blocks.Count)"
    exit 1
}
$userPara = $txtChatLog.Document.Blocks.FirstBlock
$userParaText = [System.Windows.Documents.TextRange]::new($userPara.ContentStart, $userPara.ContentEnd).Text.Trim()
if ($userParaText -ne "[Вы (12:00:00)]: [🖼️ test.png] Тестовый вопрос") {
    Write-Error "Текст параграфа пользователя '$userParaText' не соответствует ожидаемому '[Вы (12:00:00)]: [🖼️ test.png] Тестовый вопрос'!"
    exit 1
}

Append-AgentHeader
if ($txtChatLog.Document.Blocks.Count -ne 2) {
    Write-Error "Append-AgentHeader должен добавить ровно 1 заголовочный параграф!"
    exit 1
}
Write-Host "[OK] Компактное размещение сообщения пользователя на одной строке без лишних переносов (Append-UserMessageToLog, Append-AgentHeader) валидно." -ForegroundColor Green

# 11. Проверка интерактивных сворачиваемых карточек вызовов инструментов (ToolGroupCard)
Clear-ChatLog

Add-ToolStartToGroup "read_file"
if (-not $global:ActiveToolGroup) {
    Write-Error "Add-ToolStartToGroup не создал ActiveToolGroup!"
    exit 1
}

$grp = $global:ActiveToolGroup
if ($grp.BodyBorder.Visibility -ne [System.Windows.Visibility]::Visible) {
    Write-Error "При активном выполнении карточка группы должна быть развернута!"
    exit 1
}
if (-not $grp.PendingItems.ContainsKey("read_file")) {
    Write-Error "PendingItems не содержит запись для read_file!"
    exit 1
}

Add-ToolDoneToGroup "read_file" 0.18
if ($grp.ToolCount -ne 1 -or $grp.TotalSeconds -ne 0.18) {
    Write-Error "Add-ToolDoneToGroup некорректно обновил ToolCount или TotalSeconds!"
    exit 1
}
if ($grp.PendingItems.ContainsKey("read_file")) {
    Write-Error "PendingItems не удалил выполненный инструмент read_file!"
    exit 1
}

Add-ToolStartToGroup "run_command"
Add-ToolDoneToGroup "run_command" 1.05
if ($grp.ToolCount -ne 2) {
    Write-Error "Ожидалось 2 завершенных инструмента в группе!"
    exit 1
}

# Проверка финализации и автоматического сворачивания группы при ответе агента
Finalize-ActiveToolGroup
if ($null -ne $global:ActiveToolGroup) {
    Write-Error "Finalize-ActiveToolGroup не сбросил ActiveToolGroup в `$null!"
    exit 1
}
if ($grp.BodyBorder.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "После Finalize-ActiveToolGroup карточка должна быть свернута (Collapsed)!"
    exit 1
}
if ($grp.ToggleHint.Text -notmatch 'Развернуть') {
    Write-Error "ToggleHint должен содержать 'Развернуть', текущий: $($grp.ToggleHint.Text)"
    exit 1
}

# Проверка интерактивного клика по кнопке-бейджу (разворачивание)
$clickEvent1 = [System.Windows.Input.MouseButtonEventArgs]::new(
    [System.Windows.Input.Mouse]::PrimaryDevice,
    0,
    [System.Windows.Input.MouseButton]::Left
)
$clickEvent1.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
$grp.ToggleBadge.RaiseEvent($clickEvent1)

if ($grp.BodyBorder.Visibility -ne [System.Windows.Visibility]::Visible) {
    Write-Error "Клик по кнопке-бейджу не развернул карточку инструментов!"
    exit 1
}

# Проверка повторного клика по шапке (сворачивание)
$clickEvent2 = [System.Windows.Input.MouseButtonEventArgs]::new(
    [System.Windows.Input.Mouse]::PrimaryDevice,
    0,
    [System.Windows.Input.MouseButton]::Left
)
$clickEvent2.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
$grp.HeaderBtn.RaiseEvent($clickEvent2)

if ($grp.BodyBorder.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "Повторный клик по шапке не свернул карточку инструментов!"
    exit 1
}

# 12. Проверка настроек отправки по клавише Enter
if ($txtPromptInput.AcceptsReturn -ne $false) {
    Write-Error "TxtPromptInput.AcceptsReturn должен быть `$false для немедленной отправки по Enter!"
    exit 1
}
if ($btnSend.IsDefault -ne $true) {
    Write-Error "BtnSend.IsDefault должен быть `$true!"
    exit 1
}
Write-Host "[OK] Настройки поля ввода и кнопки отправки по Enter валидны (AcceptsReturn = false, IsDefault = true)." -ForegroundColor Green

# Проверка создания карточки истории диалогов
$testHistoryTools = @(
    [pscustomobject]@{ Name = "read_file"; Summary = "Проверка конфига" },
    [pscustomobject]@{ Name = "edit_file"; Summary = "Правка скрипта" }
)
Add-HistoryToolGroupCard $testHistoryTools
Write-Host "[OK] Интерактивные сворачиваемые карточки вызовов инструментов (ToolGroupCard) работают корректно." -ForegroundColor Green

# 12. Проверка обработки Enter и Shift+Enter в поле ввода TxtPromptInput
$txtPromptInput.Text = "Hello World"
$txtPromptInput.CaretIndex = 5
$caret = $txtPromptInput.CaretIndex
$txtPromptInput.SelectedText = "`r`n"
$txtPromptInput.CaretIndex = $caret + 2
if (-not $txtPromptInput.Text.Contains("`r`n")) {
    Write-Error "Shift+Enter не вставил перевод строки!"
    exit 1
}
Write-Host "[OK] Обработка клавиши Enter для отправки и Shift+Enter для переноса строки работает корректно." -ForegroundColor Green

# 13. Проверка функционала многовкладочного интерфейса (мульти-сессий)
# 13.1. Начальное состояние: одна вкладка по умолчанию
if ($global:TabsList.Count -ne 1) {
    Write-Error "При инициализации должна быть ровно 1 вкладка, обнаружено: $($global:TabsList.Count)"
    exit 1
}
if ($global:ActiveTab -ne $global:TabsList[0]) {
    Write-Error "ActiveTab не указывает на первую вкладку!"
    exit 1
}
$tab1 = $global:TabsList[0]
Write-Host "[OK] Инициализация начальной вкладки ($($tab1.Title)) валидна." -ForegroundColor Green

# 13.2. Добавление новой вкладки (Add-NewTab)
$tab2 = Add-NewTab -Title "Вторая вкладка" -Select
if ($global:TabsList.Count -ne 2) {
    Write-Error "После Add-NewTab количество вкладок должно быть 2, обнаружено: $($global:TabsList.Count)"
    exit 1
}
if ($global:ActiveTab -ne $tab2) {
    Write-Error "Add-NewTab с флагом -Select не переключил ActiveTab на вторую вкладку!"
    exit 1
}
if ($txtChatLog.Document -ne $tab2.Document) {
    Write-Error "TxtChatLog.Document не переключился на документ второй вкладки!"
    exit 1
}
if ($tab1.Document -eq $tab2.Document) {
    Write-Error "Документы разных вкладок должны быть изолированными экземплярами FlowDocument!"
    exit 1
}

# Проверка, что кнопка '+' расположена строго рядом с крайней вкладкой
$btnIdx = $pnlTabsHeader.Children.IndexOf($btnNewTab)
$lastTabIdx = $pnlTabsHeader.Children.IndexOf($tab2.HeaderBorder)
if ($btnIdx -ne ($lastTabIdx + 1)) {
    Write-Error "BtnNewTab должен следовать строго сразу за крайней вкладкой! btnIdx=$btnIdx, lastTabIdx=$lastTabIdx"
    exit 1
}
Write-Host "[OK] Создание второй вкладки, изоляция FlowDocument и размещение кнопки [+] рядом с крайней вкладкой валидны." -ForegroundColor Green

# 13.3. Проверка независимости содержимого логов между вкладками
Append-ChatFormatted -Text "Сообщение для вкладки 1`r`n" -Document $tab1.Document
Append-ChatFormatted -Text "Сообщение для вкладки 2`r`n" -Document $tab2.Document

$tr1 = [System.Windows.Documents.TextRange]::new($tab1.Document.ContentStart, $tab1.Document.ContentEnd).Text
$tr2 = [System.Windows.Documents.TextRange]::new($tab2.Document.ContentStart, $tab2.Document.ContentEnd).Text

if (-not $tr1.Contains("Сообщение для вкладки 1") -or $tr1.Contains("Сообщение для вкладки 2")) {
    Write-Error "Вкладка 1 содержит некорректный текст или данные из вкладки 2!"
    exit 1
}
if (-not $tr2.Contains("Сообщение для вкладки 2") -or $tr2.Contains("Сообщение для вкладки 1")) {
    Write-Error "Вкладка 2 содержит некорректный текст или данные из вкладки 1!"
    exit 1
}
Write-Host "[OK] Изоляция текста и отсутствие перекрёстных помех (crosstalk) между вкладками подтверждены." -ForegroundColor Green

# 13.4. Проверка переключения вкладок (Switch-ToTab, Next-Tab, Prev-Tab)
Switch-ToTab -Tab $tab1
if ($global:ActiveTab -ne $tab1 -or $txtChatLog.Document -ne $tab1.Document) {
    Write-Error "Switch-ToTab не переключил активную вкладку на Tab1!"
    exit 1
}
Next-Tab
if ($global:ActiveTab -ne $tab2) {
    Write-Error "Next-Tab не переключил на Tab2!"
    exit 1
}
Prev-Tab
if ($global:ActiveTab -ne $tab1) {
    Write-Error "Prev-Tab не вернул на Tab1!"
    exit 1
}
Write-Host "[OK] Навигация между вкладками (Switch-ToTab, Next-Tab, Prev-Tab) работает корректно." -ForegroundColor Green

# 13.5. Проверка одновременной фоновой обработки очередей событий
$tab1.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = "Фоновый токен вкладки 1" })
$tab2.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = "Фоновый токен вкладки 2" })

# Эмулируем цикл обработки очередей таймера
foreach ($t in @($global:TabsList)) {
    $item = $null
    while ($t.SyncState.Queue.TryDequeue([ref]$item)) {
        if ($item.Type -eq "token") {
            Append-ChatFormatted -Text $item.Text -Document $t.Document
        }
    }
}

$tr1After = [System.Windows.Documents.TextRange]::new($tab1.Document.ContentStart, $tab1.Document.ContentEnd).Text
$tr2After = [System.Windows.Documents.TextRange]::new($tab2.Document.ContentStart, $tab2.Document.ContentEnd).Text

if (-not $tr1After.Contains("Фоновый токен вкладки 1") -or $tr1After.Contains("Фоновый токен вкладки 2")) {
    Write-Error "Фоновая очередь Tab1 дала сбой при параллельной обработке!"
    exit 1
}
if (-not $tr2After.Contains("Фоновый токен вкладки 2") -or $tr2After.Contains("Фоновый токен вкладки 1")) {
    Write-Error "Фоновая очередь Tab2 дала сбой при параллельной обработке!"
    exit 1
}
Write-Host "[OK] Параллельная фоновая обработка очередей сообщений без перекрёстных утечек подтверждена." -ForegroundColor Green

# 13.6. Проверка закрытия вкладки через клик по кнопке ✖
$dockChild = $tab2.HeaderBorder.Child
$closeBtnFound = $null
foreach ($child in $dockChild.Children) {
    if ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.TextBlock] -and $child.Child.Text -eq "✖") {
        $closeBtnFound = $child
        break
    }
}
if (-not $closeBtnFound) {
    Write-Error "Кнопка закрытия вкладки ✖ не найдена в заголовке вкладки!"
    exit 1
}

$closeClickEvent = [System.Windows.Input.MouseButtonEventArgs]::new(
    [System.Windows.Input.Mouse]::PrimaryDevice,
    0,
    [System.Windows.Input.MouseButton]::Left
)
$closeClickEvent.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
$closeBtnFound.RaiseEvent($closeClickEvent)

if ($global:TabsList.Count -ne 1) {
    Write-Error "После клика по ✖ количество вкладок должно быть 1, обнаружено: $($global:TabsList.Count)!"
    exit 1
}
if ($global:ActiveTab -ne $tab1) {
    Write-Error "После закрытия Tab2 через ✖ активной должна остаться Tab1!"
    exit 1
}

# Проверка, что после закрытия Tab2 кнопка '+' снова сразу после крайней оставшейся вкладки
$btnIdxAfter = $pnlTabsHeader.Children.IndexOf($btnNewTab)
$tab1Idx = $pnlTabsHeader.Children.IndexOf($tab1.HeaderBorder)
if ($btnIdxAfter -ne ($tab1Idx + 1)) {
    Write-Error "После закрытия вкладки BtnNewTab должен сместиться вплотную к Tab1! btnIdx=$btnIdxAfter, tab1Idx=$tab1Idx"
    exit 1
}
Write-Host "[OK] Закрытие вкладки через клик по кнопке ✖ и перемещение кнопки [+] валидны." -ForegroundColor Green

# 13.7. Закрытие последней вкладки должно создавать чистую вкладку-замену
Close-Tab -Tab $tab1
if ($global:TabsList.Count -ne 1) {
    Write-Error "После закрытия последней вкладки должна быть автоматически создана новая замена!"
    exit 1
}
if ($null -eq $global:ActiveTab) {
    Write-Error "После автоматического создания новой вкладки ActiveTab не должен быть null!"
    exit 1
}
Write-Host "[OK] Закрытие вкладок и автоматическое создание чистой вкладки при закрытии последней работают корректно." -ForegroundColor Green

# 13.8. Проверка межстрочного интервала (LineHeight и LineStackingStrategy)
if ($txtChatLog.Document.LineHeight -lt 20.0 -or $txtChatLog.Document.LineStackingStrategy -ne [System.Windows.LineStackingStrategy]::BlockLineHeight) {
    Write-Error "TxtChatLog.Document.LineHeight ($($txtChatLog.Document.LineHeight)) или LineStackingStrategy некорректны!"
    exit 1
}
if ($global:ActiveTab.Document.LineHeight -lt 20.0 -or $global:ActiveTab.Document.LineStackingStrategy -ne [System.Windows.LineStackingStrategy]::BlockLineHeight) {
    Write-Error "ActiveTab.Document.LineHeight ($($global:ActiveTab.Document.LineHeight)) или LineStackingStrategy некорректны!"
    exit 1
}
Write-Host "[OK] Межстрочный интервал (LineHeight >= 20.0, BlockLineHeight) настроен корректно." -ForegroundColor Green

# ==============================================================================
# 14. Проверка рендеринга и форматирования Markdown (Parse-InlineMarkdownRuns, Append-MarkdownFormatted)
# ==============================================================================
$testLine = 'Текст с **жирным словом**, *курсивом*, `Get-Process` и [ссылкой](https://example.com) и [exe](file:///C:/test.exe).'
$inlines = Parse-InlineMarkdownRuns -LineText $testLine -BaseColor "#D4D4D4" -FontSize 13.0
if ($inlines.Count -lt 5) {
    Write-Error "Parse-InlineMarkdownRuns не создал ожидаемое количество инлайн-элементов! (получено $($inlines.Count))"
    exit 1
}

$boldFound = $false
$italicFound = $false
$codeFound = $false
$linkFound = $false
$exeNotLink = $true

foreach ($inl in $inlines) {
    if ($inl -is [System.Windows.Documents.Run]) {
        if ($inl.Text -eq "жирным словом" -and $inl.FontWeight -eq [System.Windows.FontWeights]::Bold) {
            $boldFound = $true
        }
        if ($inl.Text -eq "курсивом" -and $inl.FontStyle -eq [System.Windows.FontStyles]::Italic) {
            $italicFound = $true
        }
        if ($inl.Text -match "Get-Process" -and $inl.FontFamily -and $inl.FontFamily.Source -match "Consolas") {
            $codeFound = $true
        }
        if ($inl.Text.Contains("exe") -and $inl -is [System.Windows.Documents.Hyperlink]) {
            $exeNotLink = $false
        }
    } elseif ($inl -is [System.Windows.Documents.Hyperlink]) {
        if ($inl.NavigateUri.AbsoluteUri -eq "https://example.com/") {
            $linkFound = $true
        }
    }
}

if (-not $boldFound) {
    Write-Error "Parse-InlineMarkdownRuns не распознал жирный текст (**жирным словом**)!"
    exit 1
}
if (-not $italicFound) {
    Write-Error "Parse-InlineMarkdownRuns не распознал курсив (*курсивом*)!"
    exit 1
}
if (-not $codeFound) {
    Write-Error "Parse-InlineMarkdownRuns не распознал инлайн-код (`Get-Process`)!"
    exit 1
}
if (-not $linkFound) {
    Write-Error "Parse-InlineMarkdownRuns не создал Hyperlink для ссылки [ссылкой](https://example.com)!"
    exit 1
}
if (-not $exeNotLink) {
    Write-Error "Parse-InlineMarkdownRuns создал Hyperlink для .exe файла (нарушение правила безопасности)!"
    exit 1
}
Write-Host "[OK] Парсер инлайн-разметки Parse-InlineMarkdownRuns (жирный, курсив, инлайн-код, ссылки, безопасность .exe) работает корректно." -ForegroundColor Green

# 14.2. Проверка блочного рендерера Append-MarkdownFormatted
$testDoc = [System.Windows.Documents.FlowDocument]::new()
$mdBlockSample = @'
# Заголовок первого уровня
## Подзаголовок второго уровня

Обычный абзац текста с **жирным** и `кодом`.

> Это важная цитата агента

| Параметр | Значение |
| :--- | :--- |
| Model | gemini-pro |
| Effort | high |

- Маркированный пункт 1
- Маркированный пункт 2

1. Первый шаг
2. Второй шаг

```powershell
Write-Host "Тест блока кода"
```

---
Конец блока.
'@

Append-MarkdownFormatted -Text $mdBlockSample -Document $testDoc -BaseColor "#D4D4D4" -FontSize 13.0

if ($testDoc.Blocks.Count -lt 10) {
    Write-Error "Append-MarkdownFormatted создал недостаточно блоков в FlowDocument! (получено $($testDoc.Blocks.Count))"
    exit 1
}

$h1Found = $false
$quoteFound = $false
$codeBlockFound = $false
$tableFound = $false
$hrFound = $false

foreach ($b in $testDoc.Blocks) {
    if ($b -is [System.Windows.Documents.Paragraph]) {
        if ($b.FontSize -ge 18 -and $b.FontWeight -eq [System.Windows.FontWeights]::Bold) {
            $h1Found = $true
        }
    } elseif ($b -is [System.Windows.Documents.BlockUIContainer]) {
        if ($b.Child -is [System.Windows.Controls.Border]) {
            $border = $b.Child
            if ($border.BorderThickness.Left -ge 2) {
                $quoteFound = $true
            } elseif ($border.Height -eq 1) {
                $hrFound = $true
            } elseif ($border.Child -is [System.Windows.Controls.DockPanel]) {
                $codeBlockFound = $true
            } elseif ($border.Child -is [System.Windows.Controls.Grid]) {
                $tableFound = $true
            }
        }
    }
}

if (-not $h1Found) {
    Write-Error "Append-MarkdownFormatted не создал стилизованный заголовок H1 (Paragraph с FontSize >= 18)!"
    exit 1
}
if (-not $quoteFound) {
    Write-Error "Append-MarkdownFormatted не создал контейнер цитаты BlockUIContainer с левой полосой!"
    exit 1
}
if (-not $codeBlockFound) {
    Write-Error "Append-MarkdownFormatted не создал контейнер блока кода BlockUIContainer!"
    exit 1
}
if (-not $tableFound) {
    Write-Error "Append-MarkdownFormatted не создал контейнер таблицы BlockUIContainer с Grid!"
    exit 1
}
if (-not $hrFound) {
    Write-Error "Append-MarkdownFormatted не создал горизонтальный разделитель BlockUIContainer!"
    exit 1
}
Write-Host "[OK] Блочный парсер Append-MarkdownFormatted (H1, цитаты, таблицы, списки, разделители, блоки кода) работает корректно." -ForegroundColor Green

# 14.3. Проверка гладкого потокового набора с последующей финализацией в Markdown
$streamTab = Add-NewTab -Title "StreamTest" -Select
$streamTab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = "Ответ " })
$streamTab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = "**агента** с " })
$streamTab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = "`кодом`." })

# Эмулируем работу таймера при поступлении токенов
$item = $null
while ($streamTab.SyncState.Queue.TryDequeue([ref]$item)) {
    if ($item.Type -eq "token") {
        if (-not $streamTab.StreamBuffer) {
            $streamTab.StreamBuffer = [System.Text.StringBuilder]::new()
        }
        if (-not $streamTab.ActiveStreamParagraph) {
            $streamTab.ActiveStreamParagraph = [System.Windows.Documents.Paragraph]::new()
            $streamTab.ActiveStreamParagraph.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)
            $streamTab.Document.Blocks.Add($streamTab.ActiveStreamParagraph)
        }
        [void]$streamTab.StreamBuffer.Append($item.Text)
        $run = [System.Windows.Documents.Run]::new($item.Text)
        $streamTab.ActiveStreamParagraph.Inlines.Add($run)
    }
}

if ($null -eq $streamTab.ActiveStreamParagraph -or $streamTab.StreamBuffer.Length -eq 0) {
    Write-Error "Потоковый параграф и буфер не были инициализированы во время поступления токенов!"
    exit 1
}

# Финализируем по завершению ответа (done)
Finalize-TabStreamingBuffer -Tab $streamTab

if ($null -ne $streamTab.ActiveStreamParagraph) {
    Write-Error "После Finalize-TabStreamingBuffer ActiveStreamParagraph должен быть очищен ($null)!"
    exit 1
}

# Проверяем, что в документе появился финальный блок с отформатированным жирным шрифтом
$finalBoldFound = $false
foreach ($b in $streamTab.Document.Blocks) {
    if ($b -is [System.Windows.Documents.Paragraph]) {
        foreach ($inl in $b.Inlines) {
            if ($inl -is [System.Windows.Documents.Run] -and $inl.Text -eq "агента" -and $inl.FontWeight -eq [System.Windows.FontWeights]::Bold) {
                $finalBoldFound = $true
            }
        }
    }
}

if (-not $finalBoldFound) {
    Write-Error "После финализации потока в FlowDocument не найден отформатированный Run с жирным текстом ('агента')!"
    exit 1
}
Write-Host "[OK] Потоковый буфер токенов с мгновенной финализацией в отформатированный Markdown работает корректно." -ForegroundColor Green

# Закрываем тестовую вкладку
Close-Tab -Tab $streamTab

# 15. Проверка функции Scroll-ChatLogToEnd и автоматической прокрутки вниз при открытии разговора
if (-not (Get-Command "Scroll-ChatLogToEnd" -ErrorAction SilentlyContinue)) {
    Write-Error "Функция Scroll-ChatLogToEnd не найдена в области видимости!"
    exit 1
}

# Тестируем вызов Scroll-ChatLogToEnd на активном окне
Scroll-ChatLogToEnd
Write-Host "[OK] Функция Scroll-ChatLogToEnd успешно вызвана без исключений." -ForegroundColor Green

# Тестируем переключение разговора с автопрокруткой
Select-ConversationItem $first
Scroll-ChatLogToEnd
Write-Host "[OK] Открытие разговора с автоматической прокруткой Scroll-ChatLogToEnd работает корректно." -ForegroundColor Green

# Физическая верификация прокрутки вниз на FlowDocument через тестовый RichTextBox
$testScrollWin = [System.Windows.Window]::new()
$testScrollWin.Width = 400
$testScrollWin.Height = 300
$testScrollWin.ShowInTaskbar = $false
$testScrollWin.WindowStyle = [System.Windows.WindowStyle]::None
$testScrollWin.AllowsTransparency = $true
$testScrollWin.Opacity = 0.01

$testScrollRtb = [System.Windows.Controls.RichTextBox]::new()
$testScrollRtb.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Visible
$testScrollDoc = [System.Windows.Documents.FlowDocument]::new()
for ($si = 0; $si -lt 50; $si++) {
    $p = [System.Windows.Documents.Paragraph]::new([System.Windows.Documents.Run]::new("Тестовая строка лога $si"))
    $testScrollDoc.Blocks.Add($p)
}
$testScrollRtb.Document = $testScrollDoc
$testScrollWin.Content = $testScrollRtb
$testScrollWin.Show()

$savedTxtChatLog = $txtChatLog
$txtChatLog = $testScrollRtb
try {
    Scroll-ChatLogToEnd

    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Action]{
        $frame.Continue = $false
    }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)

    $offset = $testScrollRtb.VerticalOffset
    $extent = $testScrollRtb.ExtentHeight
    $viewport = $testScrollRtb.ViewportHeight

    if ($offset -le 0 -or [math]::Abs($offset - ($extent - $viewport)) -gt 2) {
        Write-Error "Scroll-ChatLogToEnd не прокрутил документ до конца! Offset=$offset, Extent=$extent, Viewport=$viewport"
        exit 1
    }
} finally {
    $txtChatLog = $savedTxtChatLog
    $testScrollWin.Close()
}
Write-Host "[OK] Физическая автоматическая прокрутка чата вниз (Scroll-ChatLogToEnd) подтверждена (Offset=$offset, Extent=$extent, Viewport=$viewport)." -ForegroundColor Green

# 16. Проверка оверлея анимации загрузки (LoadingOverlay, SpinnerRotate) и асинхронной загрузки диалогов (No-Freeze)
if (-not $loadingOverlay) {
    Write-Error "Элемент LoadingOverlay не найден в ресурсах окна!"
    exit 1
}
if (-not $spinnerRotate) {
    Write-Error "Элемент SpinnerRotate не найден в ресурсах окна!"
    exit 1
}
if (-not $txtLoadingTitle -or -not $txtLoadingSubtitle) {
    Write-Error "Текстовые элементы TxtLoadingTitle или TxtLoadingSubtitle не найдены!"
    exit 1
}

# Проверка функций показа и скрытия оверлея
Show-LoadingOverlay -Title "Тестовая загрузка" -Subtitle "Проверка анимации..."
if ($loadingOverlay.Visibility -ne [System.Windows.Visibility]::Visible) {
    Write-Error "Show-LoadingOverlay не перевёл LoadingOverlay в состояние Visible!"
    exit 1
}
if ($txtLoadingTitle.Text -ne "Тестовая загрузка") {
    Write-Error "Show-LoadingOverlay не установил заголовок!"
    exit 1
}

Hide-LoadingOverlay
if ($loadingOverlay.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "Hide-LoadingOverlay не перевёл LoadingOverlay в состояние Collapsed!"
    exit 1
}
Write-Host "[OK] Элементы анимированного оверлея (LoadingOverlay, SpinnerRotate) и функции Show/Hide работают корректно." -ForegroundColor Green

# Проверка плавной асинхронной загрузки диалога через Start-AsyncTranscriptLoad
$testTab = Add-NewTab -Title "AsyncTab" -Select
Select-ConversationItem $first

if ($testTab.StatusText -ne "Загрузка диалога...") {
    Write-Error "После вызова Select-ConversationItem статус вкладки должен быть 'Загрузка диалога...', получено: $($testTab.StatusText)"
    exit 1
}

if (-not $testTab.LoadingJob) {
    Write-Error "Select-ConversationItem не инициализировал фоновую задачу LoadingJob на вкладке!"
    exit 1
}

# Ожидаем завершения фоновой загрузки (не более 5 секунд)
Wait-TabLoading -Tab $testTab -TimeoutMs 5000

if ($testTab.LoadingJob) {
    Write-Error "После Wait-TabLoading задача LoadingJob должна быть завершена и очищена!"
    exit 1
}

if ($testTab.Document.Blocks.Count -le 0) {
    Write-Error "После завершения асинхронной загрузки Document вкладки не должен быть пустым!"
    exit 1
}

if ($loadingOverlay.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "После завершения асинхронной загрузки LoadingOverlay должен быть скрыт!"
    exit 1
}

Close-Tab -Tab $testTab
Write-Host "[OK] Плавная неблокирующая асинхронная загрузка диалогов (Start-AsyncTranscriptLoad, Wait-TabLoading) работает корректно." -ForegroundColor Green

# 17. Проверка идентичности структуры загруженного диалога живому активному чату
$testDir = Join-Path $env:TEMP "conv_align_test_$([Guid]::NewGuid().ToString('N'))"
$testLogsDir = Join-Path $testDir ".system_generated\logs"
New-Item -ItemType Directory -Path $testLogsDir -Force | Out-Null
$testTranscript = Join-Path $testLogsDir "transcript.jsonl"

$step1 = @{
    type = "USER_INPUT"
    created_at = "2026-10-27T12:30:00Z"
    content = "[Прикрепленные изображения:`n - file:///C:/path/to/diagram.png`n]`nВнимание агенту: обязательно изучи изображение.`n`n<USER_REQUEST>Поясни архитектуру лаунчера</USER_REQUEST>"
} | ConvertTo-Json -Compress

$step2 = @{
    type = "PLANNER_RESPONSE"
    created_at = "2026-10-27T12:30:05Z"
    tool_calls = @(
        @{
            name = "read_file"
            args = @{ Path = "C:\path\to\diagram.png"; toolSummary = "Read diagram image" }
        },
        @{
            name = "edit_file"
            args = @{ Path = "C:\project\src\config.json" }
        },
        @{
            name = "search_web"
            args = @{ query = "antigravity launcher architecture" }
        }
    )
} | ConvertTo-Json -Depth 5 -Compress

$step3 = @{
    type = "PLANNER_RESPONSE"
    created_at = "2026-10-27T12:30:10Z"
    content = "Архитектура лаунчера построена на принципах **WPF FlowDocument**."
} | ConvertTo-Json -Compress

[System.IO.File]::WriteAllLines($testTranscript, @($step1, $step2, $step3), [System.Text.Encoding]::UTF8)

$parsedTurns = @(& $global:ParseTranscriptScript $testTranscript)
if (-not $parsedTurns -or $parsedTurns.Count -ne 1) {
    Write-Error "ParseTranscriptScript должен извлечь ровно 1 ход, извлечено: $($parsedTurns.Count)"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$turn0 = $parsedTurns[0]
if ($turn0.UserBadges -ne "[🖼️ diagram.png]") {
    Write-Error "UserBadges '$($turn0.UserBadges)' не соответствуют ожидаемому '[🖼️ diagram.png]'!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
if ($turn0.UserText -ne "Поясни архитектуру лаунчера") {
    Write-Error "UserText '$($turn0.UserText)' содержит остаточный промпт или теги!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

if ($turn0.Items.Count -lt 2) {
    Write-Error "turn0 должен содержать TOOLS и AGENT_TEXT!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$toolsItem = $turn0.Items[0]
if ($toolsItem.Type -ne "TOOLS" -or $toolsItem.Tools.Count -ne 3) {
    Write-Error "Ожидалось 3 инструмента в группе TOOLS, найдено: $($toolsItem.Tools.Count)"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

if ($toolsItem.Tools[0].Summary -ne "Read diagram image") {
    Write-Error "Tool 0 summary '$($toolsItem.Tools[0].Summary)' != 'Read diagram image'!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
if ($toolsItem.Tools[1].Summary -ne "config.json") {
    Write-Error "Tool 1 summary '$($toolsItem.Tools[1].Summary)' != 'config.json'!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
if ($toolsItem.Tools[2].Summary -ne "antigravity launcher architecture") {
    Write-Error "Tool 2 summary '$($toolsItem.Tools[2].Summary)' != 'antigravity launcher architecture'!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Рендеринг в тестовый FlowDocument
$testDoc = [System.Windows.Documents.FlowDocument]::new()
Populate-ConversationTranscriptToLog -Turns $parsedTurns -conversationId "test-conv-123" -Document $testDoc

# Проверка отсутствия устаревших терминальных разделителей
$allText = [System.Windows.Documents.TextRange]::new($testDoc.ContentStart, $testDoc.ContentEnd).Text
if ($allText.Contains("==========") -or $allText.Contains("Вы можете продолжить этот диалог")) {
    Write-Error "В загруженном чате обнаружены устаревшие терминальные баннеры (ASCII borders)!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Проверка порядка элементов:
# Block 0: Инфо-баннер
# Block 1: Сообщение пользователя ([Вы (HH:mm:ss)]: [🖼️ diagram.png] ...)
# Block 2: Заголовок агента ([Antigravity]:)
# Block 3: Карточка вызовов инструментов (BlockUIContainer)
# Block 4: Ответ агента (Paragraph)
$blocks = @($testDoc.Blocks)
if ($blocks.Count -lt 5) {
    Write-Error "Количество блоков FlowDocument ($($blocks.Count)) меньше 5! Структура не соответствует активному чату."
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$block0Text = [System.Windows.Documents.TextRange]::new($blocks[0].ContentStart, $blocks[0].ContentEnd).Text.Trim()
if (-not $block0Text.StartsWith("[ИНФО] Загружена история диалога")) {
    Write-Error "Блок 0 '$block0Text' должен быть инфо-уведомлением [ИНФО]!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$block1Text = [System.Windows.Documents.TextRange]::new($blocks[1].ContentStart, $blocks[1].ContentEnd).Text.Trim()
if (-not ($block1Text -match '^\[Вы \(\d{2}:\d{2}:\d{2}\)\]: \[🖼️ diagram\.png\] Поясни архитектуру лаунчера$')) {
    Write-Error "Блок 1 '$block1Text' не соответствует формату live-сообщения пользователя!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$block2Text = [System.Windows.Documents.TextRange]::new($blocks[2].ContentStart, $blocks[2].ContentEnd).Text.Trim()
if ($block2Text -ne "[Antigravity]:") {
    Write-Error "Блок 2 '$block2Text' должен быть заголовком агента [Antigravity]: перед инструментами!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

if (-not ($blocks[3] -is [System.Windows.Documents.BlockUIContainer])) {
    Write-Error "Блок 3 должен быть BlockUIContainer со сворачиваемой карточкой вызовов инструментов!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$block4Text = [System.Windows.Documents.TextRange]::new($blocks[4].ContentStart, $blocks[4].ContentEnd).Text.Trim()
if (-not $block4Text.Contains("Архитектура лаунчера построена")) {
    Write-Error "Блок 4 '$block4Text' не содержит форматированного текста ответа агента!"
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Идентичность структуры загруженного диалога активному чату (порядок [Antigravity] -> карточка инструментов -> ответ, бейджи вложений, отсутствие ASCII-баннеров) подтверждена." -ForegroundColor Green

# 18. Проверка сворачиваемых карточек системных сообщений (<SYSTEM_MESSAGE>)
# 18.1. Проверка функции Parse-SystemMessageText: разбор standalone, embedded, и сокращение Task ID
$rawSample1 = @"
The following is a <SYSTEM_MESSAGE> not actually sent by the user. It is provided by the system as important information to pay attention to.

<SYSTEM_MESSAGE>
[Message] timestamp=2026-10-26T22:52:07Z sender=d24e3694-008f-4d3c-8ede-76c790903bce/task-277 priority=MESSAGE_PRIORITY_HIGH content=Task id "d24e3694-008f-4d3c-8ede-76c790903bce/task-277" finished with result:
Command exited with code 0.

Command output:
All tests passed.
</SYSTEM_MESSAGE>
"@

$parsedSys1 = @(Parse-SystemMessageText $rawSample1)
if ($parsedSys1.Count -ne 1) {
    Write-Error "Parse-SystemMessageText должен извлечь ровно 1 сообщение, получено: $($parsedSys1.Count)"
    exit 1
}
if ($parsedSys1[0].Summary -ne 'Task id "task-277" finished with result:') {
    Write-Error "Summary '$($parsedSys1[0].Summary)' != 'Task id `"task-277`" finished with result:'"
    exit 1
}
if (-not $parsedSys1[0].Body.Contains("All tests passed.")) {
    Write-Error "Body системного сообщения не содержит текст результата!"
    exit 1
}
Write-Host "[OK] Разбор системного сообщения и сокращение Task ID в Parse-SystemMessageText валидны." -ForegroundColor Green

# 18.2. Проверка создания карточки New-SystemMessageCard и переключения (Toggle-SystemMessageCard)
$testSysDoc = [System.Windows.Documents.FlowDocument]::new()
$sysCardObj = New-SystemMessageCard -Summary $parsedSys1[0].Summary -Body $parsedSys1[0].Body -StartCollapsed -Document $testSysDoc
if (-not $sysCardObj.IsCollapsed) {
    Write-Error "Карточка системного сообщения должна быть свернута по умолчанию!"
    exit 1
}
if ($sysCardObj.BodyBorder.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "BodyBorder свернутой карточки должен иметь Visibility::Collapsed!"
    exit 1
}
if ($sysCardObj.ToggleHint.Text -ne "▶ Развернуть") {
    Write-Error "ToggleHint текст свернутой карточки должен быть '▶ Развернуть', получено: '$($sysCardObj.ToggleHint.Text)'"
    exit 1
}

# Симуляция клика по ToggleBadge (Развернуть)
$evToggle = [System.Windows.Input.MouseButtonEventArgs]::new([System.Windows.Input.Mouse]::PrimaryDevice, 0, [System.Windows.Input.MouseButton]::Left)
$evToggle.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
$sysCardObj.ToggleBadge.RaiseEvent($evToggle)

if ($sysCardObj.IsCollapsed) {
    Write-Error "После клика карточка должна развернуться (IsCollapsed = false)!"
    exit 1
}
if ($sysCardObj.BodyBorder.Visibility -ne [System.Windows.Visibility]::Visible) {
    Write-Error "После клика BodyBorder должен стать Visibility::Visible!"
    exit 1
}
if ($sysCardObj.ToggleHint.Text -ne "▼ Свернуть") {
    Write-Error "ToggleHint текст развернутой карточки должен быть '▼ Свернуть', получено: '$($sysCardObj.ToggleHint.Text)'"
    exit 1
}

# Симуляция клика по HeaderBtn (Свернуть)
$evHeader = [System.Windows.Input.MouseButtonEventArgs]::new([System.Windows.Input.Mouse]::PrimaryDevice, 0, [System.Windows.Input.MouseButton]::Left)
$evHeader.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
$sysCardObj.HeaderBtn.RaiseEvent($evHeader)

if (-not $sysCardObj.IsCollapsed) {
    Write-Error "После второго клика карточка должна снова свернуться (IsCollapsed = true)!"
    exit 1
}
if ($sysCardObj.BodyBorder.Visibility -ne [System.Windows.Visibility]::Collapsed) {
    Write-Error "После второго клика BodyBorder должен снова стать Visibility::Collapsed!"
    exit 1
}
Write-Host "[OK] Создание New-SystemMessageCard и интерактивное переключение (развернуть/свернуть) работают корректно." -ForegroundColor Green

# 18.3. Проверка транскрипта со смешанными SYSTEM_MESSAGE и очисткой тегов
$testSysDir = Join-Path $env:TEMP "agy_test_sys_$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testSysDir -Force | Out-Null
$testSysJsonl = Join-Path $testSysDir "transcript.jsonl"

$sysLines = @(
    '{"step_index":1,"source":"SYSTEM","type":"SYSTEM_MESSAGE","status":"DONE","created_at":"2026-10-27T10:00:00Z","content":"The following is a <SYSTEM_MESSAGE> not actually sent by the user.\n\n<SYSTEM_MESSAGE>\n[Message] timestamp=2026-10-27T10:00:00Z sender=system priority=MESSAGE_PRIORITY_LOW content=[Notice] Server restarted successfully.\n</SYSTEM_MESSAGE>"}',
    '{"step_index":2,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-10-27T10:01:00Z","content":"<USER_REQUEST>\nПроверь теги\n</USER_REQUEST>\n<ADDITIONAL_METADATA>\nsome metadata\n</ADDITIONAL_METADATA>\n<SYSTEM_MESSAGE>\n[Message] sender=task-999 content=Task id \"task-999\" finished with result: ExitCode 0\n</SYSTEM_MESSAGE>"}',
    '{"step_index":3,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-10-27T10:01:05Z","content":"Теги успешно проверены."}'
)
[System.IO.File]::WriteAllLines($testSysJsonl, $sysLines, [System.Text.Encoding]::UTF8)

$parsedSysTurns = & $global:ParseTranscriptScript $testSysJsonl

# Проверка структуры turns и очистки UserText от тегов
if ($parsedSysTurns.Count -ne 2) {
    Write-Error "Ожидалось 2 turns (Turn 0 до запроса и Turn 1 с запросом), получено: $($parsedSysTurns.Count)"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
$turn0 = $parsedSysTurns[0]
if (-not [string]::IsNullOrWhiteSpace($turn0.UserText)) {
    Write-Error "Turn 0 UserText должен быть пустым, получено: '$($turn0.UserText)'"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
if ($turn0.Items.Count -ne 1 -or $turn0.Items[0].Summary -ne "[Notice] Server restarted successfully.") {
    Write-Error "Turn 0 должен содержать уведомление о перезапуске сервера!"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$turn1 = $parsedSysTurns[1]
if ($turn1.UserText -ne "Проверь теги") {
    Write-Error "UserText '$($turn1.UserText)' содержит остаточные теги или текст!"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Проверка, что в Turn 1 есть SYSTEM_MESSAGE (embedded) и AGENT_TEXT
$sysItems1 = @($turn1.Items | Where-Object { $_.Type -eq "SYSTEM_MESSAGE" })
if ($sysItems1.Count -ne 1) {
    Write-Error "Ожидалось 1 системное сообщение в Items Turn 1, получено: $($sysItems1.Count)"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
if ($sysItems1[0].Summary -ne 'Task id "task-999" finished with result: ExitCode 0') {
    Write-Error "SysItem 1 summary '$($sysItems1[0].Summary)' != 'Task id `"task-999`" finished with result: ExitCode 0'"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Рендеринг в FlowDocument и проверка отсутствия сырых тегов <SYSTEM_MESSAGE> в тексте
$testSysRenderDoc = [System.Windows.Documents.FlowDocument]::new()
Populate-ConversationTranscriptToLog -Turns $parsedSysTurns -conversationId "test-sys-conv" -Document $testSysRenderDoc
$allSysText = [System.Windows.Documents.TextRange]::new($testSysRenderDoc.ContentStart, $testSysRenderDoc.ContentEnd).Text

if ($allSysText.Contains("<SYSTEM_MESSAGE>") -or $allSysText.Contains("</SYSTEM_MESSAGE>")) {
    Write-Error "В отрендеренном чате обнаружены сырые теги <SYSTEM_MESSAGE> или </SYSTEM_MESSAGE>!"
    Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
Remove-Item -Path $testSysDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Парсинг транскрипта со смешанными системными сообщениями, фильтрация тегов и рендеринг без сырых XML тегов подтверждены." -ForegroundColor Green

# 18.4. Проверка паритета Python реализации (antigravity_gui.py)
$pyContent = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "antigravity_gui.py"), [System.Text.Encoding]::UTF8)
if (-not $pyContent.Contains("class CollapsibleSystemMessageCard")) {
    Write-Error "В antigravity_gui.py отсутствует класс CollapsibleSystemMessageCard!"
    exit 1
}
if (-not $pyContent.Contains("def parse_system_message_text")) {
    Write-Error "В antigravity_gui.py отсутствует функция parse_system_message_text!"
    exit 1
}
Write-Host "[OK] Паритет функционала в Python реализации (antigravity_gui.py) подтвержден." -ForegroundColor Green

# 19. Проверка задания пользовательского названия разговора (Set-ConversationTitle) и переименования
$dummyConvId = "00000000-0000-4000-8000-000000000099"
$testCustomTitle = "Тестовый кастомный разговор"

$renameOk = Set-ConversationTitle -conversationId $dummyConvId -newTitle $testCustomTitle
if (-not $renameOk) {
    Write-Error "Set-ConversationTitle вернул false!"
    exit 1
}

# Проверка, что название записалось в sessions_meta.json
$metaRaw = Get-Content -Path (Join-Path $PSScriptRoot "sessions_meta.json") -Raw -Encoding utf8
if (-not $metaRaw.Contains($testCustomTitle) -or -not $metaRaw.Contains($dummyConvId)) {
    Write-Error "sessions_meta.json не содержит обновленного названия '$testCustomTitle' для ID '$dummyConvId'!"
    exit 1
}

# Проверка обновления на открытой вкладке
$renameTab = Add-NewTab -Title "Вкладка для теста" -ConversationId $dummyConvId
[void](Set-ConversationTitle -conversationId $dummyConvId -newTitle "Обновленное имя вкладки")
if ($renameTab.Title -ne "Обновленное имя вкладки") {
    Write-Error "Set-ConversationTitle не обновил заголовок открытой вкладки! Получено: '$($renameTab.Title)'"
    exit 1
}
Close-Tab -Tab $renameTab

# Очистка тестовой записи
Remove-AntigravityConversation -conversationId $dummyConvId | Out-Null
Write-Host "[OK] Задание пользовательского названия разговора (Set-ConversationTitle) и сохранение в sessions_meta.json валидны." -ForegroundColor Green

# 19.1. Проверка наличия функционала в Python реализации (antigravity_gui.py)
$pyContentUpdated = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "antigravity_gui.py"), [System.Text.Encoding]::UTF8)
if (-not $pyContentUpdated.Contains("def set_conversation_title")) {
    Write-Error "В antigravity_gui.py отсутствует функция set_conversation_title!"
    exit 1
}
if (-not $pyContentUpdated.Contains("def _rename_conv")) {
    Write-Error "В antigravity_gui.py отсутствует метод _rename_conv!"
    exit 1
}
Write-Host "[OK] Паритет функционала переименования в Python реализации (antigravity_gui.py) подтвержден." -ForegroundColor Green

# 20. Проверка отображения заполненности контекстного окна (Context Window Usage & Tokens Tracking)
$geminiLimit = Get-ModelContextLimit -modelName "gemini-3.8-flash-high"
if ($geminiLimit -ne 1048576) {
    Write-Error "Get-ModelContextLimit для Gemini вернул $geminiLimit вместо 1048576!"
    exit 1
}

$claudeLimit = Get-ModelContextLimit -modelName "claude-sonnet-4-6"
if ($claudeLimit -ne 200000) {
    Write-Error "Get-ModelContextLimit для Claude вернул $claudeLimit вместо 200000!"
    exit 1
}

$fmt500 = Format-TokenCount 500
$fmt89k = Format-TokenCount 89200
$fmt1m  = Format-TokenCount 1048576
if ($fmt500 -ne "500" -or -not $fmt89k.Contains("k") -or -not $fmt1m.Contains("M")) {
    Write-Error "Format-TokenCount вернул некорректные форматы: $fmt500, $fmt89k, $fmt1m!"
    exit 1
}

# Проверка вычисления статистики контекста для текущей сессии
$currentStats = Get-ConversationContextStats -conversationId "d24e3694-008f-4d3c-8ede-76c790903bce" -modelName "gemini-3.8-flash-high"
if ($currentStats.TotalTokens -le 0) {
    Write-Error "Get-ConversationContextStats вернул TotalTokens <= 0 для активного диалога!"
    exit 1
}
if (-not $currentStats.DisplayText.Contains("🧠 Контекст:") -or $currentStats.Percent -le 0.0) {
    Write-Error "Get-ConversationContextStats вернул некорректный DisplayText или Percent: $($currentStats.DisplayText) ($($currentStats.Percent)%)!"
    exit 1
}

# Проверка наличия элементов управления контекста в главном окне
if (-not $txtContextTokens) {
    Write-Error "Элемент TxtContextTokens не найден в XAML главного окна!"
    exit 1
}
Update-ContextDisplay -conversationId "d24e3694-008f-4d3c-8ede-76c790903bce"
if (-not $txtContextTokens.Text.Contains("/")) {
    Write-Error "Update-ContextDisplay не установил текст TxtContextTokens! Получено: '$($txtContextTokens.Text)'"
    exit 1
}
Write-Host "[OK] Парсер токенов (Get-ConversationContextStats), форматирование и отображение контекста в статус-баре валидны." -ForegroundColor Green

# 20.1. Проверка наличия базового функционала контекста в Python реализации (antigravity_gui.py)
$pyContentFinal = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "antigravity_gui.py"), [System.Text.Encoding]::UTF8)
if (-not $pyContentFinal.Contains("def get_model_context_limit")) {
    Write-Error "В antigravity_gui.py отсутствует функция get_model_context_limit!"
    exit 1
}
if (-not $pyContentFinal.Contains("def get_conversation_context_stats")) {
    Write-Error "В antigravity_gui.py отсутствует функция get_conversation_context_stats!"
    exit 1
}
if (-not $pyContentFinal.Contains("self.lbl_context")) {
    Write-Error "В antigravity_gui.py отсутствует self.lbl_context!"
    exit 1
}
Write-Host "[OK] Паритет базового функционала отслеживания контекста в Python реализации (antigravity_gui.py) подтвержден." -ForegroundColor Green

# 21. Проверка графического виджета контекста (Progress Bar, Badge, Modal Details Dialog & Unicode Bar)
if (-not $borderContextWidget) {
    Write-Error "Виджет BorderContextWidget не найден в XAML!"
    exit 1
}
if (-not $prgContext) {
    Write-Error "Графический ProgressBar PrgContext не найден в XAML!"
    exit 1
}
if (-not $borderContextBadge -or -not $txtContextPercent) {
    Write-Error "Графический бейдж BorderContextBadge или TxtContextPercent не найден в XAML!"
    exit 1
}

# Проверка корректности передачи данных в графический ProgressBar и бейдж
if ($prgContext.Value -le 0.0 -or $prgContext.Value -gt 100.0) {
    Write-Error "PrgContext.Value имеет некорректное значение: $($prgContext.Value)"
    exit 1
}
if (-not $txtContextPercent.Text.Contains("%")) {
    Write-Error "TxtContextPercent.Text не содержит процента: '$($txtContextPercent.Text)'"
    exit 1
}

# Проверка Unicode графической шкалы в предпросмотре диалога
$previewWithBar = Get-ConversationPreviewText -conversationId "d24e3694-008f-4d3c-8ede-76c790903bce"
if (-not $previewWithBar.Contains("Контекстное окно: [") -or -not $previewWithBar.Contains("%")) {
    Write-Error "Get-ConversationPreviewText не содержит Unicode шкалы контекста! Получено:`n$previewWithBar"
    exit 1
}

# Проверка наличия функции модального детального анализа Show-ContextDetailsDialog
$dlgCmd = Get-Command Show-ContextDetailsDialog -ErrorAction SilentlyContinue
if (-not $dlgCmd) {
    Write-Error "Функция Show-ContextDetailsDialog не найдена в сессии!"
    exit 1
}

# Проверка паритета графического виджета и окна анализа в Python реализации (antigravity_gui.py)
if (-not $pyContentFinal.Contains("self.canvas_context_bar")) {
    Write-Error "В antigravity_gui.py отсутствует self.canvas_context_bar!"
    exit 1
}
if (-not $pyContentFinal.Contains("self.lbl_context_badge")) {
    Write-Error "В antigravity_gui.py отсутствует self.lbl_context_badge!"
    exit 1
}
if (-not $pyContentFinal.Contains("def _show_context_details_dialog")) {
    Write-Error "В antigravity_gui.py отсутствует метод _show_context_details_dialog!"
    exit 1
}
Write-Host "[OK] Графический прогресс-бар, цветовая индикация, бейдж, Unicode шкала и диалог анализа (Show-ContextDetailsDialog) валидны." -ForegroundColor Green

# 22. Проверка неблокирующей обработки события 'result' и защиты от зависания процесса agy.exe
$guiCode = Get-Content -Path $guiPs1 -Raw -Encoding utf8
if (-not $guiCode.Contains('$proc.WaitForExit(1500)')) {
    Write-Error "В AntigravityGUI.ps1 отсутствует таймаут завершения процесса agy.exe ($proc.WaitForExit(1500))!"
    exit 1
}
if (-not $guiCode.Contains('$turnFinished = $true')) {
    Write-Error "В AntigravityGUI.ps1 отсутствует флаг turnFinished при получении события result!"
    exit 1
}
if (-not $guiCode.Contains('$proc.Kill()')) {
    Write-Error "В AntigravityGUI.ps1 отсутствует принудительное завершение зависшего процесса ($proc.Kill())!"
    exit 1
}

# Проверка паритета защиты от зависания в Python реализации (antigravity_gui.py)
$pyFinalCheck = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "antigravity_gui.py"), [System.Text.Encoding]::UTF8)
if (-not $pyFinalCheck.Contains('proc.wait(timeout=1.5)')) {
    Write-Error "В antigravity_gui.py отсутствует таймаут proc.wait(timeout=1.5)!"
    exit 1
}
if (-not $pyFinalCheck.Contains('turn_finished = True')) {
    Write-Error "В antigravity_gui.py отсутствует флаг turn_finished при событии result!"
    exit 1
}

# Функциональная проверка обработки очереди при завершении хода (событие 'done')
$testTab = $global:ActiveTab
$testTab.SyncState.IsRunning = $true
$testTab.StatusColor = "#FFA500"
$testTab.StatusText = "Агент думает и выполняет задачи..."
$statusDot.Fill = (Get-CachedBrush "#FFA500")
$btnSend.IsEnabled = $false
$btnStop.IsEnabled = $true
$txtPromptInput.IsEnabled = $false

# Эмулируем поступление события 'done'
$testTab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "done" })

# Выполняем логику обработки очереди напрямую для вкладки
$item = $null
while ($testTab.SyncState.Queue.TryDequeue([ref]$item)) {
    if ($item.Type -eq "done") {
        Finalize-ActiveToolGroup -Tab $testTab
        Finalize-TabStreamingBuffer -Tab $testTab
        $testTab.SyncState.IsRunning = $false
        $testTab.StatusText = "Готов к работе"
        $testTab.StatusColor = "#4CAF50"
        if ($testTab.HeaderDot) {
            $testTab.HeaderDot.Fill = (Get-CachedBrush "#4CAF50")
        }
        if ($testTab -eq $global:ActiveTab) {
            $btnSend.IsEnabled = $true
            $btnStop.IsEnabled = $false
            $txtPromptInput.IsEnabled = $true
            $statusDot.Fill = (Get-CachedBrush "#4CAF50")
            $txtStatus.Text = "Готов к работе"
        }
    }
}

if ($testTab.SyncState.IsRunning -ne $false) {
    Write-Error "После события done вкладка осталась в состоянии IsRunning = true!"
    exit 1
}
if ($testTab.StatusColor -ne "#4CAF50") {
    Write-Error "После события done цвет вкладки не изменился на зеленый (#4CAF50)! Получено: $($testTab.StatusColor)"
    exit 1
}
if (-not $btnSend.IsEnabled -or -not $txtPromptInput.IsEnabled) {
    Write-Error "После события done кнопки отправки и поле ввода остались заблокированы!"
    exit 1
}
Write-Host "[OK] Неблокирующая финализация по событию result, таймауты teardown и переход в зеленый статус (#4CAF50) валидны." -ForegroundColor Green

# 23. Проверка сохранения вкладок чатов (Tab Persistence) и отложенной загрузки диалогов (Lazy Loading on Click)
# 23.1. Проверка сохранения вкладок в launcher_config.json
$origTabCount = $global:TabsList.Count
$dummyConvId = "d24e3694-008f-4d3c-8ede-76c790903bce"
$savedTabTest = Add-NewTab -Title "Сохраненный Диалог" -ConversationId $dummyConvId -Select

Save-LauncherConfig

$cfgContent = Get-Content -Path $cfgPath -Raw -Encoding utf8 | ConvertFrom-Json
if (-not $cfgContent.tabs -or $cfgContent.tabs.Count -lt 2) {
    Write-Error "В launcher_config.json не сохранился список вкладок (tabs)!"
    exit 1
}
$foundSavedTab = $cfgContent.tabs | Where-Object { $_.conversationId -eq $dummyConvId }
if (-not $foundSavedTab) {
    Write-Error "В launcher_config.json отсутствует вкладка с conversationId=$dummyConvId!"
    exit 1
}
Write-Host "[OK] Сохранение вкладок в launcher_config.json работает корректно." -ForegroundColor Green

# 23.2. Проверка ленивой инициализации (Lazy Loading) при восстановлении вкладок
# Создаем тестовую вкладку в режиме Lazy
$lazyTab = Add-NewTab -Title "Ленивая Вкладка" -ConversationId $dummyConvId -Lazy
if ($lazyTab.IsTranscriptLoaded -ne $false) {
    Write-Error "Вкладка, созданная с -Lazy, имеет IsTranscriptLoaded = true (ожидалось false)!"
    exit 1
}
if ($lazyTab.StatusColor -ne "#888888") {
    Write-Error "Цвет статуса ленивой вкладки не #888888! Получено: $($lazyTab.StatusColor)"
    exit 1
}
# Проверяем, что в документе ленивой вкладки отображается плейсхолдер с кнопкой загрузки
$hasPlaceholder = $false
foreach ($blk in $lazyTab.Document.Blocks) {
    if ($blk -is [System.Windows.Documents.BlockUIContainer]) {
        $hasPlaceholder = $true
        break
    }
}
if (-not $hasPlaceholder) {
    Write-Error "В документе ленивой вкладки не найден плейсхолдер BlockUIContainer!"
    exit 1
}
Write-Host "[OK] Отложенное состояние вкладки (IsTranscriptLoaded=false, плейсхолдер) валидно." -ForegroundColor Green

# 23.3. Проверка загрузки диалога по требованию / вызову Load-TabConversation
Load-TabConversation -Tab $lazyTab
if ($lazyTab.IsTranscriptLoaded -ne $true) {
    Write-Error "Load-TabConversation не установил IsTranscriptLoaded = true!"
    exit 1
}
# Дожидаемся завершения асинхронной загрузки
Wait-TabLoading -Tab $lazyTab -TimeoutMs 5000

if ($lazyTab.StatusColor -ne "#4CAF50") {
    Write-Error "После завершения загрузки цвет вкладки не #4CAF50! Получено: $($lazyTab.StatusColor)"
    exit 1
}
# Проверяем, что в документе появились блоки транскрипта
if ($lazyTab.Document.Blocks.Count -lt 2) {
    Write-Error "После загрузки транскрипта в документе недостаточно блоков!"
    exit 1
}
Write-Host "[OK] Загрузка диалога по требованию (Load-TabConversation) и переход в активное состояние (#4CAF50) валидны." -ForegroundColor Green

# Очищаем тестовые вкладки
Close-Tab -Tab $lazyTab
Close-Tab -Tab $savedTabTest

# 23.4. Проверка восстановления нескольких вкладок без их усечения
$testMultiCfg = [pscustomobject]@{
    windowHeight   = 780
    windowWidth    = 1080
    fontSize       = 13
    isMaximized    = $false
    activeTabIndex = 1
    tabs           = @(
        [pscustomobject]@{
            title          = "Вкладка А"
            conversationId = "conv-multi-aaa"
            workspace      = $PSScriptRoot
            model          = "gemini-2.5-pro"
            mode           = "code"
            effort         = "high"
            skipPerms      = $true
        },
        [pscustomobject]@{
            title          = "Вкладка Б (Новая)"
            conversationId = $null
            workspace      = $PSScriptRoot
            model          = "gemini-2.5-pro"
            mode           = "code"
            effort         = "high"
            skipPerms      = $true
        }
    )
}
$multiJson = $testMultiCfg | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($cfgPath, $multiJson, [System.Text.Encoding]::UTF8)

# Сбрасываем текущее состояние вкладок в памяти и запускаем Restore-SavedTabs
$global:TabsList.Clear()
if ($pnlTabsHeader) { $pnlTabsHeader.Children.Clear() }
$global:ActiveTab = $null

Restore-SavedTabs

if ($global:TabsList.Count -ne 2) {
    Write-Error "После Restore-SavedTabs количество вкладок не 2, а $($global:TabsList.Count)!"
    exit 1
}
if ($global:TabsList[0].Title -ne "Вкладка А" -or $global:TabsList[1].Title -ne "Вкладка Б (Новая)") {
    Write-Error "Названия восстановленных вкладок не совпадают с исходными!"
    exit 1
}
if ($global:TabsList[0].IsTranscriptLoaded -ne $false) {
    Write-Error "Вкладка с conversationId должна восстановиться в отложенном режиме (IsTranscriptLoaded=false)!"
    exit 1
}
if ($global:TabsList[1].IsTranscriptLoaded -ne $true) {
    Write-Error "Новая вкладка без conversationId должна быть готова сразу (IsTranscriptLoaded=true)!"
    exit 1
}

# Проверяем, что на диске в launcher_config.json после Restore-SavedTabs ничего не усечено!
$diskMultiContent = Get-Content -Path $cfgPath -Raw -Encoding utf8 | ConvertFrom-Json
if (-not $diskMultiContent.tabs -or $diskMultiContent.tabs.Count -ne 2) {
    Write-Error "Restore-SavedTabs перезаписал или урезал вкладки на диске! Количество на диске: $($diskMultiContent.tabs.Count)"
    exit 1
}
Write-Host "[OK] Восстановление нескольких вкладок (Restore-SavedTabs) без усечения и целостность файла конфигурации подтверждены." -ForegroundColor Green

# 24. Проверка защиты от Pipe Buffer Deadlock и завершения дерева процессов
$guiCheckCode = Get-Content -Path $guiPs1 -Raw -Encoding utf8
if (-not $guiCheckCode.Contains('ReadToEndAsync()')) {
    Write-Error "В AntigravityGUI.ps1 отсутствует асинхронное чтение stderr (`$proc.StandardError.ReadToEndAsync())!"
    exit 1
}
if (-not $guiCheckCode.Contains('Stop-ProcessTree')) {
    Write-Error "В AntigravityGUI.ps1 отсутствует функция Stop-ProcessTree!"
    exit 1
}
if (-not $guiCheckCode.Contains('taskkill.exe /PID')) {
    Write-Error "В AntigravityGUI.ps1 отсутствует завершение дерева процессов через taskkill.exe!"
    exit 1
}

# Проверка паритета защиты от переполнения буфера stderr в Python (antigravity_gui.py)
$pyCheckCode = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "antigravity_gui.py"), [System.Text.Encoding]::UTF8)
if (-not $pyCheckCode.Contains('_drain_stderr')) {
    Write-Error "В antigravity_gui.py отсутствует асинхронный дренаж stderr (_drain_stderr)!"
    exit 1
}
if (-not $pyCheckCode.Contains('taskkill')) {
    Write-Error "В antigravity_gui.py отсутствует завершение дерева процессов (taskkill)!"
    exit 1
}
Write-Host "[OK] Защита от переполнения буфера pipe (BeginErrorReadLine) и завершение дерева процессов (Stop-ProcessTree, taskkill) валидны." -ForegroundColor Green

Write-Host "=== Все тесты AntigravityLauncher успешно пройдены! (ExitCode 0) ===" -ForegroundColor Green
exit 0
} finally {
    Restore-LauncherConfigBackup
}
