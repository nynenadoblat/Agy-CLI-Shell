# Игровая тема «Пустошь» (в духе Kenshi), как в клиенте ClaudeWin. Тему выбирает кнопка «🎨 Тема» в строке состояния.
# Выбор лежит в launcher_config.json в ключе theme: dark - обычная тёмная тема, game - игровая.
#
# В игровой теме два материала.
# Бумага: светлые потёртые бежевые панели с тёмным текстом. Из бумаги сделаны чат, поле ввода и диалоговые окна.
# Железо: тёмно-серые плашки в ржавой раме. Из железа сделаны верхняя панель, вкладки, строка состояния, кнопки и меню.
#
# Лаунчер нарисован в тёмных цветах. Convert-ThemeColor переводит каждый тёмный цвет в цвет бумаги или железа.
# В тёмной теме фон и рамки тёмные, а текст и значки светлые. Поэтому функция отличает фон от текста по яркости цвета.
# Бумага переворачивает яркость: тёмный фон становится светлым, светлый текст становится тёмным.
# Железо оставляет яркость и меняет оттенок: синий акцент становится выцветшим хаки, зелёный - оливой, красный - кровью.
#
# Цвета разметки окон переводит Convert-ThemeXaml. Цвета из кода переводит Get-CachedBrush в AntigravityGUI.ps1.
# Тема включается при запуске лаунчера: смена темы перезапускает окно.

$script:ThemeDir = Join-Path $PSScriptRoot "theme"

# Тема из файла настроек. Путь к файлу тот же, что у AntigravityGUI.ps1 ($configFilePath).
# Файла настроек может не быть (первый запуск): тогда тема тёмная.
# Файл бывает повреждён (процесс убили во время записи). Тогда тема тоже тёмная, а причину AntigravityGUI.ps1
# пишет в perf.log ($global:LauncherThemeReadError): Write-PerfLog к этому моменту ещё не объявлен.
function Read-LauncherThemeName {
    $path = if ($env:ANTIGRAVITY_CONFIG_PATH) { $env:ANTIGRAVITY_CONFIG_PATH } else { Join-Path (Join-Path $env:APPDATA "AntigravityLauncher") "launcher_config.json" }
    if (-not (Test-Path -LiteralPath $path)) { return 'dark' }
    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding utf8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return 'dark' }
        $cfg = $raw | ConvertFrom-Json
    } catch {
        $global:LauncherThemeReadError = "GameTheme: не удалось прочитать тему из '$path': $($_.Exception.Message)"
        return 'dark'
    }
    if ($cfg.PSObject.Properties['theme'] -and $cfg.theme -eq 'game') { return 'game' }
    return 'dark'
}

$global:LauncherThemeReadError = $null
$global:LauncherTheme = Read-LauncherThemeName
$global:ThemeColorCache = @{}

function ConvertTo-ThemeHls([double]$r, [double]$g, [double]$b) {
    $max = [Math]::Max($r, [Math]::Max($g, $b))
    $min = [Math]::Min($r, [Math]::Min($g, $b))
    $l = ($max + $min) / 2.0
    if ($max -eq $min) { return @(0.0, $l, 0.0) }
    $d = $max - $min
    $s = if ($l -gt 0.5) { $d / (2.0 - $max - $min) } else { $d / ($max + $min) }
    if ($max -eq $r) { $h = ($g - $b) / $d; if ($g -lt $b) { $h += 6.0 } }
    elseif ($max -eq $g) { $h = ($b - $r) / $d + 2.0 }
    else { $h = ($r - $g) / $d + 4.0 }
    return @(($h * 60.0), $l, $s)
}

function ConvertFrom-ThemeHue([double]$p, [double]$q, [double]$t) {
    if ($t -lt 0) { $t += 1.0 }
    if ($t -gt 1) { $t -= 1.0 }
    if ($t -lt 1.0 / 6.0) { return $p + ($q - $p) * 6.0 * $t }
    if ($t -lt 0.5) { return $q }
    if ($t -lt 2.0 / 3.0) { return $p + ($q - $p) * (2.0 / 3.0 - $t) * 6.0 }
    return $p
}

# Возвращает r, g, b от 0 до 255. Яркость и насыщенность обрезаются до 0..1.
function ConvertFrom-ThemeHls([double]$h, [double]$l, [double]$s) {
    $l = [Math]::Max(0.0, [Math]::Min(1.0, $l))
    $s = [Math]::Max(0.0, [Math]::Min(1.0, $s))
    if ($s -eq 0) { $r = $l; $g = $l; $b = $l }
    else {
        $q = if ($l -lt 0.5) { $l * (1.0 + $s) } else { $l + $s - $l * $s }
        $p = 2.0 * $l - $q
        $hk = $h / 360.0
        $r = ConvertFrom-ThemeHue $p $q ($hk + 1.0 / 3.0)
        $g = ConvertFrom-ThemeHue $p $q $hk
        $b = ConvertFrom-ThemeHue $p $q ($hk - 1.0 / 3.0)
    }
    return @([int][Math]::Round($r * 255), [int][Math]::Round($g * 255), [int][Math]::Round($b * 255))
}

# Группа оттенка, как hue_group в tools/themes.py клиента ClaudeWin. Фиолетовый попадает в синюю группу.
function Get-ThemeHueGroup([double]$deg, [double]$s, [double]$l) {
    if ($s -lt 0.14 -or $l -lt 0.03) { return 'grey' }
    if ($deg -ge 185 -and $deg -le 265) { return 'blue' }
    if ($deg -ge 80 -and $deg -lt 185) { return 'green' }
    if ($deg -lt 15 -or $deg -gt 330) { return 'red' }
    if ($deg -lt 80) { return 'orange' }
    return 'blue'
}

# Цвет тёмной темы в цвет игровой темы. Kind: paper - бумага, metal - железо.
# В тёмной теме функция возвращает цвет как есть. Названия цветов (White, Transparent) и привязки она тоже не трогает.
function Convert-ThemeColor([string]$Color, [string]$Kind = 'paper') {
    if ($global:LauncherTheme -ne 'game') { return $Color }
    $key = "$Kind|$Color"
    if ($global:ThemeColorCache.ContainsKey($key)) { return $global:ThemeColorCache[$key] }
    if ($Color -notmatch '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') { return $Color }

    $hex = $Color.Substring(1)
    if ($hex.Length -eq 3) { $hex = -join ($hex.ToCharArray() | ForEach-Object { "$_$_" }) }
    $a = 255
    if ($hex.Length -eq 8) { $a = [Convert]::ToInt32($hex.Substring(0, 2), 16); $hex = $hex.Substring(2) }
    $hls = ConvertTo-ThemeHls ([Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0) ([Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0) ([Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0)
    $deg = $hls[0]; $l = $hls[1]; $s = $hls[2]
    $group = Get-ThemeHueGroup $deg $s $l
    # Светлый цвет в тёмной теме - это текст, значок или яркая рамка. Тёмный - фон или обычная рамка.
    $isText = $l -ge 0.45

    if ($Kind -eq 'metal') {
        $hsl = switch ($group) {
            'grey'   { if ($isText) { @(42, 0.08, ($l * 0.95)) } else { @(35, 0.06, ($l * 0.95)) } }
            'blue'   { if ($isText) { @(52, 0.38, [Math]::Max($l, 0.62)) } elseif ($l -gt 0.3) { @(52, 0.3, 0.45) } else { @(35, 0.1, ($l * 1.05)) } }
            'green'  { @(62, ($s * 0.6), ($l * 0.9)) }
            'red'    { @(3, [Math]::Min(0.62, $s), ($l * 0.9)) }
            'orange' { @(26, ($s * 0.85), $l) }
        }
    } else {
        # Бумага: яркость переворачивается. Текст не светлее 0.38, иначе на бежевом фоне он не читается.
        $flip = 0.84 - 0.78 * $l
        if ($isText) {
            $tl = [Math]::Min($flip, 0.38)
            $hsl = switch ($group) {
                'grey'   { @(30, 0.12, $tl) }
                'blue'   { @(20, [Math]::Min(0.55, $s * 0.7), $tl) }
                'green'  { @(62, [Math]::Min(0.5, $s * 0.55), $tl) }
                'red'    { @(3, [Math]::Min(0.6, $s), $tl) }
                'orange' { @(26, [Math]::Min(0.6, $s * 0.8), $tl) }
            }
        } else {
            $hsl = switch ($group) {
                'grey'   { @(40, 0.13, $flip) }
                # Яркая синяя заливка (главная кнопка, выбранный пункт) становится хаки, как главные кнопки ClaudeWin.
                'blue'   { if ($s -gt 0.5 -and $l -gt 0.25) { @(52, 0.3, $flip) } else { @(30, 0.16, $flip) } }
                'green'  { @(62, [Math]::Min(0.25, $s * 0.5), $flip) }
                'red'    { @(5, 0.25, $flip) }
                'orange' { @(35, 0.25, $flip) }
            }
        }
    }

    $rgb = ConvertFrom-ThemeHls $hsl[0] $hsl[2] $hsl[1]
    $out = if ($a -eq 255) { '#{0:X2}{1:X2}{2:X2}' -f $rgb[0], $rgb[1], $rgb[2] } else { '#{0:X2}{1:X2}{2:X2}{3:X2}' -f $a, $rgb[0], $rgb[1], $rgb[2] }
    $global:ThemeColorCache[$key] = $out
    return $out
}

# Скругление углов для блоков из кода. В игровой теме углы острые, как у пластин интерфейса игры.
# Radius - одно число или четыре: левый верхний, правый верхний, правый нижний, левый нижний.
function New-ThemeCorner([double[]]$Radius) {
    if ($global:LauncherTheme -eq 'game') { return [System.Windows.CornerRadius]::new(0) }
    if ($Radius.Count -eq 4) { return [System.Windows.CornerRadius]::new($Radius[0], $Radius[1], $Radius[2], $Radius[3]) }
    return [System.Windows.CornerRadius]::new($Radius[0])
}

# Шаблон кнопки игровой темы: плашка с острыми углами, светлым краем сверху и тенью снизу.
# Цвет плашки берётся из Background кнопки, поэтому зелёная, красная и главная кнопки остаются разными.
$script:ThemeButtonTemplate = @"
<Setter xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Property="Template">
    <Setter.Value>
        <ControlTemplate TargetType="Button">
            <Grid SnapsToDevicePixels="True">
                <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"/>
                <Border Margin="1">
                    <Border.Background>
                        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                            <GradientStop Color="#1FFFFFFF" Offset="0"/>
                            <GradientStop Color="#00FFFFFF" Offset="0.45"/>
                            <GradientStop Color="#33000000" Offset="1"/>
                        </LinearGradientBrush>
                    </Border.Background>
                </Border>
                <Border x:Name="Hover" Margin="1" Background="#22FFFFFF" Visibility="Collapsed"/>
                <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" RecognizesAccessKey="True" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Hover" Property="Visibility" Value="Visible"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter TargetName="Hover" Property="Visibility" Value="Visible"/>
                    <Setter TargetName="Hover" Property="Background" Value="#33000000"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.45"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
    </Setter.Value>
</Setter>
"@

function Convert-ThemeXamlNode([System.Xml.XmlElement]$Node, [string]$Kind) {
    $own = $Node.GetAttribute('Theme')
    if ($own) { $Kind = $own; $Node.RemoveAttribute('Theme') }
    # Кнопки - железные плашки и на бумаге, как в ClaudeWin.
    if ($Node.LocalName -eq 'Button' -or ($Node.LocalName -eq 'Style' -and $Node.GetAttribute('TargetType') -match '^(\{x:Type )?Button\}?$')) { $Kind = 'metal' }
    $isShadow = $Node.LocalName -eq 'DropShadowEffect'
    foreach ($a in @($Node.Attributes)) {
        if ($a.Value -match '^#[0-9A-Fa-f]{3,8}$') {
            # Тень и свечение на бумаге остаются тёмными: перевёрнутая светлая тень выглядела бы как грязь.
            $a.Value = if ($isShadow) { '#000000' } else { Convert-ThemeColor $a.Value $Kind }
        } elseif ($a.LocalName -eq 'CornerRadius' -and -not $a.Value.StartsWith('{')) {
            $a.Value = '0'
        }
    }
    foreach ($c in @($Node.ChildNodes)) {
        if ($c -is [System.Xml.XmlElement]) { Convert-ThemeXamlNode $c $Kind }
    }
}

# Переводит разметку окна в текущую тему и возвращает её. Kind - материал окна: metal для главного окна, paper для диалогов.
# Блок с атрибутом Theme="paper" или Theme="metal" задаёт материал себе и всему внутри. Атрибут Theme функция убирает
# в любой теме: XamlReader его не знает.
# Неявные стили окна (TextBlock, TextBox, ComboBox...) написаны под один материал. Поэтому в каждый блок Theme="paper"
# функция кладёт копию ресурсов окна, и копия переводится в цвета бумаги.
function Convert-ThemeXaml([xml]$Xaml, [string]$Kind = 'paper') {
    $root = $Xaml.DocumentElement
    $ns = $root.NamespaceURI
    if ($global:LauncherTheme -ne 'game') {
        foreach ($n in @($Xaml.SelectNodes('//*[@Theme]'))) { $n.RemoveAttribute('Theme') }
        return $Xaml
    }

    $resName = "$($root.LocalName).Resources"
    $res = $null
    foreach ($c in $root.ChildNodes) { if ($c.LocalName -eq $resName) { $res = $c } }
    if (-not $res) {
        $res = $Xaml.CreateElement($resName, $ns)
        [void]$root.PrependChild($res)
    }
    foreach ($el in @($Xaml.SelectNodes("//*[@Theme='paper']"))) {
        $elResName = "$($el.LocalName).Resources"
        $elRes = $null
        foreach ($c in $el.ChildNodes) { if ($c.LocalName -eq $elResName) { $elRes = $c } }
        if (-not $elRes) {
            $elRes = $Xaml.CreateElement($elResName, $ns)
            [void]$el.PrependChild($elRes)
        }
        foreach ($c in @($res.ChildNodes)) {
            if ($c -is [System.Xml.XmlElement]) { [void]$elRes.AppendChild($c.CloneNode($true)) }
        }
    }

    Convert-ThemeXamlNode $root $Kind

    # Шаблон плашки - во все неявные стили кнопок. В окне без такого стиля функция его создаёт.
    $styles = @($Xaml.GetElementsByTagName('Style', $ns) | Where-Object { $_.GetAttribute('TargetType') -match '^(\{x:Type )?Button\}?$' -and -not $_.HasAttribute('Key', 'http://schemas.microsoft.com/winfx/2006/xaml') })
    if ($styles.Count -eq 0) {
        $st = $Xaml.CreateElement('Style', $ns)
        $st.SetAttribute('TargetType', 'Button')
        [void]$res.AppendChild($st)
        $styles = @($st)
    }
    $frag = [xml]$script:ThemeButtonTemplate
    foreach ($st in $styles) {
        $hasTemplate = @($st.ChildNodes | Where-Object { $_.LocalName -eq 'Setter' -and $_.GetAttribute('Property') -eq 'Template' }).Count -gt 0
        if (-not $hasTemplate) { [void]$st.AppendChild($Xaml.ImportNode($frag.DocumentElement, $true)) }
    }

    # Бумажное окно (диалог) получает фон с фактурой бумаги, как окна ClaudeWin.
    if ($root.LocalName -eq 'Window' -and $Kind -eq 'paper') {
        $root.RemoveAttribute('Background')
        $uri = [System.Security.SecurityElement]::Escape([System.Uri]::new((Join-Path $script:ThemeDir 'paper.png')).AbsoluteUri)
        # Кисть разбирается отдельно и вставляется в Window.Background, созданный здесь же:
        # у элемента-свойства не может быть своего xmlns, а у отдельно разобранного он появился бы.
        $bg = [xml]@"
<DrawingBrush xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TileMode="Tile" Viewport="0,0,512,512" ViewportUnits="Absolute">
    <DrawingBrush.Drawing>
        <DrawingGroup>
            <GeometryDrawing Brush="$($script:ThemeDialog)">
                <GeometryDrawing.Geometry><RectangleGeometry Rect="0,0,512,512"/></GeometryDrawing.Geometry>
            </GeometryDrawing>
            <ImageDrawing ImageSource="$uri" Rect="0,0,512,512"/>
        </DrawingGroup>
    </DrawingBrush.Drawing>
</DrawingBrush>
"@
        $prop = $Xaml.CreateElement('Window.Background', $ns)
        [void]$prop.AppendChild($Xaml.ImportNode($bg.DocumentElement, $true))
        [void]$root.InsertAfter($prop, $res)
    }
    return $Xaml
}

# Фон с фактурой из ClaudeWin: цвет и поверх него полупрозрачная картинка theme/paper.png или theme/metal.png.
# Картинка повторяется плиткой. Картинки рисует tools/make_textures.py клиента ClaudeWin.
function New-ThemeTextureBrush([string]$Color, [string]$Kind) {
    $file = Join-Path $script:ThemeDir "$Kind.png"
    $img = [System.Windows.Media.Imaging.BitmapImage]::new()
    $img.BeginInit()
    $img.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $img.UriSource = [System.Uri]::new($file)
    $img.EndInit()
    $img.Freeze()
    $size = if ($Kind -eq 'paper') { 512.0 } else { 384.0 }
    $rect = [System.Windows.Rect]::new(0, 0, $size, $size)
    $group = [System.Windows.Media.DrawingGroup]::new()
    $fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    [void]$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($fill, $null, [System.Windows.Media.RectangleGeometry]::new($rect)))
    [void]$group.Children.Add([System.Windows.Media.ImageDrawing]::new($img, $rect))
    $brush = [System.Windows.Media.DrawingBrush]::new($group)
    $brush.TileMode = [System.Windows.Media.TileMode]::Tile
    $brush.Viewport = $rect
    $brush.ViewportUnits = [System.Windows.Media.BrushMappingMode]::Absolute
    $brush.Freeze()
    return $brush
}

# Цвета рамы и панелей - те же, что в GAME_EXTRA клиента ClaudeWin.
$script:ThemeRust  = '#5B3B26'
$script:ThemePaper = '#CBC5B6'
$script:ThemeMetal = '#2C2B29'
$script:ThemeDialog = '#C3BCAC'

# Фактуры и ржавые рамы главного окна. Блоки ищутся по x:Name из разметки AntigravityGUI.ps1.
function Set-GameThemeSurfaces($Window) {
    if ($global:LauncherTheme -ne 'game') { return }
    $rust = [System.Windows.Media.BrushConverter]::new().ConvertFromString($script:ThemeRust)
    $Window.Background = New-ThemeTextureBrush '#242321' 'metal'
    foreach ($name in @('BorderTopPanel', 'BorderStatusBar')) {
        $b = $Window.FindName($name)
        $b.Background = New-ThemeTextureBrush $script:ThemeMetal 'metal'
        $b.BorderBrush = $rust
        $b.BorderThickness = [System.Windows.Thickness]::new(2)
    }
    $tabs = $Window.FindName('BorderTabBar')
    $tabs.Background = New-ThemeTextureBrush '#252422' 'metal'
    $tabs.BorderBrush = $rust
    $tabs.BorderThickness = [System.Windows.Thickness]::new(3, 3, 3, 0)
    $chat = $Window.FindName('BorderChat')
    $chat.Background = New-ThemeTextureBrush $script:ThemePaper 'paper'
    $chat.BorderBrush = $rust
    $chat.BorderThickness = [System.Windows.Thickness]::new(3, 0, 3, 3)
    $Window.FindName('TxtChatLog').Background = [System.Windows.Media.Brushes]::Transparent
    $prompt = $Window.FindName('TxtPromptInput')
    $prompt.Background = New-ThemeTextureBrush $script:ThemePaper 'paper'
    $prompt.BorderBrush = $rust
    $prompt.BorderThickness = [System.Windows.Thickness]::new(3)
}
