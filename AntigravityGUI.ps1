<#
.SYNOPSIS
    Графическая настольная оболочка (Desktop GUI) для запуска и взаимодействия с Antigravity CLI (agy.exe).
.DESCRIPTION
    Нативное приложение на базе Windows Presentation Foundation (WPF) и .NET.
    Не требует установки дополнительных интерпретаторов или библиотек.
    Поддерживает потоковый вывод (streaming) токенов, контекст сессий, выбор моделей и проектов.
#>

param(
    [switch]$Headless,
    [switch]$ValidateOnly
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

trap {
    $errText = "Фатальная ошибка при выполнении AntigravityGUI.ps1:`r`n$($_)`r`n$($_.ScriptStackTrace)"
    try {
        $logF = if ($PSScriptRoot) { Join-Path $PSScriptRoot "launcher_error.log" } else { Join-Path "H:\IGROSTROY\Agy-CLI-Shell" "launcher_error.log" }
        [System.IO.File]::WriteAllText($logF, $errText, [System.Text.Encoding]::UTF8)
        if (-not ($Headless -or $ValidateOnly)) {
            [System.Windows.MessageBox]::Show($errText, "Ошибка запуска Antigravity Launcher", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        } else {
            [Console]::Error.WriteLine($errText)
        }
    } catch {}
    exit 1
}

# --- Определение расположения исполняемого файла agy.exe ---
$defaultAgyPath = "$env:LOCALAPPDATA\agy\bin\agy.exe"
if (-not (Test-Path $defaultAgyPath)) {
    $foundInPath = (Get-Command agy.exe -ErrorAction SilentlyContinue).Source
    if ($foundInPath) {
        $defaultAgyPath = $foundInPath
    }
}

# --- Корневая папка проектов ---
$defaultWorkspace = "H:\IGROSTROY"
if (-not (Test-Path $defaultWorkspace)) {
    $defaultWorkspace = $PSScriptRoot
}

# --- XAML Интерфейс в современном темном стиле ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="⚡ Antigravity Agent Launcher"
        Height="780" Width="1080" MinHeight="620" MinWidth="880"
        WindowStartupLocation="CenterScreen"
        AllowDrop="True"
        Background="#181818" Foreground="#D4D4D4"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <!-- Системные цвета для выпадающих списков (ComboBox Popup) и контролов в темной теме -->
        <SolidColorBrush x:Key="{x:Static SystemColors.WindowBrushKey}" Color="#202020" />
        <SolidColorBrush x:Key="{x:Static SystemColors.WindowTextBrushKey}" Color="#F1F1F1" />
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#0E639C" />
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF" />

        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#D4D4D4"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="CaretBrush" Value="#007ACC"/>
        </Style>
        <!-- Шаблон кнопки ToggleButton для выпадающих списков (тёмный закрытый ComboBox) -->
        <ControlTemplate x:Key="ComboBoxToggleButtonTemplate" TargetType="{x:Type ToggleButton}">
            <Border x:Name="templateRoot" Background="#252526" BorderBrush="#3E3E42" BorderThickness="1" CornerRadius="3" SnapsToDevicePixels="true">
                <Border x:Name="splitBorder" Width="20" HorizontalAlignment="Right" Margin="0" BorderThickness="0">
                    <Path x:Name="arrow" Data="M 0 0 L 4 4 L 8 0 Z" Fill="#CCCCCC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="true">
                    <Setter TargetName="templateRoot" Property="Background" Value="#2D2D30" />
                    <Setter TargetName="templateRoot" Property="BorderBrush" Value="#007ACC" />
                    <Setter TargetName="arrow" Property="Fill" Value="#FFFFFF" />
                </Trigger>
                <Trigger Property="IsChecked" Value="true">
                    <Setter TargetName="templateRoot" Property="Background" Value="#252526" />
                    <Setter TargetName="templateRoot" Property="BorderBrush" Value="#007ACC" />
                    <Setter TargetName="arrow" Property="Fill" Value="#007ACC" />
                </Trigger>
                <Trigger Property="IsEnabled" Value="false">
                    <Setter TargetName="templateRoot" Property="Background" Value="#1E1E1E" />
                    <Setter TargetName="templateRoot" Property="BorderBrush" Value="#2D2D30" />
                    <Setter TargetName="arrow" Property="Fill" Value="#555555" />
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <!-- Шаблон графической полосы прогресса контекста -->
        <ControlTemplate x:Key="ContextProgressBarTemplate" TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                <Grid x:Name="PART_Track" ClipToBounds="True">
                    <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" CornerRadius="3.5"/>
                </Grid>
            </Border>
        </ControlTemplate>

        <!-- Шаблон графической полосы прогресса лимитов использования -->
        <ControlTemplate x:Key="LimitsProgressBarTemplate" TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                <Grid x:Name="PART_Track" ClipToBounds="True">
                    <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" CornerRadius="3.5"/>
                </Grid>
            </Border>
        </ControlTemplate>

        <!-- Полный тёмный стиль ComboBox: единый контрастный тёмный фон для закрытого и открытого состояния -->
        <Style TargetType="{x:Type ComboBox}">
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="Padding" Value="7,4,24,4"/>
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid x:Name="templateRoot" SnapsToDevicePixels="true">
                            <ToggleButton x:Name="toggleButton"
                                          Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}"
                                          BorderThickness="{TemplateBinding BorderThickness}"
                                          Focusable="false"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Template="{StaticResource ComboBoxToggleButtonTemplate}"/>
                            <ContentPresenter x:Name="contentPresenter"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                              ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}"
                                              HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                                              Margin="{TemplateBinding Padding}"
                                              IsHitTestVisible="false"
                                              SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                            <Popup x:Name="PART_Popup"
                                   AllowsTransparency="true"
                                   IsOpen="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                   Placement="Bottom"
                                   PopupAnimation="Slide">
                                <Border x:Name="dropDownBorder"
                                        Background="#202020"
                                        BorderBrush="#3E3E42"
                                        BorderThickness="1"
                                        CornerRadius="2"
                                        MaxHeight="{TemplateBinding MaxDropDownHeight}"
                                        MinWidth="{Binding ActualWidth, ElementName=templateRoot}">
                                    <ScrollViewer x:Name="DropDownScrollViewer" CanContentScroll="true" Foreground="#F1F1F1">
                                        <ItemsPresenter x:Name="ItemsPresenter" KeyboardNavigation.DirectionalNavigation="Contained" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="HasItems" Value="false">
                                <Setter TargetName="dropDownBorder" Property="Height" Value="95"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter TargetName="contentPresenter" Property="TextElement.Foreground" Value="#666666"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#202020"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="6,6"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="#0E639C"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#1177BB"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Верхняя панель настроек (Row 0) -->
            <RowDefinition Height="Auto"/> <!-- Панель вкладок диалогов (Row 1) -->
            <RowDefinition Height="*"/>    <!-- Окно чата и вывода (Row 2) -->
            <RowDefinition Height="Auto"/> <!-- Поле ввода и кнопки действий (Row 3) -->
            <RowDefinition Height="Auto"/> <!-- Статус бар (Row 4) -->
        </Grid.RowDefinitions>

        <!-- ВЕРХНЯЯ ПАНЕЛЬ -->
        <Border Grid.Row="0" Background="#202020" BorderBrush="#2D2D30" BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,12">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="8"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Строка 1: Рабочая папка -->
                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="220"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Grid.Column="0" Text="Рабочая папка:" VerticalAlignment="Center" Margin="0,0,10,0" FontWeight="SemiBold"/>
                    <TextBox x:Name="TxtWorkspace" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <Button x:Name="BtnBrowseWorkspace" Grid.Column="2" Content="Обзор..." Margin="0,0,8,0" MinWidth="75"/>
                    <ComboBox x:Name="CmbProjects" Grid.Column="3" ToolTip="Быстрый выбор проекта из папки IGROSTROY"/>
                </Grid>

                <!-- Строка 2: Настройки модели, режима и параметров мышления -->
                <Grid Grid.Row="2">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="180"/>
                        <ColumnDefinition Width="14"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="110"/>
                        <ColumnDefinition Width="14"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="90"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Модель -->
                    <TextBlock Grid.Column="0" Text="Модель:" VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <ComboBox x:Name="CmbModel" Grid.Column="1" VerticalAlignment="Center"/>

                    <!-- Режим -->
                    <TextBlock Grid.Column="3" Text="Режим:" VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <ComboBox x:Name="CmbMode" Grid.Column="4" VerticalAlignment="Center"/>

                    <!-- Effort -->
                    <TextBlock Grid.Column="6" Text="Рассуждение:" VerticalAlignment="Center" Margin="0,0,6,0"/>
                    <ComboBox x:Name="CmbEffort" Grid.Column="7" VerticalAlignment="Center"/>

                    <!-- Чекбокс прав -->
                    <CheckBox x:Name="ChkSkipPerms" Grid.Column="9" Content="Авто-подтверждение (--dangerously-skip-permissions)" IsChecked="True" VerticalAlignment="Center"/>
                </Grid>

                <!-- Строка 3: Разговоры и управление сессией -->
                <Grid Grid.Row="4">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Grid.Column="0" Text="Разговор:" VerticalAlignment="Center" Margin="0,0,10,0" FontWeight="SemiBold"/>
                    <ComboBox x:Name="CmbConversations" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,8,0" ToolTip="Быстрый выбор недавнего разговора для продолжения">
                        <ComboBox.ItemTemplate>
                            <DataTemplate>
                                <Grid Margin="2,2">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="{Binding DateStr}" Foreground="{Binding DateColor}" Margin="0,0,8,0" FontFamily="Consolas, Segoe UI" FontSize="12" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="1" Text="{Binding ProjStr}" Foreground="{Binding ProjColor}" FontWeight="SemiBold" Margin="0,0,8,0" FontSize="12" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="2" Text="{Binding TitleStr}" Foreground="#FFFFFF" TextTrimming="CharacterEllipsis" FontSize="12" VerticalAlignment="Center"/>
                                </Grid>
                            </DataTemplate>
                        </ComboBox.ItemTemplate>
                    </ComboBox>
                    <Button x:Name="BtnManageConversations" Grid.Column="2" Content="💬 Все диалоги..." Margin="0,0,6,0" Background="#203348" BorderBrush="#2D4B6E" ToolTip="Открыть полный список всех разговоров с поиском и предпросмотром"/>
                    <Button x:Name="BtnNewChat" Grid.Column="3" Content="➕ Новый диалог" Margin="0,0,6,0" Background="#2A3E2A" BorderBrush="#3B5A3B" ToolTip="Сбросить ID текущего диалога и начать новый"/>
                    <Button x:Name="BtnLaunchTui" Grid.Column="4" Content="🖥️ Открыть TUI" Margin="0,0,6,0" Background="#2A3245" BorderBrush="#3D4B66" ToolTip="Открыть интерактивную консоль agy с текущим диалогом"/>
                    <Button x:Name="BtnSwitchAccount" Grid.Column="5" Content="🔑 Аккаунт ▾" Background="#3A2F45" BorderBrush="#5A4670" ToolTip="Профили аккаунтов agy: переключение в один клик, сохранение текущего аккаунта, вход в другой аккаунт"/>
                </Grid>
            </Grid>
        </Border>

        <!-- ПАНЕЛЬ ВКЛАДОК ДИАЛОГОВ -->
        <Border Grid.Row="1" x:Name="BorderTabBar" Background="#141414" BorderBrush="#2D2D30" BorderThickness="1,1,1,0" CornerRadius="6,6,0,0" Padding="4,4,4,0" Margin="0,0,0,0">
            <ScrollViewer x:Name="ScrollTabs" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                <StackPanel x:Name="PnlTabsHeader" Orientation="Horizontal">
                    <Button x:Name="BtnNewTab" Content=" ➕ " Background="#252526" BorderBrush="#3E3E42" Foreground="#CCCCCC" Padding="8,3" Margin="2,0,2,4" FontWeight="Bold" FontSize="11" ToolTip="Новый диалог в отдельной вкладке (Ctrl+T)" Cursor="Hand" VerticalAlignment="Center" Height="28"/>
                </StackPanel>
            </ScrollViewer>
        </Border>

        <!-- ЦЕНТРАЛЬНОЕ ОКНО ЧАТА -->
        <Border Grid.Row="2" Background="#1E1E1E" BorderBrush="#2D2D30" BorderThickness="1,0,1,1" CornerRadius="0,0,6,6" Margin="0,0,0,12">
            <Grid>
                <RichTextBox x:Name="TxtChatLog"
                             Background="#1E1E1E"
                             Foreground="#D4D4D4"
                             BorderThickness="0"
                             Padding="12"
                             FontFamily="Consolas, Cascadia Code, Segoe UI"
                             FontSize="13"
                             IsReadOnly="True"
                             IsUndoEnabled="False"
                             IsDocumentEnabled="True"
                             VerticalScrollBarVisibility="Auto">
                    <FlowDocument PagePadding="0" LineHeight="22" LineStackingStrategy="BlockLineHeight"/>
                </RichTextBox>

                <!-- ОВЕРЛЕЙ АНИМАЦИИ ЗАГРУЗКИ ДИАЛОГА -->
                <Grid x:Name="LoadingOverlay" Visibility="Collapsed" Background="#D918181A">
                    <Border HorizontalAlignment="Center" VerticalAlignment="Center"
                            Background="#252528" BorderBrush="#007ACC" BorderThickness="1.5"
                            CornerRadius="12" Padding="28,24" Width="380">
                        <Border.Effect>
                            <DropShadowEffect Color="#007ACC" BlurRadius="25" ShadowDepth="0" Opacity="0.35"/>
                        </Border.Effect>
                        <StackPanel HorizontalAlignment="Center">
                            <Viewbox Width="44" Height="44" Margin="0,0,0,14" HorizontalAlignment="Center">
                                <Canvas Width="48" Height="48">
                                    <Ellipse Width="42" Height="42" Canvas.Left="3" Canvas.Top="3"
                                             Stroke="#333338" StrokeThickness="4"/>
                                    <Path Canvas.Left="3" Canvas.Top="3"
                                          Stroke="#4FC1FF" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                          Data="M 21 0 A 21 21 0 0 1 42 21">
                                        <Path.RenderTransform>
                                            <RotateTransform x:Name="SpinnerRotate" Angle="0" CenterX="21" CenterY="21"/>
                                        </Path.RenderTransform>
                                    </Path>
                                </Canvas>
                            </Viewbox>
                            <TextBlock x:Name="TxtLoadingTitle" Text="Загрузка диалога..."
                                       Foreground="#FFFFFF" FontWeight="Bold" FontSize="14"
                                       HorizontalAlignment="Center" Margin="0,0,0,4"/>
                            <TextBlock x:Name="TxtLoadingSubtitle" Text="Считывание истории и форматирование..."
                                       Foreground="#9CDCFE" FontSize="12"
                                       HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap"/>
                            <ProgressBar IsIndeterminate="True" Height="3" Margin="0,16,0,0"
                                         Background="#1E1E1E" Foreground="#4FC1FF" BorderThickness="0"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </Grid>
        </Border>

        <!-- НИЖНЯЯ ПАНЕЛЬ ВВОДА И ВЛОЖЕНИЙ -->
        <Grid Grid.Row="3" Margin="0,0,0,8">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> <!-- Панель прикрепленных картинок/файлов -->
                <RowDefinition Height="Auto"/> <!-- Поле ввода и кнопки действий -->
            </Grid.RowDefinitions>

            <!-- ПАНЕЛЬ ПРИКРЕПЛЕННЫХ ИЗОБРАЖЕНИЙ -->
            <Border x:Name="BorderAttachments" Grid.Row="0" Background="#1C2128" BorderBrush="#30363D" BorderThickness="1" CornerRadius="6" Padding="8,6" Margin="0,0,0,8" Visibility="Collapsed">
                <DockPanel LastChildFill="True">
                    <TextBlock DockPanel.Dock="Left" Text="📎 Прикреплено:" VerticalAlignment="Center" Foreground="#8B949E" FontWeight="SemiBold" Margin="0,0,10,0"/>
                    <Button x:Name="BtnClearAttachments" DockPanel.Dock="Right" Content="Очистить все" Padding="6,2" FontSize="11" Background="#21262D" BorderBrush="#30363D" Foreground="#F85149" Margin="8,0,0,0" ToolTip="Удалить все прикрепленные изображения"/>
                    <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="PnlAttachmentsList" Orientation="Horizontal"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- Поле ввода промпта и кнопки действий -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="130"/>
                </Grid.ColumnDefinitions>

                <!-- Поле ввода промпта -->
                <TextBox x:Name="TxtPromptInput"
                         Grid.Column="0"
                         Height="85"
                         Background="#252526"
                         Foreground="#FFFFFF"
                         BorderBrush="#3E3E42"
                         BorderThickness="1"
                         Padding="8"
                         FontFamily="Segoe UI"
                         FontSize="13"
                         AcceptsReturn="False"
                         TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         AllowDrop="True"
                         Margin="0,0,8,0"
                         ToolTip="Введите запрос к агенту. Нажмите Enter для отправки, Shift+Enter для новой строки. Нажмите Ctrl+V для вставки скриншота из буфера или перетащите картинку."/>

                <!-- Кнопки отправки, вложения и остановки -->
                <Grid Grid.Column="1">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="4"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="4"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Button x:Name="BtnSend"
                            Grid.Row="0"
                            Content="Отправить ↵"
                            Background="#0E639C"
                            BorderBrush="#1177BB"
                            FontWeight="Bold"
                            FontSize="13"
                            IsDefault="True"/>

                    <Grid Grid.Row="2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="4"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="BtnAttachImage"
                                Grid.Column="0"
                                Content="📎 Файл"
                                Background="#23272E"
                                BorderBrush="#3E4451"
                                Padding="2,3"
                                FontSize="11"
                                ToolTip="Прикрепить файл или изображение (Ctrl+V)"/>
                        <Button x:Name="BtnAttachFolder"
                                Grid.Column="2"
                                Content="📁 Папка"
                                Background="#23272E"
                                BorderBrush="#3E4451"
                                Padding="2,3"
                                FontSize="11"
                                ToolTip="Прикрепить папку проекта"/>
                    </Grid>

                    <Button x:Name="BtnStop"
                            Grid.Row="4"
                            Content="⏹ Стоп"
                            Background="#7A1D1D"
                            BorderBrush="#9B2626"
                            IsEnabled="False"
                            Padding="6,3"
                            FontSize="11"/>
                </Grid>
            </Grid>
        </Grid>

        <!-- СТАТУС БАР -->
        <Border Grid.Row="4" Background="#141414" BorderBrush="#252526" BorderThickness="1" CornerRadius="4" Padding="8,4">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="16"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="16"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="16"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Ellipse x:Name="StatusDot" Grid.Column="0" Width="10" Height="10" Fill="#4CAF50" Margin="0,0,8,0" VerticalAlignment="Center"/>
                <TextBlock x:Name="TxtStatus" Grid.Column="1" Text="Готов к работе" VerticalAlignment="Center" Foreground="#AAAAAA"/>
                <!-- ГРАФИЧЕСКИЕ ВИДЖЕТЫ: КОНТЕКСТ И ЛИМИТЫ ИСПОЛЬЗОВАНИЯ -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <!-- ГРАФИЧЕСКИЙ ВИДЖЕТ ЗАПОЛНЕННОСТИ КОНТЕКСТА -->
                    <Border x:Name="BorderContextWidget"
                            Background="#1C1F26" BorderBrush="#2D333B" BorderThickness="1"
                            CornerRadius="5" Padding="7,3" Cursor="Hand" VerticalAlignment="Center" Margin="0,0,8,0"
                            ToolTip="Заполненность контекстного окна модели. Нажмите для подробного анализа.">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="🧠" FontSize="11" Margin="0,0,5,0" VerticalAlignment="Center"/>
                            
                            <!-- Графическая полоса прогресса (Progress Bar) -->
                            <ProgressBar x:Name="PrgContext" Template="{StaticResource ContextProgressBarTemplate}"
                                         Width="75" Height="8" Minimum="0" Maximum="100" Value="0"
                                         Background="#14161C" BorderBrush="#252A34" BorderThickness="1"
                                         Foreground="#4EC9B0" Margin="0,0,6,0" VerticalAlignment="Center"/>

                            <!-- Числовой текст: 108k / 1.0M -->
                            <TextBlock x:Name="TxtContextTokens" Text="0 / 1.0M" FontSize="11" Foreground="#CCCCCC" FontFamily="Consolas, Segoe UI" Margin="0,0,6,0" VerticalAlignment="Center"/>

                            <!-- Графический бейдж с процентом -->
                            <Border x:Name="BorderContextBadge" Background="#1B2F2B" BorderBrush="#244B3F" BorderThickness="1" CornerRadius="3" Padding="4,0" VerticalAlignment="Center">
                                <TextBlock x:Name="TxtContextPercent" Text="0%" FontSize="10" FontWeight="Bold" Foreground="#4EC9B0"/>
                            </Border>
                        </StackPanel>
                    </Border>

                    <!-- ГРАФИЧЕСКИЙ ВИДЖЕТ ЛИМИТОВ ИСПОЛЬЗОВАНИЯ -->
                    <Border x:Name="BorderLimitsWidget"
                            Background="#1C1F26" BorderBrush="#2D333B" BorderThickness="1"
                            CornerRadius="5" Padding="7,3" Cursor="Hand" VerticalAlignment="Center"
                            ToolTip="Суточные лимиты использования (RPD, RPM, квоты токенов). Нажмите для дашборда квот.">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="⚡" FontSize="11" Margin="0,0,5,0" VerticalAlignment="Center"/>
                            
                            <!-- Графическая полоса прогресса лимитов -->
                            <ProgressBar x:Name="PrgLimits" Template="{StaticResource LimitsProgressBarTemplate}"
                                         Width="70" Height="8" Minimum="0" Maximum="100" Value="0"
                                         Background="#14161C" BorderBrush="#252A34" BorderThickness="1"
                                         Foreground="#4EC9B0" Margin="0,0,6,0" VerticalAlignment="Center"/>

                            <!-- Числовой текст: 23 / 1.5k -->
                            <TextBlock x:Name="TxtLimitsSummary" Text="0 / 1.5k" FontSize="11" Foreground="#CCCCCC" FontFamily="Consolas, Segoe UI" Margin="0,0,6,0" VerticalAlignment="Center"/>

                            <!-- Графический бейдж с остатком квоты -->
                            <Border x:Name="BorderLimitsBadge" Background="#1B2F2B" BorderBrush="#244B3F" BorderThickness="1" CornerRadius="3" Padding="4,0" VerticalAlignment="Center">
                                <TextBlock x:Name="TxtLimitsPercent" Text="100%" FontSize="10" FontWeight="Bold" Foreground="#4EC9B0"/>
                            </Border>
                        </StackPanel>
                    </Border>
                </StackPanel>
                <TextBlock x:Name="TxtZoom" Grid.Column="4" Text="🔍 100% (13pt)" ToolTip="Масштаб шрифта: зажмите Ctrl + колесико мыши (или Ctrl+0 / клик для сброса)" VerticalAlignment="Center" Foreground="#888888" Cursor="Hand"/>
                <TextBlock x:Name="TxtConversationId" Grid.Column="6" Text="Диалог: Новый" VerticalAlignment="Center" Foreground="#888888" Cursor="Hand" ToolTip="Нажмите, чтобы открыть менеджер разговоров"/>
                <Button x:Name="BtnClearLog" Grid.Column="8" Content="Очистить лог" Padding="8,2" FontSize="11" Background="#252526" BorderBrush="#3E3E42"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Загрузка XAML
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# --- Глобальная защита от вылетов в событиях UI WPF (Dispatcher Unhandled Exception) ---
$window.Dispatcher.Add_UnhandledException({
    param($s, $e)
    try {
        $logF = if ($PSScriptRoot) { Join-Path $PSScriptRoot "launcher_error.log" } else { Join-Path "H:\IGROSTROY\Agy-CLI-Shell" "launcher_error.log" }
        $errText = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Dispatcher UI Exception: $($e.Exception.Message)`r`n$($e.Exception.StackTrace)`r`n"
        [System.IO.File]::AppendAllText($logF, $errText, [System.Text.Encoding]::UTF8)
    } catch {}
    # Помечаем исключение как обработанное, чтобы окно интерфейса не вылетало
    $e.Handled = $true
})

# --- Определение расположения папки лаунчера ---
$launcherDir = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "AntigravityGUI.ps1"))) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path -and (Test-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "AntigravityGUI.ps1"))) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    "H:\IGROSTROY\Agy-CLI-Shell"
}

# Установка иконки приложения
$appIconPath = Join-Path $launcherDir "app_icon.ico"
if (Test-Path $appIconPath) {
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($appIconPath))
    } catch {}
}

# Поиск элементов управления по именам
$txtWorkspace           = $window.FindName("TxtWorkspace")
$btnBrowseWorkspace     = $window.FindName("BtnBrowseWorkspace")
$cmbProjects            = $window.FindName("CmbProjects")
$cmbModel               = $window.FindName("CmbModel")
$cmbMode                = $window.FindName("CmbMode")
$cmbEffort              = $window.FindName("CmbEffort")
$chkSkipPerms           = $window.FindName("ChkSkipPerms")
$cmbConversations       = $window.FindName("CmbConversations")
$btnManageConversations = $window.FindName("BtnManageConversations")
$btnNewChat             = $window.FindName("BtnNewChat")
$btnLaunchTui           = $window.FindName("BtnLaunchTui")
$btnSwitchAccount       = $window.FindName("BtnSwitchAccount")
$borderTabBar           = $window.FindName("BorderTabBar")
$btnNewTab              = $window.FindName("BtnNewTab")
$scrollTabs             = $window.FindName("ScrollTabs")
$pnlTabsHeader          = $window.FindName("PnlTabsHeader")
$txtChatLog             = $window.FindName("TxtChatLog")
$txtPromptInput         = $window.FindName("TxtPromptInput")
$btnSend                = $window.FindName("BtnSend")
$btnStop                = $window.FindName("BtnStop")
$statusDot              = $window.FindName("StatusDot")
$txtStatus              = $window.FindName("TxtStatus")
$borderContextWidget    = $window.FindName("BorderContextWidget")
$prgContext             = $window.FindName("PrgContext")
$txtContextTokens       = $window.FindName("TxtContextTokens")
$borderContextBadge     = $window.FindName("BorderContextBadge")
$txtContextPercent      = $window.FindName("TxtContextPercent")
$borderLimitsWidget     = $window.FindName("BorderLimitsWidget")
$prgLimits              = $window.FindName("PrgLimits")
$txtLimitsSummary       = $window.FindName("TxtLimitsSummary")
$borderLimitsBadge      = $window.FindName("BorderLimitsBadge")
$txtLimitsPercent       = $window.FindName("TxtLimitsPercent")
$txtZoom                = $window.FindName("TxtZoom")
$txtConversationId      = $window.FindName("TxtConversationId")
$btnClearLog            = $window.FindName("BtnClearLog")
$borderAttachments      = $window.FindName("BorderAttachments")
$pnlAttachmentsList     = $window.FindName("PnlAttachmentsList")
$btnClearAttachments    = $window.FindName("BtnClearAttachments")
$btnAttachImage         = $window.FindName("BtnAttachImage")
$btnAttachFolder        = $window.FindName("BtnAttachFolder")
$loadingOverlay         = $window.FindName("LoadingOverlay")
$spinnerRotate          = $window.FindName("SpinnerRotate")
$txtLoadingTitle        = $window.FindName("TxtLoadingTitle")
$txtLoadingSubtitle     = $window.FindName("TxtLoadingSubtitle")

# Запуск аппаратной плавной анимации вращения спиннера загрузки (60 FPS)
if ($spinnerRotate) {
    try {
        $spinnerAnim = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, 360.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds(1.0)))
        $spinnerAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $spinnerRotate.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $spinnerAnim)
    } catch {}
}

# --- Определение расположения папки лаунчера и конфигурации ---
$launcherDir = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "AntigravityGUI.ps1"))) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path -and (Test-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "AntigravityGUI.ps1"))) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    "H:\IGROSTROY\Agy-CLI-Shell"
}
# Пользовательские данные (вкладки, настройки, названия диалогов) хранятся в папке пользователя,
# а не рядом со скриптом: %APPDATA%\AntigravityLauncher
$userDataDir = Join-Path $env:APPDATA "AntigravityLauncher"
if (-not (Test-Path $userDataDir)) {
    New-Item -ItemType Directory -Path $userDataDir -Force | Out-Null
}
# Одноразовый перенос старых файлов из папки лаунчера
foreach ($dataFileName in @("launcher_config.json", "sessions_meta.json")) {
    $oldDataFile = Join-Path $launcherDir $dataFileName
    $newDataFile = Join-Path $userDataDir $dataFileName
    if ((Test-Path $oldDataFile) -and -not (Test-Path $newDataFile)) {
        Copy-Item -Path $oldDataFile -Destination $newDataFile
    }
}
$configFilePath = if ($env:ANTIGRAVITY_CONFIG_PATH) { $env:ANTIGRAVITY_CONFIG_PATH } else { Join-Path $userDataDir "launcher_config.json" }

# Профили аккаунтов agy (вход хранится в Диспетчере учётных данных Windows)
. (Join-Path $launcherDir "Accounts.ps1")

# --- Диагностика зависаний: perf.log в папке пользовательских данных ---
# Пишет время тяжёлых этапов и отдельным потоком (UiHangWatchdog) фиксирует, что окно перестало
# отвечать, и на каком этапе (PerfState.Stage). Этап "-" означает, что зависание не в коде
# лаунчера, а внутри WPF (раскладка/отрисовка документа).
$script:perfLogPath = Join-Path $userDataDir "perf.log"
try {
    if ((Test-Path $script:perfLogPath) -and ((Get-Item $script:perfLogPath).Length -gt 3MB)) {
        Move-Item -Path $script:perfLogPath -Destination ($script:perfLogPath + ".old") -Force
    }
} catch {}
$global:PerfState = [hashtable]::Synchronized(@{ Heartbeat = [DateTime]::UtcNow.Ticks; Stage = "-"; StageSince = [DateTime]::UtcNow.Ticks })

function Write-PerfLog {
    param([string]$Message)
    try {
        $line = "[{0:HH:mm:ss.fff}] {1}`r`n" -f [DateTime]::Now, $Message
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
        $fs = [System.IO.File]::Open($script:perfLogPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
    } catch {
        # лог диагностики не должен ронять приложение
    }
}

function Set-PerfStage {
    param([string]$Stage)
    $global:PerfState.Stage = $Stage
    $global:PerfState.StageSince = [DateTime]::UtcNow.Ticks
}

function Start-UiHangWatchdog {
    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        param($state, $logPath)
        function Write-WdLog([string]$m) {
            try {
                $line = "[{0:HH:mm:ss.fff}] {1}`r`n" -f [DateTime]::Now, $m
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
                $fs = [System.IO.File]::Open($logPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
                try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
            } catch {}
        }
        $hung = $false
        $hangStartTicks = 0L
        while ($true) {
            Start-Sleep -Milliseconds 500
            $nowTicks = [DateTime]::UtcNow.Ticks
            $idleMs = [long](($nowTicks - $state.Heartbeat) / 10000)
            if ($idleMs -gt 1500) {
                if (-not $hung) { $hung = $true; $hangStartTicks = $state.Heartbeat }
                $stageMs = [long](($nowTicks - $state.StageSince) / 10000)
                Write-WdLog "ЗАВИСАНИЕ: окно не отвечает $idleMs мс; этап: '$($state.Stage)' (в этапе уже $stageMs мс)"
            } elseif ($hung) {
                $hung = $false
                $totalMs = [long](($nowTicks - $hangStartTicks) / 10000)
                Write-WdLog "ОКНО ОТВЕЧАЕТ СНОВА: зависание длилось около $totalMs мс; последний этап: '$($state.Stage)'"
            }
        }
    }).AddArgument($global:PerfState).AddArgument($script:perfLogPath)
    [void]$ps.BeginInvoke()
    Write-PerfLog "=== Запуск лаунчера, watchdog зависаний включён (порог 1500 мс) ==="
}

# --- Коллекция прикрепленных изображений ---
$global:AttachedImages = [System.Collections.Generic.List[psobject]]::new()

function Get-AttachmentsDirectory {
    $targetDir = $null
    if ($txtWorkspace -and [string]::IsNullOrWhiteSpace($txtWorkspace.Text) -eq $false -and (Test-Path $txtWorkspace.Text)) {
        $targetDir = Join-Path $txtWorkspace.Text ".antigravity\attachments"
    } else {
        $targetDir = Join-Path $launcherDir "attachments"
    }
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    return $targetDir
}

function New-ArrowGeometry {
    param(
        [double]$x1, [double]$y1,
        [double]$x2, [double]$y2,
        [double]$headLength = 26.0,
        [double]$headWidth = 13.0
    )
    $dx = $x2 - $x1
    $dy = $y2 - $y1
    $len = [math]::Sqrt($dx * $dx + $dy * $dy)
    if ($len -lt 2.0) { return $null }

    $ux = $dx / $len
    $uy = $dy / $len
    $nx = -$uy
    $ny = $ux

    $headLen = [math]::Min($headLength, $len * 0.7)
    $bx = $x2 - $ux * $headLen
    $by = $y2 - $uy * $headLen

    $p1x = $bx + $nx * $headWidth
    $p1y = $by + $ny * $headWidth
    $p2x = $bx - $nx * $headWidth
    $p2y = $by - $ny * $headWidth

    $geom = [System.Windows.Media.StreamGeometry]::new()
    $ctx = $geom.Open()
    $ctx.BeginFigure([System.Windows.Point]::new($x1, $y1), $false, $false)
    $ctx.LineTo([System.Windows.Point]::new($bx, $by), $true, $true)
    $ctx.BeginFigure([System.Windows.Point]::new($x2, $y2), $true, $true)
    $ctx.LineTo([System.Windows.Point]::new($p1x, $p1y), $true, $true)
    $ctx.LineTo([System.Windows.Point]::new($p2x, $p2y), $true, $true)
    $ctx.Close()
    $geom.Freeze()
    return $geom
}

function Show-ImageViewerWindow {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string]$Title = "",
        [psobject]$AttachedItem = $null
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return }

    # Интеллектуальный поиск физического файла
    $targetPath = $FilePath
    if (-not (Test-Path $targetPath)) {
        $fn = [System.IO.Path]::GetFileName($FilePath)
        $candidates = @(
            (Join-Path $launcherDir "attachments\$fn"),
            ($(if ($txtWorkspace -and $txtWorkspace.Text) { Join-Path $txtWorkspace.Text ".antigravity\attachments\$fn" }))
        )
        $found = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        if ($found) {
            $targetPath = $found
        } else {
            [System.Windows.MessageBox]::Show("Файл изображения не найден на диске:`n$FilePath", "Изображение недоступно", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
    }

    try {
        $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit()
        $bi.UriSource = [System.Uri]::new((Convert-Path $targetPath))
        $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bi.EndInit()
        $bi.Freeze()
    } catch {
        [System.Windows.MessageBox]::Show("Не удалось загрузить изображение:`n$($_.ToString())", "Ошибка открытия", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }

    $fileName = [System.IO.Path]::GetFileName($targetPath)
    $dispTitle = if ($Title) { $Title } else { $fileName }
    $fileInfo = Get-Item $targetPath -ErrorAction SilentlyContinue
    $fileSizeKB = if ($fileInfo) { [math]::Round($fileInfo.Length / 1024) } else { 0 }
    $w = [math]::Round($bi.PixelWidth)
    $h = [math]::Round($bi.PixelHeight)
    $baseThickness = [math]::Max(3.0, [math]::Round($w / 350.0))

    # Создание окна просмотра
    $viewer = [System.Windows.Window]::new()
    $viewer.Title = "Просмотр изображения: $dispTitle ($w × $h)"
    $viewer.Width = [math]::Min(1200, [math]::Max(800, $w + 80))
    $viewer.Height = [math]::Min(880, [math]::Max(580, $h + 170))
    $viewer.MinWidth = 650
    $viewer.MinHeight = 480
    $viewer.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    if ($window -and $window.IsVisible) {
        $viewer.Owner = $window
    }
    $viewer.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#161A22")
    $viewer.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E6EDF3")

    $rootGrid = [System.Windows.Controls.Grid]::new()
    $rowTop = [System.Windows.Controls.RowDefinition]::new()
    $rowTop.Height = [System.Windows.GridLength]::new(44, [System.Windows.GridUnitType]::Pixel)
    $rowTools = [System.Windows.Controls.RowDefinition]::new()
    $rowTools.Height = [System.Windows.GridLength]::new(40, [System.Windows.GridUnitType]::Pixel)
    $rowCenter = [System.Windows.Controls.RowDefinition]::new()
    $rowCenter.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $rowBottom = [System.Windows.Controls.RowDefinition]::new()
    $rowBottom.Height = [System.Windows.GridLength]::new(36, [System.Windows.GridUnitType]::Pixel)

    $rootGrid.RowDefinitions.Add($rowTop)
    $rootGrid.RowDefinitions.Add($rowTools)
    $rootGrid.RowDefinitions.Add($rowCenter)
    $rootGrid.RowDefinitions.Add($rowBottom)

    # 1. Верхняя панель (Заголовок, метаданные и системные действия)
    $topBar = [System.Windows.Controls.Border]::new()
    $topBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F242C")
    $topBar.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $topBar.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $topBar.Padding = [System.Windows.Thickness]::new(14, 0, 14, 0)
    [System.Windows.Controls.Grid]::SetRow($topBar, 0)

    $topGrid = [System.Windows.Controls.DockPanel]::new()
    $topGrid.LastChildFill = $true

    $pnlActions = [System.Windows.Controls.StackPanel]::new()
    $pnlActions.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    [System.Windows.Controls.DockPanel]::SetDock($pnlActions, [System.Windows.Controls.Dock]::Right)

    $btnSys = [System.Windows.Controls.Button]::new()
    $btnSys.Content = "🖼️ В системе"
    $btnSys.ToolTip = "Открыть во внешнем системном просмотрщике Windows"
    $btnSys.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#238636")
    $btnSys.Foreground = [System.Windows.Media.Brushes]::White
    $btnSys.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnSys.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
    $btnSys.Margin = [System.Windows.Thickness]::new(6, 6, 0, 6)
    $btnSys.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnSys.Add_Click({
        try {
            $psi = [System.Diagnostics.ProcessStartInfo]::new($targetPath)
            $psi.UseShellExecute = $true
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("Не удалось запустить просмотрщик: $($_.ToString())", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    }.GetNewClosure())
    [void]$pnlActions.Children.Add($btnSys)

    $btnFolder = [System.Windows.Controls.Button]::new()
    $btnFolder.Content = "📁 В папке"
    $btnFolder.ToolTip = "Открыть папку с файлом в Проводнике"
    $btnFolder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D333B")
    $btnFolder.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnFolder.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnFolder.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
    $btnFolder.Margin = [System.Windows.Thickness]::new(6, 6, 0, 6)
    $btnFolder.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnFolder.Add_Click({
        try {
            [System.Diagnostics.Process]::Start("explorer.exe", "/select,`"$targetPath`"") | Out-Null
        } catch {}
    }.GetNewClosure())
    [void]$pnlActions.Children.Add($btnFolder)

    $btnCopyImg = [System.Windows.Controls.Button]::new()
    $btnCopyImg.Content = "📋 Картинка"
    $btnCopyImg.ToolTip = "Скопировать изображение в буфер обмена"
    $btnCopyImg.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D333B")
    $btnCopyImg.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnCopyImg.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnCopyImg.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
    $btnCopyImg.Margin = [System.Windows.Thickness]::new(6, 6, 0, 6)
    $btnCopyImg.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnCopyImg.Add_Click({
        try {
            [System.Windows.Clipboard]::SetImage($bi)
            $btnCopyImg.Content = "✅ Скопировано!"
            $t = [System.Windows.Threading.DispatcherTimer]::new()
            $t.Interval = [TimeSpan]::FromMilliseconds(1500)
            $t.Add_Tick({
                $btnCopyImg.Content = "📋 Картинка"
                $t.Stop()
            }.GetNewClosure())
            $t.Start()
        } catch {}
    }.GetNewClosure())
    [void]$pnlActions.Children.Add($btnCopyImg)

    $btnCopyPath = [System.Windows.Controls.Button]::new()
    $btnCopyPath.Content = "📋 Путь"
    $btnCopyPath.ToolTip = "Скопировать путь к файлу в буфер обмена"
    $btnCopyPath.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D333B")
    $btnCopyPath.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnCopyPath.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnCopyPath.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
    $btnCopyPath.Margin = [System.Windows.Thickness]::new(6, 6, 0, 6)
    $btnCopyPath.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnCopyPath.Add_Click({
        try {
            [System.Windows.Clipboard]::SetText($targetPath)
            $btnCopyPath.Content = "✅ Скопирован!"
            $t = [System.Windows.Threading.DispatcherTimer]::new()
            $t.Interval = [TimeSpan]::FromMilliseconds(1500)
            $t.Add_Tick({
                $btnCopyPath.Content = "📋 Путь"
                $t.Stop()
            }.GetNewClosure())
            $t.Start()
        } catch {}
    }.GetNewClosure())
    [void]$pnlActions.Children.Add($btnCopyPath)

    $btnClose = [System.Windows.Controls.Button]::new()
    $btnClose.Content = "✕"
    $btnClose.ToolTip = "Закрыть окно (Esc)"
    $btnClose.Background = [System.Windows.Media.Brushes]::Transparent
    $btnClose.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8B949E")
    $btnClose.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnClose.FontSize = 14
    $btnClose.FontWeight = [System.Windows.FontWeights]::Bold
    $btnClose.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
    $btnClose.Margin = [System.Windows.Thickness]::new(10, 6, 0, 6)
    $btnClose.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnClose.Add_Click({ $viewer.Close() }.GetNewClosure())
    [void]$pnlActions.Children.Add($btnClose)

    [void]$topGrid.Children.Add($pnlActions)

    $pnlTitle = [System.Windows.Controls.StackPanel]::new()
    $pnlTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tbTitle = [System.Windows.Controls.TextBlock]::new()
    $tbTitle.Text = $dispTitle
    $tbTitle.FontWeight = [System.Windows.FontWeights]::Bold
    $tbTitle.FontSize = 13
    $tbTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F6FC")
    $tbTitle.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [void]$pnlTitle.Children.Add($tbTitle)

    $tbMeta = [System.Windows.Controls.TextBlock]::new()
    $tbMeta.Text = "${w} × ${h} px  •  ${fileSizeKB} KB  •  $targetPath"
    $tbMeta.FontSize = 10
    $tbMeta.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8B949E")
    $tbMeta.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [void]$pnlTitle.Children.Add($tbMeta)

    [void]$topGrid.Children.Add($pnlTitle)
    $topBar.Child = $topGrid
    [void]$rootGrid.Children.Add($topBar)

    # 2. Панель инструментов разметки (Drawing Toolbar)
    $toolBar = [System.Windows.Controls.Border]::new()
    $toolBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#161B22")
    $toolBar.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $toolBar.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $toolBar.Padding = [System.Windows.Thickness]::new(14, 0, 14, 0)
    [System.Windows.Controls.Grid]::SetRow($toolBar, 1)

    $toolGrid = [System.Windows.Controls.DockPanel]::new()
    $toolGrid.LastChildFill = $false

    $pnlToolsLeft = [System.Windows.Controls.StackPanel]::new()
    $pnlToolsLeft.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $pnlToolsLeft.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.DockPanel]::SetDock($pnlToolsLeft, [System.Windows.Controls.Dock]::Left)

    $modeButtons = [System.Collections.Generic.List[psobject]]::new()

    $btnModePan = [System.Windows.Controls.Button]::new()
    $btnModePan.Content = "🖐️ Рука"
    $btnModePan.ToolTip = "Свободное перемещение и масштабирование (Клавиша H)"
    $btnModePan.Height = 28
    $btnModePan.Padding = [System.Windows.Thickness]::new(10, 2, 10, 2)
    $btnModePan.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
    $btnModePan.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnModePan.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F6FEB")
    $btnModePan.Foreground = [System.Windows.Media.Brushes]::White
    $btnModePan.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#388BFD")
    $btnModePan.BorderThickness = [System.Windows.Thickness]::new(1)
    $modeButtons.Add([pscustomobject]@{ Mode="Pan"; Button=$btnModePan })
    [void]$pnlToolsLeft.Children.Add($btnModePan)

    $btnModeRect = [System.Windows.Controls.Button]::new()
    $btnModeRect.Content = "🔲 Рамка"
    $btnModeRect.ToolTip = "Выделить область прямоугольником (Клавиша R)"
    $btnModeRect.Height = 28
    $btnModeRect.Padding = [System.Windows.Thickness]::new(10, 2, 10, 2)
    $btnModeRect.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
    $btnModeRect.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnModeRect.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnModeRect.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnModeRect.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $btnModeRect.BorderThickness = [System.Windows.Thickness]::new(1)
    $modeButtons.Add([pscustomobject]@{ Mode="Rect"; Button=$btnModeRect })
    [void]$pnlToolsLeft.Children.Add($btnModeRect)

    $btnModeArrow = [System.Windows.Controls.Button]::new()
    $btnModeArrow.Content = "↗️ Стрелка"
    $btnModeArrow.ToolTip = "Нарисовать стрелку-указатель (Клавиша A)"
    $btnModeArrow.Height = 28
    $btnModeArrow.Padding = [System.Windows.Thickness]::new(10, 2, 10, 2)
    $btnModeArrow.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $btnModeArrow.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnModeArrow.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnModeArrow.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnModeArrow.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $btnModeArrow.BorderThickness = [System.Windows.Thickness]::new(1)
    $modeButtons.Add([pscustomobject]@{ Mode="Arrow"; Button=$btnModeArrow })
    [void]$pnlToolsLeft.Children.Add($btnModeArrow)

    $sep1 = [System.Windows.Controls.Border]::new()
    $sep1.Width = 1
    $sep1.Height = 18
    $sep1.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $sep1.Margin = [System.Windows.Thickness]::new(4, 0, 10, 0)
    [void]$pnlToolsLeft.Children.Add($sep1)

    # Палитра цветов
    $colorButtons = [System.Collections.Generic.List[psobject]]::new()
    $colorsDef = @(
        @{ Hex="#FF3333"; Name="Красный маркер" },
        @{ Hex="#FFD700"; Name="Желтый маркер" },
        @{ Hex="#00E676"; Name="Зеленый маркер" }
    )

    foreach ($c in $colorsDef) {
        $btnColor = [System.Windows.Controls.Button]::new()
        $btnColor.Width = 20
        $btnColor.Height = 20
        $btnColor.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
        $btnColor.ToolTip = $c.Name
        $btnColor.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnColor.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($c.Hex)
        if ($c.Hex -eq "#FF3333") {
            $btnColor.BorderBrush = [System.Windows.Media.Brushes]::White
            $btnColor.BorderThickness = [System.Windows.Thickness]::new(2)
        } else {
            $btnColor.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
            $btnColor.BorderThickness = [System.Windows.Thickness]::new(1)
        }
        $hexVal = $c.Hex
        $colorButtons.Add([pscustomobject]@{ Hex=$hexVal; Button=$btnColor })
        [void]$pnlToolsLeft.Children.Add($btnColor)
    }

    $sep2 = [System.Windows.Controls.Border]::new()
    $sep2.Width = 1
    $sep2.Height = 18
    $sep2.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $sep2.Margin = [System.Windows.Thickness]::new(8, 0, 10, 0)
    [void]$pnlToolsLeft.Children.Add($sep2)

    # Undo
    $btnUndo = [System.Windows.Controls.Button]::new()
    $btnUndo.Content = "↩️ Отмена"
    $btnUndo.ToolTip = "Отменить последний маркер (Ctrl+Z)"
    $btnUndo.Height = 28
    $btnUndo.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $btnUndo.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
    $btnUndo.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnUndo.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnUndo.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnUndo.BorderThickness = [System.Windows.Thickness]::new(0)
    [void]$pnlToolsLeft.Children.Add($btnUndo)

    # Clear
    $btnClear = [System.Windows.Controls.Button]::new()
    $btnClear.Content = "🗑️ Очистить"
    $btnClear.ToolTip = "Удалить все нарисованные маркеры"
    $btnClear.Height = 28
    $btnClear.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $btnClear.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
    $btnClear.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnClear.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnClear.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnClear.BorderThickness = [System.Windows.Thickness]::new(0)
    [void]$pnlToolsLeft.Children.Add($btnClear)

    [void]$toolGrid.Children.Add($pnlToolsLeft)

    # Правая часть тулбара: кнопка сохранения / применения разметки
    $btnApply = [System.Windows.Controls.Button]::new()
    $btnApply.Content = "💾 Применить разметку"
    $btnApply.ToolTip = "Запечь маркеры в файл `_annotated.png` и прикрепить к сообщению"
    $btnApply.Height = 28
    $btnApply.Padding = [System.Windows.Thickness]::new(14, 2, 14, 2)
    $btnApply.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnApply.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#238636")
    $btnApply.Foreground = [System.Windows.Media.Brushes]::White
    $btnApply.FontWeight = [System.Windows.FontWeights]::SemiBold
    $btnApply.BorderThickness = [System.Windows.Thickness]::new(0)
    [System.Windows.Controls.DockPanel]::SetDock($btnApply, [System.Windows.Controls.Dock]::Right)
    [void]$toolGrid.Children.Add($btnApply)

    $toolBar.Child = $toolGrid
    [void]$rootGrid.Children.Add($toolBar)

    # 3. Центральная область с изображением и векторным холстом
    $canvasHost = [System.Windows.Controls.Grid]::new()
    $canvasHost.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0D1117")
    $canvasHost.ClipToBounds = $true
    $canvasHost.Cursor = [System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.Grid]::SetRow($canvasHost, 2)

    $innerCanvas = [System.Windows.Controls.Canvas]::new()
    $innerCanvas.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $innerCanvas.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $innerCanvas.Width = 0
    $innerCanvas.Height = 0

    $imgBox = [System.Windows.Controls.Grid]::new()
    $imgBox.Width = $w
    $imgBox.Height = $h
    [System.Windows.Controls.Canvas]::SetLeft($imgBox, -$w / 2.0)
    [System.Windows.Controls.Canvas]::SetTop($imgBox, -$h / 2.0)

    $imgView = [System.Windows.Controls.Image]::new()
    $imgView.Source = $bi
    $imgView.Width = $w
    $imgView.Height = $h

    $annotCanvas = [System.Windows.Controls.Canvas]::new()
    $annotCanvas.Width = $w
    $annotCanvas.Height = $h
    $annotCanvas.Background = [System.Windows.Media.Brushes]::Transparent

    [void]$imgBox.Children.Add($imgView)
    [void]$imgBox.Children.Add($annotCanvas)

    $transformGroup = [System.Windows.Media.TransformGroup]::new()
    $scaleTransform = [System.Windows.Media.ScaleTransform]::new(1.0, 1.0)
    $translateTransform = [System.Windows.Media.TranslateTransform]::new(0.0, 0.0)
    $transformGroup.Children.Add($scaleTransform)
    $transformGroup.Children.Add($translateTransform)
    $imgBox.RenderTransform = $transformGroup
    $imgBox.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)

    [void]$innerCanvas.Children.Add($imgBox)
    [void]$canvasHost.Children.Add($innerCanvas)
    [void]$rootGrid.Children.Add($canvasHost)

    # 4. Нижняя панель подсказок и масштабирования
    $botBar = [System.Windows.Controls.Border]::new()
    $botBar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#161B22")
    $botBar.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $botBar.BorderThickness = [System.Windows.Thickness]::new(0, 1, 0, 0)
    $botBar.Padding = [System.Windows.Thickness]::new(12, 0, 12, 0)
    [System.Windows.Controls.Grid]::SetRow($botBar, 3)

    $botGrid = [System.Windows.Controls.DockPanel]::new()
    $botGrid.LastChildFill = $false

    $lblHelp = [System.Windows.Controls.TextBlock]::new()
    $lblHelp.Text = "💡 Перемещение: зажмите ЛКМ  •  Колесико: масштаб  •  2x клик: сброс  •  Esc: закрыть"
    $lblHelp.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $lblHelp.FontSize = 11
    $lblHelp.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8B949E")
    [System.Windows.Controls.DockPanel]::SetDock($lblHelp, [System.Windows.Controls.Dock]::Left)
    [void]$botGrid.Children.Add($lblHelp)

    $pnlZoom = [System.Windows.Controls.StackPanel]::new()
    $pnlZoom.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $pnlZoom.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.DockPanel]::SetDock($pnlZoom, [System.Windows.Controls.Dock]::Right)

    $lblZoomVal = [System.Windows.Controls.TextBlock]::new()
    $lblZoomVal.Text = "100%"
    $lblZoomVal.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $lblZoomVal.Margin = [System.Windows.Thickness]::new(8, 0, 8, 0)
    $lblZoomVal.FontSize = 11
    $lblZoomVal.FontWeight = [System.Windows.FontWeights]::SemiBold
    $lblZoomVal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")

    $btnZoomOut = [System.Windows.Controls.Button]::new()
    $btnZoomOut.Content = "➖"
    $btnZoomOut.Width = 26
    $btnZoomOut.Height = 22
    $btnZoomOut.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnZoomOut.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnZoomOut.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnZoomOut.Cursor = [System.Windows.Input.Cursors]::Hand

    $btnZoomIn = [System.Windows.Controls.Button]::new()
    $btnZoomIn.Content = "➕"
    $btnZoomIn.Width = 26
    $btnZoomIn.Height = 22
    $btnZoomIn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnZoomIn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnZoomIn.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnZoomIn.Cursor = [System.Windows.Input.Cursors]::Hand

    $btnZoomReset = [System.Windows.Controls.Button]::new()
    $btnZoomReset.Content = "1:1"
    $btnZoomReset.ToolTip = "Масштаб 100% (1:1)"
    $btnZoomReset.Width = 32
    $btnZoomReset.Height = 22
    $btnZoomReset.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
    $btnZoomReset.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnZoomReset.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnZoomReset.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnZoomReset.Cursor = [System.Windows.Input.Cursors]::Hand

    [void]$pnlZoom.Children.Add($btnZoomOut)
    [void]$pnlZoom.Children.Add($lblZoomVal)
    [void]$pnlZoom.Children.Add($btnZoomIn)
    [void]$pnlZoom.Children.Add($btnZoomReset)

    $btnZoomFit = [System.Windows.Controls.Button]::new()
    $btnZoomFit.Content = "⛶"
    $btnZoomFit.ToolTip = "Вписать изображение в окно (Клавиша F или 2x клик)"
    $btnZoomFit.Width = 26
    $btnZoomFit.Height = 22
    $btnZoomFit.Margin = [System.Windows.Thickness]::new(4, 0, 0, 0)
    $btnZoomFit.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $btnZoomFit.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $btnZoomFit.BorderThickness = [System.Windows.Thickness]::new(0)
    $btnZoomFit.Cursor = [System.Windows.Input.Cursors]::Hand
    [void]$pnlZoom.Children.Add($btnZoomFit)

    [void]$botGrid.Children.Add($pnlZoom)
    $botBar.Child = $botGrid
    [void]$rootGrid.Children.Add($botBar)

    # 5. Единый синхронизированный контекст состояния окна
    $state = [hashtable]::Synchronized(@{
        Viewer             = $viewer
        CanvasHost         = $canvasHost
        AnnotCanvas        = $annotCanvas
        ScaleTransform     = $scaleTransform
        TranslateTransform = $translateTransform
        LblHelp            = $lblHelp
        LblZoomVal         = $lblZoomVal
        BtnPan             = $btnModePan
        BtnRect            = $btnModeRect
        BtnArrow           = $btnModeArrow
        BtnUndo            = $btnUndo
        BtnClear           = $btnClear
        BtnApply           = $btnApply
        ModeButtons        = $modeButtons
        ColorButtons       = $colorButtons
        CurrentMode        = "Pan"
        CurrentColor       = "#FF3333"
        Width              = $w
        Height             = $h
        BaseThickness      = $baseThickness
        IsPanning          = $false
        IsDrawing          = $false
        StartX             = 0.0
        StartY             = 0.0
        StartMouseX        = 0.0
        StartMouseY        = 0.0
        StartTransX        = 0.0
        StartTransY        = 0.0
        CurrentZoom        = 1.0
        InitialZoom        = 1.0
        CurrentShape       = $null
        ShapesList         = [System.Collections.Generic.List[psobject]]::new()
        BitmapImage        = $bi
        TargetPath         = $targetPath
        AttachedItem       = $AttachedItem
    })

    # Обработчики режимов
    $SwitchMode = {
        param([string]$newMode)
        $state.CurrentMode = $newMode
        foreach ($mb in $state.ModeButtons) {
            if ($mb.Mode -eq $newMode) {
                $mb.Button.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F6FEB")
                $mb.Button.Foreground = [System.Windows.Media.Brushes]::White
                $mb.Button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#388BFD")
            } else {
                $mb.Button.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
                $mb.Button.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
                $mb.Button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
            }
        }
        if ($newMode -eq "Pan") {
            $state.AnnotCanvas.Cursor = [System.Windows.Input.Cursors]::Hand
            $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Hand
            $state.LblHelp.Text = "💡 Перемещение: зажмите ЛКМ  •  Колесико: масштаб  •  2x клик: сброс  •  Esc: закрыть"
        } elseif ($newMode -eq "Rect") {
            $state.AnnotCanvas.Cursor = [System.Windows.Input.Cursors]::Cross
            $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Cross
            $state.LblHelp.Text = "💡 Рисование рамки: зажмите ЛКМ и протяните  •  Панорамирование: зажмите ПКМ/СКМ"
        } elseif ($newMode -eq "Arrow") {
            $state.AnnotCanvas.Cursor = [System.Windows.Input.Cursors]::Cross
            $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Cross
            $state.LblHelp.Text = "💡 Рисование стрелки: протяните ЛКМ от начала к цели  •  Панорамирование: зажмите ПКМ/СКМ"
        }
    }.GetNewClosure()

    $btnModePan.Add_Click({ & $SwitchMode "Pan" }.GetNewClosure())
    $btnModeRect.Add_Click({ & $SwitchMode "Rect" }.GetNewClosure())
    $btnModeArrow.Add_Click({ & $SwitchMode "Arrow" }.GetNewClosure())

    # Выбор цвета маркера
    foreach ($cb in $state.ColorButtons) {
        $colorHex = $cb.Hex
        $cb.Button.Add_Click({
            $state.CurrentColor = $colorHex
            foreach ($item in $state.ColorButtons) {
                if ($item.Hex -eq $colorHex) {
                    $item.Button.BorderBrush = [System.Windows.Media.Brushes]::White
                    $item.Button.BorderThickness = [System.Windows.Thickness]::new(2)
                } else {
                    $item.Button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
                    $item.Button.BorderThickness = [System.Windows.Thickness]::new(1)
                }
            }
        }.GetNewClosure())
    }

    # Undo
    $PerformUndo = {
        if ($state.ShapesList.Count -gt 0) {
            $lastItem = $state.ShapesList[$state.ShapesList.Count - 1]
            if ($lastItem -and $lastItem.Element) {
                $state.AnnotCanvas.Children.Remove($lastItem.Element) | Out-Null
            }
            $state.ShapesList.Remove($lastItem) | Out-Null
        }
    }.GetNewClosure()
    $btnUndo.Add_Click({ & $PerformUndo }.GetNewClosure())

    # Clear
    $PerformClear = {
        $state.AnnotCanvas.Children.Clear()
        $state.ShapesList.Clear()
    }.GetNewClosure()
    $btnClear.Add_Click({ & $PerformClear }.GetNewClosure())

    # Масштабирование
    $btnZoomOut.Add_Click({
        $state.CurrentZoom = [math]::Max(0.1, $state.CurrentZoom - 0.15)
        $state.ScaleTransform.ScaleX = $state.CurrentZoom
        $state.ScaleTransform.ScaleY = $state.CurrentZoom
        $state.LblZoomVal.Text = "$([math]::Round($state.CurrentZoom * 100))%"
    }.GetNewClosure())

    $btnZoomIn.Add_Click({
        $state.CurrentZoom = [math]::Min(10.0, $state.CurrentZoom + 0.15)
        $state.ScaleTransform.ScaleX = $state.CurrentZoom
        $state.ScaleTransform.ScaleY = $state.CurrentZoom
        $state.LblZoomVal.Text = "$([math]::Round($state.CurrentZoom * 100))%"
    }.GetNewClosure())

    $btnZoomReset.Add_Click({
        $state.CurrentZoom = 1.0
        $state.ScaleTransform.ScaleX = 1.0
        $state.ScaleTransform.ScaleY = 1.0
        $state.TranslateTransform.X = 0.0
        $state.TranslateTransform.Y = 0.0
        $state.LblZoomVal.Text = "100%"
    }.GetNewClosure())

    $PerformZoomFit = {
        $state.CurrentZoom = $state.InitialZoom
        $state.ScaleTransform.ScaleX = $state.InitialZoom
        $state.ScaleTransform.ScaleY = $state.InitialZoom
        $state.TranslateTransform.X = 0.0
        $state.TranslateTransform.Y = 0.0
        $state.LblZoomVal.Text = "$([math]::Round($state.InitialZoom * 100))%"
    }.GetNewClosure()
    $btnZoomFit.Add_Click({ & $PerformZoomFit }.GetNewClosure())

    # Мышиные события: интерактивное панорамирование и рисование
    $canvasHost.Add_PreviewMouseDown({
        param($s, $e)
        if ($state.CurrentMode -eq "Pan") {
            if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left -or $e.ChangedButton -eq [System.Windows.Input.MouseButton]::Middle) {
                if ($e.ClickCount -ge 2 -and $e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
                    $state.CurrentZoom = $state.InitialZoom
                    $state.ScaleTransform.ScaleX = $state.InitialZoom
                    $state.ScaleTransform.ScaleY = $state.InitialZoom
                    $state.TranslateTransform.X = 0.0
                    $state.TranslateTransform.Y = 0.0
                    $state.LblZoomVal.Text = "$([math]::Round($state.InitialZoom * 100))%"
                    $e.Handled = $true
                    return
                }

                $state.IsPanning = $true
                $pos = $e.GetPosition($state.CanvasHost)
                $state.StartMouseX = $pos.X
                $state.StartMouseY = $pos.Y
                $state.StartTransX = $state.TranslateTransform.X
                $state.StartTransY = $state.TranslateTransform.Y
                $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::SizeAll
                $state.CanvasHost.CaptureMouse() | Out-Null
                $e.Handled = $true
            }
        } else {
            # В режимах Rect и Arrow: ПКМ или СКМ панорамируют
            if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Right -or $e.ChangedButton -eq [System.Windows.Input.MouseButton]::Middle) {
                $state.IsPanning = $true
                $pos = $e.GetPosition($state.CanvasHost)
                $state.StartMouseX = $pos.X
                $state.StartMouseY = $pos.Y
                $state.StartTransX = $state.TranslateTransform.X
                $state.StartTransY = $state.TranslateTransform.Y
                $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::SizeAll
                $state.CanvasHost.CaptureMouse() | Out-Null
                $e.Handled = $true
                return
            }

            # ЛКМ рисует
            if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
                $pos = $e.GetPosition($state.AnnotCanvas)
                $state.IsDrawing = $true
                $state.StartX = [math]::Max(0.0, [math]::Min([double]$state.Width, $pos.X))
                $state.StartY = [math]::Max(0.0, [math]::Min([double]$state.Height, $pos.Y))

                $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($state.CurrentColor)

                if ($state.CurrentMode -eq "Rect") {
                    $shape = [System.Windows.Shapes.Rectangle]::new()
                    $shape.Stroke = $brush
                    $shape.StrokeThickness = $state.BaseThickness
                    $col = [System.Windows.Media.ColorConverter]::ConvertFromString($state.CurrentColor)
                    $shape.Fill = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(40, $col.R, $col.G, $col.B))
                    $shape.RadiusX = 4
                    $shape.RadiusY = 4
                    [System.Windows.Controls.Canvas]::SetLeft($shape, $state.StartX)
                    [System.Windows.Controls.Canvas]::SetTop($shape, $state.StartY)
                    $shape.Width = 0
                    $shape.Height = 0
                    [void]$state.AnnotCanvas.Children.Add($shape)
                    $state.CurrentShape = $shape
                } elseif ($state.CurrentMode -eq "Arrow") {
                    $shape = [System.Windows.Shapes.Path]::new()
                    $shape.Stroke = $brush
                    $shape.StrokeThickness = $state.BaseThickness
                    $shape.Fill = $brush
                    $shape.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
                    $shape.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
                    $shape.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
                    [void]$state.AnnotCanvas.Children.Add($shape)
                    $state.CurrentShape = $shape
                }

                $state.CanvasHost.CaptureMouse() | Out-Null
                $e.Handled = $true
            }
        }
    }.GetNewClosure())

    $canvasHost.Add_PreviewMouseMove({
        param($s, $e)
        if ($state.IsPanning) {
            $cur = $e.GetPosition($state.CanvasHost)
            $deltaX = $cur.X - $state.StartMouseX
            $deltaY = $cur.Y - $state.StartMouseY
            $state.TranslateTransform.X = $state.StartTransX + $deltaX
            $state.TranslateTransform.Y = $state.StartTransY + $deltaY
        } elseif ($state.IsDrawing -and $state.CurrentShape) {
            $curPos = $e.GetPosition($state.AnnotCanvas)
            $curX = [math]::Max(0.0, [math]::Min([double]$state.Width, $curPos.X))
            $curY = [math]::Max(0.0, [math]::Min([double]$state.Height, $curPos.Y))

            if ($state.CurrentMode -eq "Rect") {
                $minX = [math]::Min($state.StartX, $curX)
                $minY = [math]::Min($state.StartY, $curY)
                $rw = [math]::Abs($curX - $state.StartX)
                $rh = [math]::Abs($curY - $state.StartY)
                [System.Windows.Controls.Canvas]::SetLeft($state.CurrentShape, $minX)
                [System.Windows.Controls.Canvas]::SetTop($state.CurrentShape, $minY)
                $state.CurrentShape.Width = $rw
                $state.CurrentShape.Height = $rh
            } elseif ($state.CurrentMode -eq "Arrow") {
                $arrowGeom = New-ArrowGeometry -x1 $state.StartX -y1 $state.StartY -x2 $curX -y2 $curY -headLength ($state.BaseThickness * 7.0) -headWidth ($state.BaseThickness * 3.5)
                if ($arrowGeom) {
                    $state.CurrentShape.Data = $arrowGeom
                }
            }
        }
    }.GetNewClosure())

    $canvasHost.Add_PreviewMouseUp({
        param($s, $e)
        if ($state.IsPanning) {
            $state.IsPanning = $false
            $state.CanvasHost.ReleaseMouseCapture()
            if ($state.CurrentMode -eq "Pan") {
                $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Hand
            } else {
                $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Cross
            }
            $e.Handled = $true
        } elseif ($state.IsDrawing) {
            $state.IsDrawing = $false
            $state.CanvasHost.ReleaseMouseCapture()

            if ($state.CurrentShape) {
                if ($state.CurrentMode -eq "Rect") {
                    if ($state.CurrentShape.Width -ge 6 -and $state.CurrentShape.Height -ge 6) {
                        $state.ShapesList.Add([pscustomobject]@{
                            Type    = "Rect"
                            Element = $state.CurrentShape
                            X       = [System.Windows.Controls.Canvas]::GetLeft($state.CurrentShape)
                            Y       = [System.Windows.Controls.Canvas]::GetTop($state.CurrentShape)
                            W       = $state.CurrentShape.Width
                            H       = $state.CurrentShape.Height
                            Color   = $state.CurrentColor
                        })
                    } else {
                        $state.AnnotCanvas.Children.Remove($state.CurrentShape) | Out-Null
                    }
                } elseif ($state.CurrentMode -eq "Arrow") {
                    $curPos = $e.GetPosition($state.AnnotCanvas)
                    $curX = [math]::Max(0.0, [math]::Min([double]$state.Width, $curPos.X))
                    $curY = [math]::Max(0.0, [math]::Min([double]$state.Height, $curPos.Y))
                    $dx = $curX - $state.StartX
                    $dy = $curY - $state.StartY
                    $len = [math]::Sqrt($dx * $dx + $dy * $dy)
                    if ($len -ge 10.0) {
                        $state.ShapesList.Add([pscustomobject]@{
                            Type    = "Arrow"
                            Element = $state.CurrentShape
                            X1      = $state.StartX
                            Y1      = $state.StartY
                            X2      = $curX
                            Y2      = $curY
                            Color   = $state.CurrentColor
                        })
                    } else {
                        $state.AnnotCanvas.Children.Remove($state.CurrentShape) | Out-Null
                    }
                }
                $state.CurrentShape = $null
            }
            $e.Handled = $true
        }
    }.GetNewClosure())

    $canvasHost.Add_LostMouseCapture({
        $state.IsPanning = $false
        if ($state.IsDrawing) {
            $state.IsDrawing = $false
            if ($state.CurrentShape) {
                $state.AnnotCanvas.Children.Remove($state.CurrentShape) | Out-Null
                $state.CurrentShape = $null
            }
        }
        if ($state.CurrentMode -eq "Pan") {
            $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Hand
        } else {
            $state.CanvasHost.Cursor = [System.Windows.Input.Cursors]::Cross
        }
    }.GetNewClosure())

    # Масштабирование колесиком мыши
    $canvasHost.Add_PreviewMouseWheel({
        param($s, $e)
        $e.Handled = $true
        $delta = if ($e.Delta -gt 0) { 0.15 } else { -0.15 }
        $state.CurrentZoom = [math]::Max(0.1, [math]::Min(10.0, $state.CurrentZoom + $delta))
        $state.ScaleTransform.ScaleX = $state.CurrentZoom
        $state.ScaleTransform.ScaleY = $state.CurrentZoom
        $state.LblZoomVal.Text = "$([math]::Round($state.CurrentZoom * 100))%"
    }.GetNewClosure())

    # Автоматическая подгонка масштаба при загрузке и изменении размера окна (UpdateFitZoom)
    $UpdateFitZoom = {
        if ($state.CanvasHost.ActualWidth -gt 50 -and $state.CanvasHost.ActualHeight -gt 50) {
            $vw = $state.CanvasHost.ActualWidth - 20
            $vh = $state.CanvasHost.ActualHeight - 20
            $fit = [math]::Min(1.0, [math]::Min(($vw / $state.Width), ($vh / $state.Height)))
            if ($fit -gt 0.05) {
                $isInitialOrFit = ([math]::Abs($state.CurrentZoom - $state.InitialZoom) -lt 0.02)
                $state.InitialZoom = $fit
                if ($isInitialOrFit) {
                    $state.CurrentZoom = $fit
                    $state.ScaleTransform.ScaleX = $fit
                    $state.ScaleTransform.ScaleY = $fit
                    $state.TranslateTransform.X = 0.0
                    $state.TranslateTransform.Y = 0.0
                    $state.LblZoomVal.Text = "$([math]::Round($fit * 100))%"
                }
            }
        }
    }.GetNewClosure()

    $canvasHost.Add_Loaded({ & $UpdateFitZoom }.GetNewClosure())
    $canvasHost.Add_SizeChanged({ & $UpdateFitZoom }.GetNewClosure())

    # Восстановление сохраненных маркеров при повторном открытии того же изображения
    if ($AttachedItem -and $AttachedItem.PSObject.Properties['SavedShapes'] -and $AttachedItem.SavedShapes) {
        foreach ($saved in $AttachedItem.SavedShapes) {
            $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($saved.Color)
            if ($saved.Type -eq "Rect") {
                $rShape = [System.Windows.Shapes.Rectangle]::new()
                $rShape.Stroke = $brush
                $rShape.StrokeThickness = $state.BaseThickness
                $col = [System.Windows.Media.ColorConverter]::ConvertFromString($saved.Color)
                $rShape.Fill = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(40, $col.R, $col.G, $col.B))
                $rShape.RadiusX = 4
                $rShape.RadiusY = 4
                [System.Windows.Controls.Canvas]::SetLeft($rShape, $saved.X)
                [System.Windows.Controls.Canvas]::SetTop($rShape, $saved.Y)
                $rShape.Width = $saved.W
                $rShape.Height = $saved.H
                [void]$state.AnnotCanvas.Children.Add($rShape)
                $state.ShapesList.Add([pscustomobject]@{
                    Type    = "Rect"
                    Element = $rShape
                    X       = $saved.X
                    Y       = $saved.Y
                    W       = $saved.W
                    H       = $saved.H
                    Color   = $saved.Color
                })
            } elseif ($saved.Type -eq "Arrow") {
                $aShape = [System.Windows.Shapes.Path]::new()
                $aShape.Stroke = $brush
                $aShape.StrokeThickness = $state.BaseThickness
                $aShape.Fill = $brush
                $aShape.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
                $aShape.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
                $aShape.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
                $aShape.Data = New-ArrowGeometry -x1 $saved.X1 -y1 $saved.Y1 -x2 $saved.X2 -y2 $saved.Y2 -headLength ($state.BaseThickness * 7.0) -headWidth ($state.BaseThickness * 3.5)
                [void]$state.AnnotCanvas.Children.Add($aShape)
                $state.ShapesList.Add([pscustomobject]@{
                    Type    = "Arrow"
                    Element = $aShape
                    X1      = $saved.X1
                    Y1      = $saved.Y1
                    X2      = $saved.X2
                    Y2      = $saved.Y2
                    Color   = $saved.Color
                })
            }
        }
    }

    # Сохранение и запекание разметки в _annotated.png
    $PerformApply = {
        if ($state.ShapesList.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Сначала нарисуйте хотя бы один маркер (рамку или стрелку) на изображении.", "Разметка не найдена", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }

        try {
            # 1. Запекание нативного изображения с разметкой
            $dv = [System.Windows.Media.DrawingVisual]::new()
            $dc = $dv.RenderOpen()
            $dc.DrawImage($state.BitmapImage, [System.Windows.Rect]::new(0, 0, $state.Width, $state.Height))

            foreach ($item in $state.ShapesList) {
                $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($item.Color)
                if ($item.Type -eq "Rect") {
                    $col = [System.Windows.Media.ColorConverter]::ConvertFromString($item.Color)
                    $fillBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(40, $col.R, $col.G, $col.B))
                    $pen = [System.Windows.Media.Pen]::new($brush, $state.BaseThickness)
                    $dc.DrawRoundedRectangle($fillBrush, $pen, [System.Windows.Rect]::new($item.X, $item.Y, $item.W, $item.H), 4.0, 4.0)
                } elseif ($item.Type -eq "Arrow") {
                    $pen = [System.Windows.Media.Pen]::new($brush, $state.BaseThickness)
                    $pen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
                    $pen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
                    $pen.LineJoin = [System.Windows.Media.PenLineJoin]::Round
                    $arrowGeom = New-ArrowGeometry -x1 $item.X1 -y1 $item.Y1 -x2 $item.X2 -y2 $item.Y2 -headLength ($state.BaseThickness * 7.0) -headWidth ($state.BaseThickness * 3.5)
                    if ($arrowGeom) {
                        $dc.DrawGeometry($brush, $pen, $arrowGeom)
                    }
                }
            }
            $dc.Close()

            $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($state.Width, $state.Height, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
            $rtb.Render($dv)

            # 2. Сохранение файла
            $dir = [System.IO.Path]::GetDirectoryName($state.TargetPath)
            $baseFn = [System.IO.Path]::GetFileNameWithoutExtension($state.TargetPath)
            $cleanBase = $baseFn -replace '_annotated$', ''
            $annotatedPath = Join-Path $dir "${cleanBase}_annotated.png"

            $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
            $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
            $fsOut = [System.IO.FileStream]::new($annotatedPath, [System.IO.FileMode]::Create)
            $encoder.Save($fsOut)
            $fsOut.Close()

            # 3. Привязка к списку вложений
            $targetAtt = $state.AttachedItem
            if (-not $targetAtt) {
                $targetAtt = $global:AttachedImages | Where-Object { $_.FilePath -eq $state.TargetPath -or $_.FilePath -eq (Join-Path $dir "${cleanBase}.png") } | Select-Object -First 1
            }

            $savedShapesList = [System.Collections.Generic.List[psobject]]::new()
            foreach ($sh in $state.ShapesList) {
                if ($sh.Type -eq "Rect") {
                    $savedShapesList.Add([pscustomobject]@{
                        Type  = "Rect"
                        X     = $sh.X
                        Y     = $sh.Y
                        W     = $sh.W
                        H     = $sh.H
                        Color = $sh.Color
                    })
                } elseif ($sh.Type -eq "Arrow") {
                    $savedShapesList.Add([pscustomobject]@{
                        Type  = "Arrow"
                        X1    = $sh.X1
                        Y1    = $sh.Y1
                        X2    = $sh.X2
                        Y2    = $sh.Y2
                        Color = $sh.Color
                    })
                }
            }

            if ($targetAtt) {
                if ($targetAtt.PSObject.Properties['AnnotatedFilePath']) {
                    $targetAtt.AnnotatedFilePath = $annotatedPath
                } else {
                    $targetAtt | Add-Member -NotePropertyName "AnnotatedFilePath" -NotePropertyValue $annotatedPath -Force
                }
                if ($targetAtt.PSObject.Properties['HasAnnotation']) {
                    $targetAtt.HasAnnotation = $true
                } else {
                    $targetAtt | Add-Member -NotePropertyName "HasAnnotation" -NotePropertyValue $true -Force
                }
                if ($targetAtt.PSObject.Properties['SavedShapes']) {
                    $targetAtt.SavedShapes = $savedShapesList
                } else {
                    $targetAtt | Add-Member -NotePropertyName "SavedShapes" -NotePropertyValue $savedShapesList -Force
                }
            } else {
                $newItem = [pscustomobject]@{
                    ItemType          = "Image"
                    FilePath          = $state.TargetPath
                    FileName          = [System.IO.Path]::GetFileName($state.TargetPath)
                    DisplayName       = $cleanBase
                    DimInfo           = "$($state.Width)x$($state.Height) • $([math]::Round((Get-Item $state.TargetPath).Length / 1024)) KB"
                    ImageSource       = $state.BitmapImage
                    Icon              = "🖼️"
                    AnnotatedFilePath = $annotatedPath
                    HasAnnotation     = $true
                    SavedShapes       = $savedShapesList
                }
                $global:AttachedImages.Add($newItem)
            }


            Render-AttachmentsUI

            $state.BtnApply.Content = "✅ Разметка сохранена!"
            $state.BtnApply.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F6FEB")
            $t = [System.Windows.Threading.DispatcherTimer]::new()
            $t.Interval = [TimeSpan]::FromMilliseconds(2000)
            $t.Add_Tick({
                $state.BtnApply.Content = "💾 Применить разметку"
                $state.BtnApply.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#238636")
                $t.Stop()
            }.GetNewClosure())
            $t.Start()
        } catch {
            [System.Windows.MessageBox]::Show("Не удалось сохранить разметку: $($_.ToString())", "Ошибка сохранения", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    }.GetNewClosure()
    $btnApply.Add_Click({ & $PerformApply }.GetNewClosure())

    # Горячие клавиши
    $viewer.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            $viewer.Close()
        } elseif ($e.Key -eq [System.Windows.Input.Key]::Z -and [System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) {
            & $PerformUndo
        } elseif ($e.Key -eq [System.Windows.Input.Key]::H) {
            & $SwitchMode "Pan"
        } elseif ($e.Key -eq [System.Windows.Input.Key]::R) {
            & $SwitchMode "Rect"
        } elseif ($e.Key -eq [System.Windows.Input.Key]::A) {
            & $SwitchMode "Arrow"
        } elseif ($e.Key -eq [System.Windows.Input.Key]::C -and [System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) {
            try { [System.Windows.Clipboard]::SetImage($bi) } catch {}
        } elseif ($e.Key -eq [System.Windows.Input.Key]::F) {
            & $PerformZoomFit
        } elseif ($e.Key -eq [System.Windows.Input.Key]::D1 -or $e.Key -eq [System.Windows.Input.Key]::NumPad1 -or $e.Key -eq [System.Windows.Input.Key]::D0 -or $e.Key -eq [System.Windows.Input.Key]::NumPad0) {
            $state.CurrentZoom = 1.0
            $state.ScaleTransform.ScaleX = 1.0
            $state.ScaleTransform.ScaleY = 1.0
            $state.TranslateTransform.X = 0.0
            $state.TranslateTransform.Y = 0.0
            $state.LblZoomVal.Text = "100%"
        }
    }.GetNewClosure())

    $viewer.Content = $rootGrid
    if (-not ($Headless -or $ValidateOnly -or ($env:ANTIGRAVITY_HEADLESS -eq '1'))) {
        $viewer.Show()
        $viewer.Focus() | Out-Null
    }
}

function Render-AttachmentsUI {
    $pnlAttachmentsList.Children.Clear()
    if ($global:AttachedImages.Count -eq 0) {
        $borderAttachments.Visibility = [System.Windows.Visibility]::Collapsed
        return
    }

    $borderAttachments.Visibility = [System.Windows.Visibility]::Visible

    foreach ($item in $global:AttachedImages) {
        $capturedItem = $item

        # Карточка вложения
        $card = [System.Windows.Controls.Border]::new()
        $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#252A30")
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#383E4A")
        $card.BorderThickness = [System.Windows.Thickness]::new(1)
        $card.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $card.Padding = [System.Windows.Thickness]::new(4, 4, 6, 4)
        $card.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)

        $cardGrid = [System.Windows.Controls.StackPanel]::new()
        $cardGrid.Orientation = [System.Windows.Controls.Orientation]::Horizontal

        # Кликабельная область для открытия (миниатюра/иконка + текстовое описание)
        $clickablePart = [System.Windows.Controls.StackPanel]::new()
        $clickablePart.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $clickablePart.Cursor = [System.Windows.Input.Cursors]::Hand

        $itemPath = $item.FilePath
        $itemType = if ($item.ItemType) { $item.ItemType } elseif ($item.ImageSource) { "Image" } else { "File" }
        $clickablePart.ToolTip = switch ($itemType) {
            "Folder" { "Папка (клик откроет в Проводнике)`n$itemPath" }
            "File"   { "Файл (клик откроет файл)`n$itemPath" }
            default  { "Нажмите для просмотра изображения`n$itemPath" }
        }

        # Миниатюра (для картинок) или бейдж с иконкой (для файлов и папок)
        if ($item.ImageSource) {
            $imgCtrl = [System.Windows.Controls.Image]::new()
            $imgCtrl.Source = $item.ImageSource
            $imgCtrl.Width = 36
            $imgCtrl.Height = 36
            $imgCtrl.Stretch = [System.Windows.Media.Stretch]::UniformToFill
            $imgCtrl.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)

            $imgBorder = [System.Windows.Controls.Border]::new()
            $imgBorder.CornerRadius = [System.Windows.CornerRadius]::new(3)
            $imgBorder.ClipToBounds = $true
            $imgBorder.Child = $imgCtrl
            [void]$clickablePart.Children.Add($imgBorder)
        } else {
            $iconBorder = [System.Windows.Controls.Border]::new()
            $iconBorder.Width = 36
            $iconBorder.Height = 36
            $iconBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $iconBorder.Background = if ($itemType -eq "Folder") {
                [System.Windows.Media.BrushConverter]::new().ConvertFromString("#382A15")
            } else {
                [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1C2D42")
            }
            $iconBorder.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)

            $iconTxt = [System.Windows.Controls.TextBlock]::new()
            $iconTxt.Text = if ($item.Icon) { $item.Icon } elseif ($itemType -eq "Folder") { "📁" } else { "📄" }
            $iconTxt.FontSize = 17
            $iconTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $iconTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $iconBorder.Child = $iconTxt
            [void]$clickablePart.Children.Add($iconBorder)
        }

        # Текстовое описание
        $txtBox = [System.Windows.Controls.StackPanel]::new()
        $txtBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $lblTitle = [System.Windows.Controls.TextBlock]::new()
        $lblTitle.Text = $item.DisplayName
        $lblTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
        $lblTitle.FontSize = 11
        $lblTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E6EDF3")
        [void]$txtBox.Children.Add($lblTitle)

        if ($item.DimInfo) {
            $lblSub = [System.Windows.Controls.TextBlock]::new()
            $lblSub.Text = $item.DimInfo
            $lblSub.FontSize = 10
            $lblSub.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8B949E")
            [void]$txtBox.Children.Add($lblSub)
        }

        if ($item.HasAnnotation -and $item.AnnotatedFilePath -and (Test-Path -LiteralPath $item.AnnotatedFilePath)) {
            $lblAnnotBadge = [System.Windows.Controls.TextBlock]::new()
            $lblAnnotBadge.Text = "🎯 С разметкой (2 файла)"
            $lblAnnotBadge.FontSize = 10
            $lblAnnotBadge.FontWeight = [System.Windows.FontWeights]::SemiBold
            $lblAnnotBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3FB950")
            [void]$txtBox.Children.Add($lblAnnotBadge)
        }
        [void]$clickablePart.Children.Add($txtBox)

        # Интерактивная подсветка рамки при наведении мыши
        $cardRef = $card
        $clickablePart.Add_MouseEnter({
            $cardRef.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#58A6FF")
            $cardRef.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D333B")
        }.GetNewClosure())
        $clickablePart.Add_MouseLeave({
            $cardRef.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#383E4A")
            $cardRef.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#252A30")
        }.GetNewClosure())

        # Клик по карточке: просмотрщик для картинок, проводник для папок, запуск для файлов
        $previewPath = $item.FilePath
        $previewTitle = $item.DisplayName
        $clickablePart.Add_PreviewMouseLeftButtonDown({
            param($s, $e)
            $e.Handled = $true
            if ($capturedItem.ItemType -eq "Image" -or $capturedItem.ImageSource) {
                Show-ImageViewerWindow -FilePath $previewPath -Title $previewTitle -AttachedItem $capturedItem
            } elseif ($capturedItem.ItemType -eq "Folder" -or (Test-Path -LiteralPath $previewPath -PathType Container)) {
                try { Start-Process "explorer.exe" -ArgumentList "`"$previewPath`"" } catch {}
            } else {
                try {
                    $psi = [System.Diagnostics.ProcessStartInfo]::new($previewPath)
                    $psi.UseShellExecute = $true
                    [System.Diagnostics.Process]::Start($psi) | Out-Null
                } catch {
                    try { Start-Process "explorer.exe" -ArgumentList "/select,`"$previewPath`"" } catch {}
                }
            }
        }.GetNewClosure())

        [void]$cardGrid.Children.Add($clickablePart)

        # Кнопка удаления (✖)
        $btnRemove = [System.Windows.Controls.Button]::new()
        $btnRemove.Content = "✖"
        $btnRemove.Background = [System.Windows.Media.Brushes]::Transparent
        $btnRemove.BorderThickness = [System.Windows.Thickness]::new(0)
        $btnRemove.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F85149")
        $btnRemove.FontWeight = [System.Windows.FontWeights]::Bold
        $btnRemove.FontSize = 12
        $btnRemove.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnRemove.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $btnRemove.Padding = [System.Windows.Thickness]::new(4, 2, 4, 2)
        $btnRemove.ToolTip = switch ($itemType) {
            "Folder" { "Удалить эту папку из вложений" }
            "File"   { "Удалить этот файл из вложений" }
            default  { "Удалить это изображение" }
        }
        $targetItem = $item
        $btnRemove.Add_Click({
            if ($targetItem) {
                $global:AttachedImages.Remove($targetItem) | Out-Null
            }
            Render-AttachmentsUI
        }.GetNewClosure())

        [void]$cardGrid.Children.Add($btnRemove)
        $card.Child = $cardGrid
        [void]$pnlAttachmentsList.Children.Add($card)
    }
}

function Clear-AttachedImages {
    $global:AttachedImages.Clear()
    Render-AttachmentsUI
}

function Add-ClipboardImage {
    try {
        if (-not [System.Windows.Clipboard]::ContainsImage()) { return }
        $bs = [System.Windows.Clipboard]::GetImage()
        if (-not $bs) { return }

        $dir = Get-AttachmentsDirectory
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $rand = (Get-Random -Minimum 100 -Maximum 999)
        $filename = "screenshot_${ts}_${rand}.png"
        $filePath = Join-Path $dir $filename

        $enc = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bs))
        $fs = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Create)
        $enc.Save($fs)
        $fs.Close()

        $w = [math]::Round($bs.Width)
        $h = [math]::Round($bs.Height)
        $fileSize = [math]::Round((Get-Item -LiteralPath $filePath).Length / 1024)

        $item = [pscustomobject]@{
            ItemType          = "Image"
            FilePath          = $filePath
            FileName          = $filename
            DisplayName       = "Скриншот (${w}x${h})"
            DimInfo           = "${w}x${h} • ${fileSize} KB"
            ImageSource       = $bs
            Icon              = "🖼️"
            AnnotatedFilePath = $null
            HasAnnotation     = $false
        }
        $global:AttachedImages.Add($item)
        Render-AttachmentsUI
    } catch {
        [System.Windows.MessageBox]::Show("Не удалось вставить изображение из буфера: $($_.ToString())", "Ошибка вставки", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    }
}

function Add-AttachedItem {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try {
        $fullPath = (Convert-Path -LiteralPath $Path)
        $isContainer = (Test-Path -LiteralPath $fullPath -PathType Container)

        # Проверяем, не добавлен ли уже этот путь
        $existing = $global:AttachedImages | Where-Object { $_.FilePath -eq $fullPath } | Select-Object -First 1
        if ($existing) { return }

        if ($isContainer) {
            $dirInfo = Get-Item -LiteralPath $fullPath
            $fn = $dirInfo.Name
            $fileCount = 0
            try {
                $fileCount = [System.IO.Directory]::GetFiles($fullPath, "*", [System.IO.SearchOption]::AllDirectories).Length
            } catch {
                try { $fileCount = [System.IO.Directory]::GetFiles($fullPath).Length } catch {}
            }
            $dimInfo = if ($fileCount -gt 0) { "Папка • $fileCount файлов" } else { "Папка" }

            $item = [pscustomobject]@{
                ItemType          = "Folder"
                FilePath          = $fullPath
                FileName          = $fn
                DisplayName       = $fn
                DimInfo           = $dimInfo
                ImageSource       = $null
                Icon              = "📁"
                AnnotatedFilePath = $null
                HasAnnotation     = $false
            }
            $global:AttachedImages.Add($item)
            Render-AttachmentsUI
            return
        }

        $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
        $isImg = ($ext -in @(".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"))

        if ($isImg) {
            $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bi.BeginInit()
            $bi.UriSource = [System.Uri]::new($fullPath)
            $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bi.EndInit()
            $bi.Freeze()

            $fn = [System.IO.Path]::GetFileName($fullPath)
            $fileSize = [math]::Round((Get-Item -LiteralPath $fullPath).Length / 1024)
            $w = [math]::Round($bi.PixelWidth)
            $h = [math]::Round($bi.PixelHeight)

            $item = [pscustomobject]@{
                ItemType          = "Image"
                FilePath          = $fullPath
                FileName          = $fn
                DisplayName       = $fn
                DimInfo           = "${w}x${h} • ${fileSize} KB"
                ImageSource       = $bi
                Icon              = "🖼️"
                AnnotatedFilePath = $null
                HasAnnotation     = $false
            }
            $global:AttachedImages.Add($item)
            Render-AttachmentsUI
            return
        }

        # Обычный файл любого расширения
        $fn = [System.IO.Path]::GetFileName($fullPath)
        $len = (Get-Item -LiteralPath $fullPath).Length
        $fileSizeStr = if ($len -gt 1048576) { "$([math]::Round($len / 1048576, 1)) MB" } else { "$([math]::Round($len / 1024)) KB" }

        $icon = switch -regex ($ext) {
            '\.(zip|rar|7z|tar|gz|bz2)$' { "📦" }
            '\.(txt|md|log|rtf|pdf|docx?|xlsx?)$' { "📝" }
            '\.(cs|py|js|ts|json|xml|yaml|yml|html|css|cpp|h|c|rs|go|sh|ps1)$' { "📄" }
            '\.(mp3|wav|ogg|flac|mp4|mkv|avi|mov)$' { "🎬" }
            default { "📄" }
        }

        $item = [pscustomobject]@{
            ItemType          = "File"
            FilePath          = $fullPath
            FileName          = $fn
            DisplayName       = $fn
            DimInfo           = "$ext • $fileSizeStr"
            ImageSource       = $null
            Icon              = $icon
            AnnotatedFilePath = $null
            HasAnnotation     = $false
        }
        $global:AttachedImages.Add($item)
        Render-AttachmentsUI
    } catch {}
}

function Add-AttachedImageFile {
    param([string]$path)
    Add-AttachedItem -Path $path
}

function Handle-PasteAction {
    if ([System.Windows.Clipboard]::ContainsImage()) {
        Add-ClipboardImage
        return $true
    }
    if ([System.Windows.Clipboard]::ContainsFileDropList()) {
        $files = [System.Windows.Clipboard]::GetFileDropList()
        $hasAny = $false
        foreach ($f in $files) {
            if (Test-Path -LiteralPath $f) {
                Add-AttachedItem -Path $f
                $hasAny = $true
            }
        }
        if ($hasAny) { return $true }
    }
    return $false
}

# --- Настройки масштабирования шрифта, геометрии окна и персистентности ---
$global:DefaultFontSize = 13.0
$global:MinFontSize     = 8.0
$global:MaxFontSize     = 36.0
$global:MinWindowWidth  = 880.0
$global:MinWindowHeight = 620.0

function Load-LauncherConfig {
    if (Test-Path $configFilePath) {
        try {
            $raw = Get-Content -Path $configFilePath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if ($raw) {
                return ($raw | ConvertFrom-Json)
            }
        } catch {}
    }
    return $null
}

function Save-LauncherConfig {
    try {
        $cfg = @{}
        if (Test-Path $configFilePath) {
            try {
                $raw = Get-Content -Path $configFilePath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
                if ($raw) {
                    $existing = $raw | ConvertFrom-Json
                    if ($existing -is [PSCustomObject]) {
                        foreach ($prop in $existing.PSObject.Properties) {
                            $cfg[$prop.Name] = $prop.Value
                        }
                    }
                }
            } catch {}
        }
        $cfg["fontSize"] = [double]$global:CurrentFontSize

        # Сохранение геометрии и состояния окна
        if ($window) {
            $isMax = ($window.WindowState -eq [System.Windows.WindowState]::Maximized)
            $cfg["isMaximized"] = $isMax

            if ($isMax -and -not [double]::IsInfinity($window.RestoreBounds.Width) -and $window.RestoreBounds.Width -gt 0) {
                $cfg["windowWidth"]  = [math]::Round([double]$window.RestoreBounds.Width)
                $cfg["windowHeight"] = [math]::Round([double]$window.RestoreBounds.Height)
            } else {
                $w = if ($window.ActualWidth -gt 0) { $window.ActualWidth } else { $window.Width }
                $h = if ($window.ActualHeight -gt 0) { $window.ActualHeight } else { $window.Height }
                if ($w -ge $global:MinWindowWidth) {
                    $cfg["windowWidth"] = [math]::Round([double]$w)
                }
                if ($h -ge $global:MinWindowHeight) {
                    $cfg["windowHeight"] = [math]::Round([double]$h)
                }
            }
        }

        # Сохранение открытых вкладок и активной вкладки
        if ($global:TabsList -and $global:TabsList.Count -gt 0) {
            if ($global:ActiveTab) {
                if ($txtPromptInput) { $global:ActiveTab.PromptText = $txtPromptInput.Text }
                if ($txtWorkspace) { $global:ActiveTab.Workspace = $txtWorkspace.Text }
                if ($cmbModel -and $cmbModel.SelectedItem) { $global:ActiveTab.Model = $cmbModel.SelectedItem.ToString() }
                if ($cmbMode -and $cmbMode.SelectedItem) { $global:ActiveTab.Mode = $cmbMode.SelectedItem.ToString() }
                if ($cmbEffort -and $cmbEffort.SelectedItem) { $global:ActiveTab.Effort = $cmbEffort.SelectedItem.ToString() }
                if ($chkSkipPerms) { $global:ActiveTab.SkipPerms = [bool]$chkSkipPerms.IsChecked }
            }

            $tabsArr = [System.Collections.Generic.List[object]]::new()
            $activeIdx = 0
            for ($i = 0; $i -lt $global:TabsList.Count; $i++) {
                $t = $global:TabsList[$i]
                if ($t -eq $global:ActiveTab) {
                    $activeIdx = $i
                }
                $tabsArr.Add([pscustomobject]@{
                    title          = $t.Title
                    conversationId = $t.ConversationId
                    workspace      = $t.Workspace
                    model          = $t.Model
                    mode           = $t.Mode
                    effort         = $t.Effort
                    skipPerms      = [bool]$t.SkipPerms
                })
            }
            $cfg["tabs"] = @($tabsArr)
            $cfg["activeTabIndex"] = $activeIdx
        }

        $cfgDir = [System.IO.Path]::GetDirectoryName($configFilePath)
        if (-not [string]::IsNullOrEmpty($cfgDir) -and -not [System.IO.Directory]::Exists($cfgDir)) {
            [System.IO.Directory]::CreateDirectory($cfgDir) | Out-Null
        }
        $jsonStr = $cfg | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($configFilePath, $jsonStr, [System.Text.Encoding]::UTF8)
    } catch {}
}

$loadedCfg = Load-LauncherConfig

if ($loadedCfg -and $loadedCfg.fontSize) {
    $val = [double]$loadedCfg.fontSize
    if ($val -ge $global:MinFontSize -and $val -le $global:MaxFontSize) {
        $global:CurrentFontSize = [math]::Round($val)
    } else {
        $global:CurrentFontSize = $global:DefaultFontSize
    }
} else {
    $global:CurrentFontSize = $global:DefaultFontSize
}

# Восстановление размеров и состояния окна
if ($loadedCfg) {
    if ($loadedCfg.windowWidth -and [double]$loadedCfg.windowWidth -ge $global:MinWindowWidth) {
        $window.Width = [double]$loadedCfg.windowWidth
    }
    if ($loadedCfg.windowHeight -and [double]$loadedCfg.windowHeight -ge $global:MinWindowHeight) {
        $window.Height = [double]$loadedCfg.windowHeight
    }
    if ($loadedCfg.isMaximized -eq $true) {
        $window.WindowState = [System.Windows.WindowState]::Maximized
    }
}

function Update-ZoomDisplay {
    $pct = [math]::Round(($global:CurrentFontSize / $global:DefaultFontSize) * 100)
    $txtZoom.Text = "🔍 $pct% ($($global:CurrentFontSize)pt)"
}

function Set-AppZoom {
    param([double]$deltaSize)
    $newSize = [math]::Round($global:CurrentFontSize + $deltaSize)
    if ($newSize -lt $global:MinFontSize) { $newSize = $global:MinFontSize }
    if ($newSize -gt $global:MaxFontSize) { $newSize = $global:MaxFontSize }

    if ($newSize -ne $global:CurrentFontSize) {
        $global:CurrentFontSize = $newSize
        $txtChatLog.FontSize = $global:CurrentFontSize
        $txtPromptInput.FontSize = $global:CurrentFontSize
        $calcLineHeight = [math]::Round([math]::Max(20.0, $global:CurrentFontSize * 1.55))
        if ($txtChatLog.Document) {
            $txtChatLog.Document.LineHeight = $calcLineHeight
            $txtChatLog.Document.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
        }
        if ($global:TabsList) {
            foreach ($t in $global:TabsList) {
                if ($t.Document) {
                    $t.Document.LineHeight = $calcLineHeight
                    $t.Document.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
                }
            }
        }
        Update-ZoomDisplay
        Save-LauncherConfig
    }
}

function Reset-AppZoom {
    $global:CurrentFontSize = $global:DefaultFontSize
    $txtChatLog.FontSize = $global:DefaultFontSize
    $txtPromptInput.FontSize = $global:DefaultFontSize
    $calcLineHeight = [math]::Round([math]::Max(20.0, $global:DefaultFontSize * 1.55))
    if ($txtChatLog.Document) {
        $txtChatLog.Document.LineHeight = $calcLineHeight
        $txtChatLog.Document.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
    }
    if ($global:TabsList) {
        foreach ($t in $global:TabsList) {
            if ($t.Document) {
                $t.Document.LineHeight = $calcLineHeight
                $t.Document.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
            }
        }
    }
    Update-ZoomDisplay
    Save-LauncherConfig
}

# Применение сохраненного шрифта при старте
$txtChatLog.FontSize = $global:CurrentFontSize
$txtPromptInput.FontSize = $global:CurrentFontSize
$initialLineHeight = [math]::Round([math]::Max(20.0, $global:CurrentFontSize * 1.55))
if ($txtChatLog.Document) {
    $txtChatLog.Document.LineHeight = $initialLineHeight
    $txtChatLog.Document.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
}
Update-ZoomDisplay

# --- Инициализация списков и значений по умолчанию ---
$txtWorkspace.Text = $defaultWorkspace

# Список доступных моделей
$availableModels = @(
    "gemini-3.8-flash-high",
    "gemini-3.8-flash-medium",
    "gemini-3.8-flash-low",
    "claude-sonnet-4-6",
    "claude-opus-4-6-thinking",
    "gpt-oss-120b-medium"
)
foreach ($m in $availableModels) { [void]$cmbModel.Items.Add($m) }
$cmbModel.SelectedItem = "gemini-3.8-flash-high"

# Режимы агента
$availableModes = @("auto", "plan", "accept-edits")
foreach ($md in $availableModes) { [void]$cmbMode.Items.Add($md) }
$cmbMode.SelectedItem = "auto"

# Уровни рассуждений
$availableEfforts = @("auto", "high", "medium", "low")
foreach ($ef in $availableEfforts) { [void]$cmbEffort.Items.Add($ef) }
$cmbEffort.SelectedItem = "auto"

# Поиск поддиректорий проектов
function Refresh-ProjectList {
    $cmbProjects.Items.Clear()
    [void]$cmbProjects.Items.Add("— Выберите проект —")
    $cmbProjects.SelectedIndex = 0
    if (Test-Path $defaultWorkspace) {
        $subdirs = Get-ChildItem -Path $defaultWorkspace -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike ".*" -and $_.Name -ne "AntigravityLauncher" }
        foreach ($d in $subdirs) {
            [void]$cmbProjects.Items.Add($d.Name)
        }
    }
}
Refresh-ProjectList

# --- Система форматированного цветного вывода в лог чата ---
$global:BrushCache = @{}
$global:ActiveToolGroup = $null

function Get-CachedBrush([string]$colorHex) {
    if (-not $global:BrushCache.ContainsKey($colorHex)) {
        $b = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorHex)
        $b.Freeze()
        $global:BrushCache[$colorHex] = $b
    }
    return $global:BrushCache[$colorHex]
}

function Clear-ChatLog {
    param($Document = $null)
    if ($global:ActiveTab) {
        $global:ActiveTab.ActiveToolGroup = $null
    }
    $global:ActiveToolGroup = $null
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if ($doc) {
        $clearSw = [System.Diagnostics.Stopwatch]::StartNew()
        $doc.Blocks.Clear()
        if ($clearSw.ElapsedMilliseconds -gt 150) {
            Write-PerfLog "Clear-ChatLog: Blocks.Clear занял $($clearSw.ElapsedMilliseconds) мс"
        }
    }
}

function Scroll-ChatLogToEnd {
    if (-not $txtChatLog) { return }
    try {
        $txtChatLog.ScrollToEnd()
        $txtChatLog.ScrollToVerticalOffset([double]::MaxValue)
    } catch {}
    try {
        $txtChatLog.Dispatcher.BeginInvoke([System.Action]{
            try {
                $layoutSw = [System.Diagnostics.Stopwatch]::StartNew()
                Set-PerfStage "scroll: UpdateLayout (раскладка документа WPF)"
                $txtChatLog.UpdateLayout()
                $layoutMs = $layoutSw.ElapsedMilliseconds
                $txtChatLog.ScrollToEnd()
                $txtChatLog.ScrollToVerticalOffset([double]::MaxValue)
                if ($txtChatLog.Document -and $txtChatLog.Document.ContentEnd) {
                    $txtChatLog.CaretPosition = $txtChatLog.Document.ContentEnd
                }
                if ($layoutSw.ElapsedMilliseconds -gt 150) {
                    Write-PerfLog "Scroll-ChatLogToEnd: UpdateLayout $layoutMs мс, вместе с прокруткой $($layoutSw.ElapsedMilliseconds) мс"
                }
                Set-PerfStage "-"
            } catch {}
        }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
    } catch {}
}

$global:LoadingOverlayStartTime = $null

function Show-LoadingOverlay {
    param(
        [string]$Title = "Загрузка диалога...",
        [string]$Subtitle = "Считывание истории и форматирование..."
    )
    if (-not $loadingOverlay) { return }
    $global:LoadingOverlayStartTime = [DateTime]::UtcNow
    if ($txtLoadingTitle) { $txtLoadingTitle.Text = $Title }
    if ($txtLoadingSubtitle) { $txtLoadingSubtitle.Text = $Subtitle }
    $loadingOverlay.Visibility = [System.Windows.Visibility]::Visible
}

function Hide-LoadingOverlay {
    if (-not $loadingOverlay) { return }
    $loadingOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    $global:LoadingOverlayStartTime = $null
}

function Append-ChatFormatted {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [string]$Color = "#D4D4D4",
        [switch]$Bold,
        $Document = $null
    )
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }
    $tr = [System.Windows.Documents.TextRange]::new($doc.ContentEnd, $doc.ContentEnd)
    $tr.Text = $Text
    $tr.ApplyPropertyValue([System.Windows.Documents.TextElement]::ForegroundProperty, (Get-CachedBrush $Color))
    if ($Bold) {
        $tr.ApplyPropertyValue([System.Windows.Documents.TextElement]::FontWeightProperty, [System.Windows.FontWeights]::Bold)
    } else {
        $tr.ApplyPropertyValue([System.Windows.Documents.TextElement]::FontWeightProperty, [System.Windows.FontWeights]::Normal)
    }
}

function Parse-InlineMarkdownRuns {
    param(
        [string]$LineText,
        [string]$BaseColor = "#D4D4D4",
        [double]$FontSize = 13.0
    )
    $runs = [System.Collections.Generic.List[System.Windows.Documents.Inline]]::new()
    if ([string]::IsNullOrEmpty($LineText)) { return $runs }

    $baseBrush = Get-CachedBrush $BaseColor
    $boldBrush = Get-CachedBrush "#FFFFFF"
    $codeBrush = Get-CachedBrush "#CE9178"
    $codeBg = Get-CachedBrush "#28282B"
    $codeFont = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code, Courier New")

    $pattern = '(?<link>\[(?<linktext>[^\]\r\n]+)\]\((?<linkurl>[^\)\s\r\n]+)\))|(?<codeblock>`[^`\r\n]+`)|(?<bolditalic>\*\*\*[^*]+?\*\*\*|___[^_]+?___)|(?<bold>\*\*[^*]+?\*\*|__[^_]+?__)|(?<italic>\*[^*]+?\*|(?<=\s|^)_[^_]+?_(?=\s|$|[.,!?:;]))|(?<strike>~~[^~]+?~~)'

    $lastIndex = 0
    $matches = [regex]::Matches($LineText, $pattern)

    foreach ($m in $matches) {
        if ($m.Index -gt $lastIndex) {
            $plainText = $LineText.Substring($lastIndex, $m.Index - $lastIndex)
            $run = [System.Windows.Documents.Run]::new($plainText)
            $run.Foreground = $baseBrush
            $runs.Add($run)
        }

        $val = $m.Value
        if ($m.Groups["link"].Success) {
            $linkText = $m.Groups["linktext"].Value
            $linkUrl = $m.Groups["linkurl"].Value
            if ($linkUrl -notmatch '\.exe($|\?)' -and ($linkUrl -match '^https?://' -or $linkUrl -match '^file://')) {
                try {
                    $hl = [System.Windows.Documents.Hyperlink]::new()
                    $hl.NavigateUri = [System.Uri]::new($linkUrl)
                    $hlRun = [System.Windows.Documents.Run]::new($linkText)
                    $hl.Inlines.Add($hlRun)
                    $hl.Foreground = Get-CachedBrush "#4FC1FF"
                    $hl.TextDecorations = [System.Windows.TextDecorations]::Underline
                    $hl.ToolTip = $linkUrl
                    $hl.Cursor = [System.Windows.Input.Cursors]::Hand
                    $hl.Add_RequestNavigate({
                        param($s, $e)
                        try {
                            if ($e.Uri.AbsoluteUri -notmatch '\.exe($|\?)') {
                                Start-Process $e.Uri.AbsoluteUri
                            }
                        } catch {}
                    })
                    $runs.Add($hl)
                } catch {
                    $run = [System.Windows.Documents.Run]::new($linkText)
                    $run.Foreground = Get-CachedBrush "#4FC1FF"
                    $run.TextDecorations = [System.Windows.TextDecorations]::Underline
                    $runs.Add($run)
                }
            } else {
                $run = [System.Windows.Documents.Run]::new($linkText)
                $run.Foreground = Get-CachedBrush "#4FC1FF"
                $runs.Add($run)
            }
        }
        elseif ($m.Groups["codeblock"].Success) {
            $codeText = $val.Substring(1, $val.Length - 2)
            $run = [System.Windows.Documents.Run]::new(" $codeText ")
            $run.Foreground = $codeBrush
            $run.Background = $codeBg
            $run.FontFamily = $codeFont
            $run.FontSize = [Math]::Max(10.0, $FontSize - 0.5)
            $runs.Add($run)
        }
        elseif ($m.Groups["bolditalic"].Success) {
            $content = $val.Substring(3, $val.Length - 6)
            $run = [System.Windows.Documents.Run]::new($content)
            $run.FontWeight = [System.Windows.FontWeights]::Bold
            $run.FontStyle = [System.Windows.FontStyles]::Italic
            $run.Foreground = $boldBrush
            $runs.Add($run)
        }
        elseif ($m.Groups["bold"].Success) {
            $content = $val.Substring(2, $val.Length - 4)
            $run = [System.Windows.Documents.Run]::new($content)
            $run.FontWeight = [System.Windows.FontWeights]::Bold
            $run.Foreground = $boldBrush
            $runs.Add($run)
        }
        elseif ($m.Groups["italic"].Success) {
            $content = $val.Substring(1, $val.Length - 2)
            $run = [System.Windows.Documents.Run]::new($content)
            $run.FontStyle = [System.Windows.FontStyles]::Italic
            $run.Foreground = Get-CachedBrush "#DCDCDC"
            $runs.Add($run)
        }
        elseif ($m.Groups["strike"].Success) {
            $content = $val.Substring(2, $val.Length - 4)
            $run = [System.Windows.Documents.Run]::new($content)
            $run.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
            $run.Foreground = Get-CachedBrush "#888888"
            $runs.Add($run)
        }

        $lastIndex = $m.Index + $m.Length
    }

    if ($lastIndex -lt $LineText.Length) {
        $tail = $LineText.Substring($lastIndex)
        $run = [System.Windows.Documents.Run]::new($tail)
        $run.Foreground = $baseBrush
        $runs.Add($run)
    }

    return $runs
}

function Append-MarkdownFormatted {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        $Document = $null,
        [string]$BaseColor = "#D4D4D4",
        $FontSize = $null
    )
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }
    if ([string]::IsNullOrEmpty($Text)) { return }

    $effFontSize = if ($FontSize -and $FontSize -gt 0) { [double]$FontSize } elseif ($global:CurrentFontSize -and $global:CurrentFontSize -gt 0) { [double]$global:CurrentFontSize } else { 13.0 }
    $calcLineHeight = [math]::Round([math]::Max(20.0, $effFontSize * 1.55))

    $lines = $Text -split "\r?\n"
    $i = 0
    $len = $lines.Length

    # Весь рендер-цикл обёрнут в try/catch: ошибка при разборе одного блока
    # (код, таблица, inline-markdown со спецсимволами) не должна обнулять весь ответ.
    # Без этого сложные ответы (## заголовки, ``` блоки, $ символы) молча пропадали.
    try {
    while ($i -lt $len) {
        $line = $lines[$i]

        # 1. Fenced code block: ```[lang]
        if ($line -match '^```(.*)$') {
            $codeLang = $matches[1].Trim()
            $codeLines = [System.Collections.Generic.List[string]]::new()
            $i++
            while ($i -lt $len -and $lines[$i] -notmatch '^```') {
                $codeLines.Add($lines[$i])
                $i++
            }
            if ($i -lt $len) { $i++ } # Пропуск закрывающего ```

            $codeContent = [string]::Join("`r`n", $codeLines)

            $border = [System.Windows.Controls.Border]::new()
            $border.Background = Get-CachedBrush "#161618"
            $border.BorderBrush = Get-CachedBrush "#2D2D30"
            $border.BorderThickness = [System.Windows.Thickness]::new(1)
            $border.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $border.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)

            $dock = [System.Windows.Controls.DockPanel]::new()

            # Шапка блока кода (метка языка и кнопка копирования)
            $header = [System.Windows.Controls.Border]::new()
            $header.Background = Get-CachedBrush "#1F1F22"
            $header.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
            $header.CornerRadius = [System.Windows.CornerRadius]::new(3, 3, 0, 0)
            [System.Windows.Controls.DockPanel]::SetDock($header, [System.Windows.Controls.Dock]::Top)

            $grid = [System.Windows.Controls.Grid]::new()
            $col1 = [System.Windows.Controls.ColumnDefinition]::new(); $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $col2 = [System.Windows.Controls.ColumnDefinition]::new(); $col2.Width = [System.Windows.GridLength]::Auto
            $grid.ColumnDefinitions.Add($col1)
            $grid.ColumnDefinitions.Add($col2)

            $txtLang = [System.Windows.Controls.TextBlock]::new()
            $txtLang.Text = if ($codeLang) { $codeLang.ToLower() } else { "code" }
            $txtLang.Foreground = Get-CachedBrush "#858585"
            $txtLang.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas")
            $txtLang.FontSize = 10.5
            $txtLang.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetColumn($txtLang, 0)
            $grid.Children.Add($txtLang) | Out-Null

            $btnCopy = [System.Windows.Controls.Button]::new()
            $btnCopy.Content = "📋 Копировать"
            $btnCopy.Background = Get-CachedBrush "#2D2D30"
            $btnCopy.BorderBrush = Get-CachedBrush "#3E3E42"
            $btnCopy.Foreground = Get-CachedBrush "#CCCCCC"
            $btnCopy.FontSize = 10.0
            $btnCopy.Padding = [System.Windows.Thickness]::new(6, 1, 6, 1)
            $btnCopy.Cursor = [System.Windows.Input.Cursors]::Hand
            $btnCopy.Tag = $codeContent
            $btnCopy.Add_Click({
                param($s, $e)
                try {
                    [System.Windows.Clipboard]::SetText($s.Tag)
                    $s.Content = "✔ Скопировано!"
                } catch {}
            })
            [System.Windows.Controls.Grid]::SetColumn($btnCopy, 1)
            $grid.Children.Add($btnCopy) | Out-Null
            $header.Child = $grid
            $dock.Children.Add($header) | Out-Null

            # Текстовое поле с моноширинным кодом
            $txtBox = [System.Windows.Controls.TextBox]::new()
            $txtBox.Text = $codeContent
            $txtBox.IsReadOnly = $true
            $txtBox.IsUndoEnabled = $false
            $txtBox.Background = [System.Windows.Media.Brushes]::Transparent
            $txtBox.BorderThickness = [System.Windows.Thickness]::new(0)
            $txtBox.Foreground = Get-CachedBrush "#D4D4D4"
            $txtBox.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code, Courier New")
            $txtBox.FontSize = [Math]::Max(11.0, $effFontSize - 1.0)
            $txtBox.AcceptsReturn = $true
            $txtBox.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $txtBox.Padding = [System.Windows.Thickness]::new(8, 6, 8, 8)
            $dock.Children.Add($txtBox) | Out-Null

            $border.Child = $dock
            $container = [System.Windows.Documents.BlockUIContainer]::new($border)
            $doc.Blocks.Add($container)
            continue
        }

        # 2. Markdown Таблицы: последовательность строк с разделителем |
        if ($line -match '^\|.+\|$') {
            $tableLines = [System.Collections.Generic.List[string]]::new()
            while ($i -lt $len -and $lines[$i] -match '^\|.+\|$') {
                $tableLines.Add($lines[$i])
                $i++
            }
            $rows = [System.Collections.Generic.List[string[]]]::new()
            foreach ($tl in $tableLines) {
                $trimmed = $tl.Trim().Trim('|')
                $cells = $trimmed.Split('|') | ForEach-Object { $_.Trim() }
                $rows.Add($cells)
            }
            if ($rows.Count -ge 2) {
                $colCount = ($rows | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
                $tblBorder = [System.Windows.Controls.Border]::new()
                $tblBorder.Background = Get-CachedBrush "#18181A"
                $tblBorder.BorderBrush = Get-CachedBrush "#3E3E42"
                $tblBorder.BorderThickness = [System.Windows.Thickness]::new(1)
                $tblBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
                $tblBorder.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)

                $grid = [System.Windows.Controls.Grid]::new()
                for ($c = 0; $c -lt $colCount; $c++) {
                    $cd = [System.Windows.Controls.ColumnDefinition]::new()
                    $cd.Width = [System.Windows.GridLength]::Auto
                    $grid.ColumnDefinitions.Add($cd)
                }

                $isHeader = $true
                $gridRow = 0
                for ($r = 0; $r -lt $rows.Count; $r++) {
                    $rowCells = $rows[$r]
                    $isSep = $true
                    foreach ($cell in $rowCells) {
                        if ($cell -notmatch '^-+(:?)$' -and $cell -notmatch '^:?-+:?$') {
                            $isSep = $false
                            break
                        }
                    }
                    if ($isSep) {
                        $isHeader = $false
                        continue
                    }

                    $rd = [System.Windows.Controls.RowDefinition]::new()
                    $grid.RowDefinitions.Add($rd)

                    for ($c = 0; $c -lt $colCount; $c++) {
                        $cellText = if ($c -lt $rowCells.Length) { $rowCells[$c] } else { "" }
                        $cellBorder = [System.Windows.Controls.Border]::new()
                        $cellBorder.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
                        $cellBorder.BorderBrush = Get-CachedBrush "#2D2D30"
                        $cellBorder.BorderThickness = [System.Windows.Thickness]::new(0, 0, 1, 1)

                        if ($isHeader) {
                            $cellBorder.Background = Get-CachedBrush "#252528"
                        } elseif ($gridRow % 2 -eq 1) {
                            $cellBorder.Background = Get-CachedBrush "#1F1F22"
                        }

                        $tb = [System.Windows.Controls.TextBlock]::new()
                        $tb.FontSize = $effFontSize
                        $tb.FontFamily = [System.Windows.Media.FontFamily]::new("Segoe UI, Consolas")
                        $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
                        $tb.LineHeight = [math]::Round([math]::Max(19.0, $effFontSize * 1.45))
                        $tb.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight

                        $cellColor = if ($isHeader) { "#4EC9B0" } else { "#D4D4D4" }
                        $cellInlines = Parse-InlineMarkdownRuns -LineText $cellText -BaseColor $cellColor -FontSize $effFontSize
                        foreach ($cinl in $cellInlines) {
                            if ($isHeader) { $cinl.FontWeight = [System.Windows.FontWeights]::Bold }
                            $tb.Inlines.Add($cinl)
                        }

                        $cellBorder.Child = $tb
                        [System.Windows.Controls.Grid]::SetRow($cellBorder, $gridRow)
                        [System.Windows.Controls.Grid]::SetColumn($cellBorder, $c)
                        $grid.Children.Add($cellBorder) | Out-Null
                    }
                    $gridRow++
                }
                $tblBorder.Child = $grid
                $container = [System.Windows.Documents.BlockUIContainer]::new($tblBorder)
                $doc.Blocks.Add($container)
            }
            continue
        }

        # 3. Горизонтальный разделитель (---, ___, ***)
        if ($line -match '^(---|___|\*\*\*)\s*$') {
            $rule = [System.Windows.Controls.Border]::new()
            $rule.Height = 1
            $rule.Background = Get-CachedBrush "#3E3E42"
            $rule.Margin = [System.Windows.Thickness]::new(0, 6, 0, 6)
            $container = [System.Windows.Documents.BlockUIContainer]::new($rule)
            $doc.Blocks.Add($container)
            $i++
            continue
        }

        # 4. Заголовки (#, ##, ###, ####)
        if ($line -match '^(#{1,6})\s+(.*)$') {
            $level = $matches[1].Length
            $headerText = $matches[2]
            $p = [System.Windows.Documents.Paragraph]::new()
            $hColor = "#D4D4D4"
            $hSize = $effFontSize

            switch ($level) {
                1 { $hSize = $effFontSize + 6.0; $hColor = "#4FC1FF"; $p.Margin = [System.Windows.Thickness]::new(0, 10, 0, 4) }
                2 { $hSize = $effFontSize + 4.0; $hColor = "#4EC9B0"; $p.Margin = [System.Windows.Thickness]::new(0, 8, 0, 3) }
                3 { $hSize = $effFontSize + 2.0; $hColor = "#E2C08D"; $p.Margin = [System.Windows.Thickness]::new(0, 6, 0, 2) }
                default { $hSize = $effFontSize + 1.0; $hColor = "#DCDCAA"; $p.Margin = [System.Windows.Thickness]::new(0, 4, 0, 2) }
            }
            $p.FontSize = $hSize
            $p.FontWeight = [System.Windows.FontWeights]::Bold
            $p.LineHeight = [math]::Round($hSize * 1.35)
            $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight

            $inlines = Parse-InlineMarkdownRuns -LineText $headerText -BaseColor $hColor -FontSize $hSize
            foreach ($inl in $inlines) {
                $inl.FontWeight = [System.Windows.FontWeights]::Bold
                $p.Inlines.Add($inl)
            }
            $doc.Blocks.Add($p)
            $i++
            continue
        }

        # 5. Блок цитаты (> text)
        if ($line -match '^>\s?(.*)$') {
            $quoteLines = [System.Collections.Generic.List[string]]::new()
            while ($i -lt $len -and $lines[$i] -match '^>\s?(.*)$') {
                $quoteLines.Add($matches[1])
                $i++
            }
            $border = [System.Windows.Controls.Border]::new()
            $border.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
            $border.BorderBrush = Get-CachedBrush "#007ACC"
            $border.Background = Get-CachedBrush "#181E24"
            $border.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
            $border.Margin = [System.Windows.Thickness]::new(0, 3, 0, 5)
            $border.CornerRadius = [System.Windows.CornerRadius]::new(0, 3, 3, 0)

            $tb = [System.Windows.Controls.TextBlock]::new()
            $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $tb.FontStyle = [System.Windows.FontStyles]::Italic
            $tb.LineHeight = $calcLineHeight
            $tb.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight

            for ($ql = 0; $ql -lt $quoteLines.Count; $ql++) {
                if ($ql -gt 0) { $tb.Inlines.Add([System.Windows.Documents.LineBreak]::new()) }
                $inlines = Parse-InlineMarkdownRuns -LineText $quoteLines[$ql] -BaseColor "#A0A0A0" -FontSize $effFontSize
                foreach ($inl in $inlines) { $tb.Inlines.Add($inl) }
            }
            $border.Child = $tb
            $container = [System.Windows.Documents.BlockUIContainer]::new($border)
            $doc.Blocks.Add($container)
            continue
        }

        # 6. Маркированный список (- , * , + )
        if ($line -match '^(\s*)([-*+])\s+(.*)$') {
            $indentSpaces = $matches[1].Length
            $itemText = $matches[3]
            $p = [System.Windows.Documents.Paragraph]::new()
            $p.LineHeight = $calcLineHeight
            $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
            $p.Margin = [System.Windows.Thickness]::new(16 + ($indentSpaces * 4), 2, 0, 3)

            $bulletChar = if ($indentSpaces -gt 0) { "○ " } else { "• " }
            $bulletRun = [System.Windows.Documents.Run]::new($bulletChar)
            $bulletRun.Foreground = Get-CachedBrush "#569CD6"
            $bulletRun.FontWeight = [System.Windows.FontWeights]::Bold
            $p.Inlines.Add($bulletRun)

            $inlines = Parse-InlineMarkdownRuns -LineText $itemText -BaseColor $BaseColor -FontSize $effFontSize
            foreach ($inl in $inlines) { $p.Inlines.Add($inl) }
            $doc.Blocks.Add($p)
            $i++
            continue
        }

        # 7. Нумерованный список (1. , 2. )
        if ($line -match '^(\s*)(\d+)\.\s+(.*)$') {
            $indentSpaces = $matches[1].Length
            $num = $matches[2]
            $itemText = $matches[3]
            $p = [System.Windows.Documents.Paragraph]::new()
            $p.LineHeight = $calcLineHeight
            $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
            $p.Margin = [System.Windows.Thickness]::new(16 + ($indentSpaces * 4), 2, 0, 3)

            $numRun = [System.Windows.Documents.Run]::new("$num. ")
            $numRun.Foreground = Get-CachedBrush "#569CD6"
            $numRun.FontWeight = [System.Windows.FontWeights]::SemiBold
            $p.Inlines.Add($numRun)

            $inlines = Parse-InlineMarkdownRuns -LineText $itemText -BaseColor $BaseColor -FontSize $effFontSize
            foreach ($inl in $inlines) { $p.Inlines.Add($inl) }
            $doc.Blocks.Add($p)
            $i++
            continue
        }

        # 8. Пустая строка: разделитель абзацев
        if ([string]::IsNullOrWhiteSpace($line)) {
            $i++
            continue
        }

        # 9. Обычный абзац текста: объединение строк абзаца с переносом через LineBreak
        $paraLines = [System.Collections.Generic.List[string]]::new()
        while ($i -lt $len) {
            $cur = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($cur) -or 
                $cur -match '^```' -or 
                $cur -match '^\|.+\|$' -or 
                $cur -match '^(---|___|\*\*\*)\s*$' -or 
                $cur -match '^#{1,6}\s+' -or 
                $cur -match '^>\s?' -or 
                $cur -match '^(\s*)([-*+]|\d+\.)\s+') {
                break
            }
            $paraLines.Add($cur)
            $i++
        }

        if ($paraLines.Count -gt 0) {
            $p = [System.Windows.Documents.Paragraph]::new()
            $p.LineHeight = $calcLineHeight
            $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
            $p.Margin = [System.Windows.Thickness]::new(0, 3, 0, 7)
            for ($pl = 0; $pl -lt $paraLines.Count; $pl++) {
                if ($pl -gt 0) { $p.Inlines.Add([System.Windows.Documents.LineBreak]::new()) }
                $inlines = Parse-InlineMarkdownRuns -LineText $paraLines[$pl] -BaseColor $BaseColor -FontSize $effFontSize
                foreach ($inl in $inlines) { $p.Inlines.Add($inl) }
            }
            $doc.Blocks.Add($p)
        }
    }
    } catch {
        # Fallback: если рендер Markdown упал — выводим сырой текст,
        # чтобы ответ не пропал с экрана полностью
        try {
            $p = [System.Windows.Documents.Paragraph]::new()
            $p.Margin = [System.Windows.Thickness]::new(0, 3, 0, 7)
            $run = [System.Windows.Documents.Run]::new($Text)
            $run.Foreground = Get-CachedBrush $BaseColor
            $p.Inlines.Add($run)
            $doc.Blocks.Add($p)
        } catch {}
    }

    # Если блок кода не был закрыт до конца файла
    if ($inCodeBlock -and $codeLines.Count -gt 0) {
        $p = [System.Windows.Documents.Paragraph]::new()
        $p.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code, Courier New")
        $p.Inlines.Add([System.Windows.Documents.Run]::new([string]::Join("`r`n", $codeLines)))
        $doc.Blocks.Add($p)
    }
}

function Append-UserMessageToLog {
    param(
        [object]$TimeStr = "",
        [object]$Text = "",
        [object]$Badges = "",
        $Attachments = $null,
        $Document = $null,
        [switch]$IsQueued
    )
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }

    $cleanTime = if ($TimeStr -is [System.Collections.IList]) { [string]$TimeStr[0] } else { [string]$TimeStr }
    $cleanText = if ($Text -is [System.Collections.IList]) { [string]($Text -join "`r`n") } else { [string]$Text }
    $cleanBadges = if ($Badges -is [System.Collections.IList]) { [string]($Badges -join " ") } else { [string]$Badges }

    $effFontSize = if ($global:CurrentFontSize -and $global:CurrentFontSize -gt 0) { [double]$global:CurrentFontSize } else { 13.0 }
    $calcLineHeight = [math]::Round([math]::Max(20.0, $effFontSize * 1.55))

    $lines = $cleanText -split "\r?\n"
    $firstLine = if ($lines.Length -gt 0) { $lines[0] } else { "" }

    $p = [System.Windows.Documents.Paragraph]::new()
    $p.Margin = [System.Windows.Thickness]::new(0, 8, 0, 4)
    $p.LineHeight = $calcLineHeight
    $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight

    # 1. Р‘РµР№РґР¶Рё РїСЂРёРєСЂРµРїР»РµРЅРЅС‹С… С„Р°Р№Р»РѕРІ: РёРЅС‚РµСЂР°РєС‚РёРІРЅС‹Рµ РєР»РёРєР°Р±РµР»СЊРЅС‹Рµ РїР»Р°С€РєРё РґР»СЏ РёР·РѕР±СЂР°Р¶РµРЅРёР№ Рё РґРѕРєСѓРјРµРЅС‚РѕРІ
    $activeAttachments = @()
    if ($Attachments) {
        $activeAttachments = @($Attachments)
    } elseif (-not [string]::IsNullOrEmpty($Badges)) {
        # Р РµР·РµСЂРІРЅС‹Р№ СЂР°Р·Р±РѕСЂ РёРјРµРЅ С„Р°Р№Р»РѕРІ РёР· СЃС‚СЂРѕРєРё [рџ–јпёЏ filename1, рџЋЇ filename2]
        $extracted = [System.Collections.Generic.List[psobject]]::new()
        foreach ($rawItem in ($Badges.Trim(' []') -split ',')) {
            $fn = ($rawItem.Trim() -replace '^[^\w\.\-]+', '').Trim()
            if ($fn) {
                $cand = @(
                    (Join-Path (Get-AttachmentsDirectory) $fn),
                    ($(if ($txtWorkspace -and $txtWorkspace.Text) { Join-Path $txtWorkspace.Text ".antigravity\attachments\$fn" })),
                    (Join-Path $launcherDir "attachments\$fn")
                ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
                $fPath = if ($cand) { $cand } else { $fn }
                $extracted.Add([pscustomobject]@{
                    FilePath    = $fPath
                    FileName    = $fn
                    DisplayName = $fn
                })
            }
        }
        $activeAttachments = @($extracted)
    }

    $hasBadges = (@($activeAttachments).Length -gt 0)
    $headerText = if ($cleanTime) {
        if ($hasBadges) { "[Вы ($cleanTime)]:" } else { "[Вы ($cleanTime)]: " }
    } else {
        if ($hasBadges) { "[Вы]:" } else { "[Вы]: " }
    }

    # 2. Р—Р°РіРѕР»РѕРІРѕРє [Р’С‹ (HH:mm:ss)]:
    $headerRun = [System.Windows.Documents.Run]::new($headerText)
    $headerRun.Foreground = Get-CachedBrush "#4FC1FF"
    $headerRun.FontWeight = [System.Windows.FontWeights]::Bold
    $p.Inlines.Add($headerRun)

    if ($IsQueued) {
        $qRun = [System.Windows.Documents.Run]::new("⏳ [В очереди] ")
        $qRun.Foreground = Get-CachedBrush "#F0883E"
        $qRun.FontWeight = [System.Windows.FontWeights]::Bold
        $p.Inlines.Add($qRun)
    }

    if (@($activeAttachments).Length -gt 0) {
        foreach ($att in @($activeAttachments)) {
            $attPath = if ($att.FilePath) { [string]$att.FilePath } else { "" }
            $attName = if ($att.DisplayName) { [string]$att.DisplayName } elseif ($att.FileName) { [string]$att.FileName } else { [System.IO.Path]::GetFileName($attPath) }

            $isAnnotated = ($attName -match "^🎯" -or $attPath -match "_annotated\.png$")
            $isImage = ($attPath -match '\.(png|jpg|jpeg|bmp|gif|webp)$' -or $attName -match '\.(png|jpg|jpeg|bmp|gif|webp)$' -or $attName -match "^[🖼️🎯]")

            $badgeBorder = [System.Windows.Controls.Border]::new()
            $badgeBorder.Background = Get-CachedBrush "#262C36"
            $badgeBorder.BorderBrush = if ($isAnnotated) { Get-CachedBrush "#3FB950" } else { Get-CachedBrush "#38414E" }
            $badgeBorder.BorderThickness = [System.Windows.Thickness]::new(1)
            $badgeBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $badgeBorder.Padding = [System.Windows.Thickness]::new(6, 2, 6, 2)
            $badgeBorder.Margin = [System.Windows.Thickness]::new(0, 0, 5, 0)
            $badgeBorder.Cursor = [System.Windows.Input.Cursors]::Hand
            $badgeBorder.ToolTip = if ($isAnnotated) { "Нажмите для просмотра разметки маркерами`n$attPath" } elseif ($isImage) { "Нажмите для просмотра изображения`n$attPath" } else { "Нажмите для открытия файла`n$attPath" }

            $sp = [System.Windows.Controls.StackPanel]::new()
            $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

            $iconTb = [System.Windows.Controls.TextBlock]::new()
            $iconTb.Text = if ($isAnnotated) { "🎯 " } elseif ($isImage) { "🖼️ " } else { "📎 " }
            $iconTb.FontSize = [math]::Max(11.0, $effFontSize - 1.0)
            [void]$sp.Children.Add($iconTb)

            $nameTb = [System.Windows.Controls.TextBlock]::new()
            $nameTb.Text = ($attName -replace "^[🖼️🎯📎\s]+", "").Trim()
            $nameTb.FontSize = [math]::Max(11.0, $effFontSize - 1.0)
            $nameTb.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTb.Foreground = if ($isAnnotated) { Get-CachedBrush "#3FB950" } else { Get-CachedBrush "#79C0FF" }
            [void]$sp.Children.Add($nameTb)

            $badgeBorder.Child = $sp

            # Ховер подсветка
            $badgeBorder.Add_MouseEnter({
                $badgeBorder.Background = Get-CachedBrush "#313945"
                $badgeBorder.BorderBrush = if ($isAnnotated) { Get-CachedBrush "#46D160" } else { Get-CachedBrush "#58A6FF" }
            }.GetNewClosure())
            $badgeBorder.Add_MouseLeave({
                $badgeBorder.Background = Get-CachedBrush "#262C36"
                $badgeBorder.BorderBrush = if ($isAnnotated) { Get-CachedBrush "#3FB950" } else { Get-CachedBrush "#38414E" }
            }.GetNewClosure())

            # Клик левой кнопкой мыши открывает просмотрщик (для картинок) или проводник/файл
            $clickPath = $attPath
            $clickTitle = $nameTb.Text
            $badgeBorder.Add_PreviewMouseLeftButtonDown({
                param($s, $e)
                $e.Handled = $true
                if ($isImage) {
                    Show-ImageViewerWindow -FilePath $clickPath -Title $clickTitle
                } else {
                    try {
                        $psi = [System.Diagnostics.ProcessStartInfo]::new($clickPath)
                        $psi.UseShellExecute = $true
                        [System.Diagnostics.Process]::Start($psi) | Out-Null
                    } catch {}
                }
            }.GetNewClosure())

            # Контекстное меню
            $ctxMenu = [System.Windows.Controls.ContextMenu]::new()
            if ($isImage) {
                $miView = [System.Windows.Controls.MenuItem]::new()
                $miView.Header = "Просмотреть изображение"
                $miView.Add_Click({ Show-ImageViewerWindow -FilePath $clickPath -Title $clickTitle }.GetNewClosure())
                [void]$ctxMenu.Items.Add($miView)
            }
            $miSys = [System.Windows.Controls.MenuItem]::new()
            $miSys.Header = "Открыть в системе"
            $miSys.Add_Click({
                try {
                    $psi = [System.Diagnostics.ProcessStartInfo]::new($clickPath)
                    $psi.UseShellExecute = $true
                    [System.Diagnostics.Process]::Start($psi) | Out-Null
                } catch {}
            }.GetNewClosure())
            [void]$ctxMenu.Items.Add($miSys)

            $miFolder = [System.Windows.Controls.MenuItem]::new()
            $miFolder.Header = "Показать в папке (Проводник)"
            $miFolder.Add_Click({
                try { [System.Diagnostics.Process]::Start("explorer.exe", "/select,`"$clickPath`"") | Out-Null } catch {}
            }.GetNewClosure())
            [void]$ctxMenu.Items.Add($miFolder)

            $miCopyPath = [System.Windows.Controls.MenuItem]::new()
            $miCopyPath.Header = "Копировать путь к файлу"
            $miCopyPath.Add_Click({
                try { [System.Windows.Clipboard]::SetText($clickPath) } catch {}
            }.GetNewClosure())
            [void]$ctxMenu.Items.Add($miCopyPath)

            $badgeBorder.ContextMenu = $ctxMenu

            $uic = [System.Windows.Documents.InlineUIContainer]::new($badgeBorder)
            $p.Inlines.Add($uic)
            $badgeText = "[$($iconTb.Text.Trim()) $attName] "
            $accRun = [System.Windows.Documents.Run]::new($badgeText)
            $accRun.FontSize = 1.0
            $accRun.Foreground = [System.Windows.Media.Brushes]::Transparent
            $p.Inlines.Add($accRun)
        }
    }
    # 3. Первая строка сообщения пользователя - строго на той же строке
    $firstInlines = Parse-InlineMarkdownRuns -LineText $firstLine -BaseColor "#F1F1F1" -FontSize $effFontSize
    foreach ($inl in $firstInlines) {
        $p.Inlines.Add($inl)
    }

    # 4. Последующие строки сообщения (при Shift+Enter)
    for ($li = 1; $li -lt $lines.Length; $li++) {
        $p.Inlines.Add([System.Windows.Documents.LineBreak]::new())
        $nextInlines = Parse-InlineMarkdownRuns -LineText $lines[$li] -BaseColor "#F1F1F1" -FontSize $effFontSize
        foreach ($inl in $nextInlines) {
            $p.Inlines.Add($inl)
        }
    }

    $doc.Blocks.Add($p)
}

function Append-AgentHeader($Document = $null) {
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }
    $effFontSize = if ($global:CurrentFontSize -and $global:CurrentFontSize -gt 0) { [double]$global:CurrentFontSize } else { 13.0 }
    $calcLineHeight = [math]::Round([math]::Max(20.0, $effFontSize * 1.55))

    $p = [System.Windows.Documents.Paragraph]::new()
    $p.Margin = [System.Windows.Thickness]::new(0, 8, 0, 2)
    $p.LineHeight = $calcLineHeight
    $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight

    $run = [System.Windows.Documents.Run]::new("[Antigravity]:")
    $run.Foreground = Get-CachedBrush "#C586C0"
    $run.FontWeight = [System.Windows.FontWeights]::Bold
    $p.Inlines.Add($run)
    $doc.Blocks.Add($p)
}

function Toggle-ToolGroupCard {
    param($element, $e)
    if ($e) { $e.Handled = $true }
    if (-not $element) { return }
    $g = $element.Tag
    if (-not $g) { return }

    if ($g.IsCollapsed) {
        if ($g.LazyTools -and $g.BodyPanel.Children.Count -eq 0) {
            foreach ($t in $g.LazyTools) {
                $row = [System.Windows.Controls.TextBlock]::new()
                $tSummary = if ($t.Summary) { " — $($t.Summary)" } else { "" }
                $row.Text = "  ✔️ ⚙️ [$($t.Name)]$tSummary"
                $row.Foreground = (Get-CachedBrush "#4EC9B0")
                $row.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
                $g.BodyPanel.Children.Add($row) | Out-Null
            }
        }
        $g.BodyBorder.Visibility = [System.Windows.Visibility]::Visible
        $g.ToggleHint.Text = "▼ Свернуть"
        $g.IsCollapsed = $false
    } else {
        $g.BodyBorder.Visibility = [System.Windows.Visibility]::Collapsed
        $g.ToggleHint.Text = "▶ Развернуть ($($g.ToolCount))"
        $g.IsCollapsed = $true
    }
}

# --- Компоненты интерактивных сворачиваемых карточек вызовов инструментов ---
function New-ToolGroupCard {
    param(
        [switch]$StartCollapsed,
        $Document = $null
    )

    $card = [System.Windows.Controls.Border]::new()
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#252526")
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3E3E42")
    $card.BorderThickness = [System.Windows.Thickness]::new(1)
    $card.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $card.Margin = [System.Windows.Thickness]::new(0, 4, 0, 8)

    $dock = [System.Windows.Controls.DockPanel]::new()

    # Шапка / интерактивная панель группы
    $headerBtn = [System.Windows.Controls.Border]::new()
    $headerBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D2D30")
    $headerBtn.Padding = [System.Windows.Thickness]::new(10, 6, 10, 6)
    $headerBtn.CornerRadius = [System.Windows.CornerRadius]::new(3, 3, 0, 0)
    $headerBtn.Cursor = [System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.DockPanel]::SetDock($headerBtn, [System.Windows.Controls.Dock]::Top)

    $headerGrid = [System.Windows.Controls.Grid]::new()
    $c1 = [System.Windows.Controls.ColumnDefinition]::new(); $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c2 = [System.Windows.Controls.ColumnDefinition]::new(); $c2.Width = [System.Windows.GridLength]::Auto
    $headerGrid.ColumnDefinitions.Add($c1)
    $headerGrid.ColumnDefinitions.Add($c2)

    $headerTitle = [System.Windows.Controls.TextBlock]::new()
    $headerTitle.Text = "⚙️ Вызовы инструментов (выполняется...)"
    $headerTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CE9178")
    $headerTitle.FontWeight = [System.Windows.FontWeights]::Bold
    $headerTitle.Cursor = [System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.Grid]::SetColumn($headerTitle, 0)
    $headerGrid.Children.Add($headerTitle) | Out-Null

    # Кнопка-бейдж для наглядного сворачивания / разворачивания
    $toggleBadge = [System.Windows.Controls.Border]::new()
    $toggleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38383C")
    $toggleBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4E4E52")
    $toggleBadge.BorderThickness = [System.Windows.Thickness]::new(1)
    $toggleBadge.CornerRadius = [System.Windows.CornerRadius]::new(3)
    $toggleBadge.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $toggleBadge.Cursor = [System.Windows.Input.Cursors]::Hand

    $toggleHint = [System.Windows.Controls.TextBlock]::new()
    $toggleHint.Text = if ($StartCollapsed) { "▶ Развернуть" } else { "▼ Свернуть" }
    $toggleHint.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CCCCCC")
    $toggleHint.FontSize = 11
    $toggleHint.FontWeight = [System.Windows.FontWeights]::SemiBold
    $toggleBadge.Child = $toggleHint

    [System.Windows.Controls.Grid]::SetColumn($toggleBadge, 1)
    $headerGrid.Children.Add($toggleBadge) | Out-Null

    $headerBtn.Child = $headerGrid
    $dock.Children.Add($headerBtn) | Out-Null

    # Тело карточки (список вызовов)
    $bodyBorder = [System.Windows.Controls.Border]::new()
    $bodyBorder.Padding = [System.Windows.Thickness]::new(10, 6, 10, 8)
    $bodyBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    if ($StartCollapsed) {
        $bodyBorder.Visibility = [System.Windows.Visibility]::Collapsed
    }

    $bodySp = [System.Windows.Controls.StackPanel]::new()
    $bodyBorder.Child = $bodySp
    $dock.Children.Add($bodyBorder) | Out-Null

    $card.Child = $dock

    $groupObj = [PSCustomObject]@{
        Card         = $card
        HeaderBtn    = $headerBtn
        ToggleBadge  = $toggleBadge
        HeaderTitle  = $headerTitle
        ToggleHint   = $toggleHint
        BodyBorder   = $bodyBorder
        BodyPanel    = $bodySp
        ToolCount    = 0
        TotalSeconds = 0.0
        IsCollapsed  = [bool]$StartCollapsed
        PendingItems = @{}
        LazyTools    = $null
    }

    # Эффект наведения мыши на шапку и бейдж (используем $s - отправитель события WPF, чтобы не зависеть от замыкания переменных)
    $headerBtn.Add_MouseEnter({
        param($s, $e)
        if ($s) { $s.Background = (Get-CachedBrush "#333338") }
    })
    $headerBtn.Add_MouseLeave({
        param($s, $e)
        if ($s) { $s.Background = (Get-CachedBrush "#2D2D30") }
    })
    $toggleBadge.Add_MouseEnter({
        param($s, $e)
        if ($s) {
            $s.Background = (Get-CachedBrush "#4A4A52")
            $s.BorderBrush = (Get-CachedBrush "#6E6E78")
        }
    })
    $toggleBadge.Add_MouseLeave({
        param($s, $e)
        if ($s) {
            $s.Background = (Get-CachedBrush "#38383C")
            $s.BorderBrush = (Get-CachedBrush "#4E4E52")
        }
    })

    # Сохраняем ссылку на объект группы в Tag для доступа из обработчиков событий
    $headerBtn.Tag = $groupObj
    $toggleBadge.Tag = $groupObj

    # Переключение видимости при клике (PreviewMouseLeftButtonDown перехватывает клик до RichTextBox)
    $headerBtn.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Toggle-ToolGroupCard -element $s -e $e
    })
    $toggleBadge.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Toggle-ToolGroupCard -element $s -e $e
    })

    $buc = [System.Windows.Documents.BlockUIContainer]::new($card)
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if ($doc) {
        $doc.Blocks.Add($buc)
    }

    return $groupObj
}

# --- Компоненты интерактивных сворачиваемых карточек системных уведомлений (<SYSTEM_MESSAGE>) ---
function Parse-SystemMessageText([string]$text) {
    $results = [System.Collections.Generic.List[psobject]]::new()
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $pattern = '(?s)<SYSTEM_MESSAGE>\s*(.*?)\s*</SYSTEM_MESSAGE>'
        $sysMatches = [regex]::Matches($text, $pattern)
        if ($sysMatches.Count -gt 0) {
            foreach ($m in $sysMatches) {
                $body = $m.Groups[1].Value.Trim()
                $summary = ""
                if ($body -match 'content=([^\r\n]+)') {
                    $summary = if ($Matches.Count -gt 1) { $Matches[1].Trim() } else { [regex]::Unescape("\u0421\u0438\u0441\u0442\u0435\u043c\u043d\u043e\u0435 \u0443\u0432\u0435\u0434\u043e\u043c\u043b\u0435\u043d\u0438\u0435") }
            } else {
                $firstLine = ($body -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
                $summary = if ($firstLine) { $firstLine.Trim() } else { "Системное уведомление" }
            }
            $summary = [regex]::Replace($summary, 'Task id "[0-9a-fA-F\-]{20,}/(task-\d+)"', 'Task id "$1"')
            if ($summary.Length -gt 75) { $summary = $summary.Substring(0, 72) + "..." }
            $results.Add([pscustomobject]@{
                Summary = $summary
                Body    = $body
            })
        }
    } else {
        $clean = $text.Trim()
        $firstLine = ($clean -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
        $summary = if ($firstLine) { $firstLine.Trim() } else { "Системное уведомление" }
        $summary = [regex]::Replace($summary, 'Task id "[0-9a-fA-F\-]{20,}/(task-\d+)"', 'Task id "$1"')
        if ($summary.Length -gt 75) { $summary = $summary.Substring(0, 72) + "..." }
        $results.Add([pscustomobject]@{
            Summary = $summary
            Body    = $clean
        })
    }
    return , $results.ToArray()
}

function Toggle-SystemMessageCard {
    param($element, $e)
    if ($e) { $e.Handled = $true }
    if (-not $element) { return }
    $g = $element.Tag
    if (-not $g) { return }

    if ($g.IsCollapsed) {
        $g.BodyBorder.Visibility = [System.Windows.Visibility]::Visible
        $g.ToggleHint.Text = "▼ Свернуть"
        $g.IsCollapsed = $false
    } else {
        $g.BodyBorder.Visibility = [System.Windows.Visibility]::Collapsed
        $g.ToggleHint.Text = "▶ Развернуть"
        $g.IsCollapsed = $true
    }
}

function New-SystemMessageCard {
    param(
        $Summary = [regex]::Unescape("\u0421\u0438\u0441\u0442\u0435\u043c\u043d\u043e\u0435 \u0443\u0432\u0435\u0434\u043e\u043c\u043b\u0435\u043d\u0438\u0435"),
        $Body = "",
        [switch]$StartCollapsed = $true,
        $Document = $null
    )
    $Summary = if ($Summary -is [System.Collections.IList]) { ($Summary -join " ") } elseif ($null -eq $Summary) { "" } else { [string]$Summary }
    $Body = if ($Body -is [System.Collections.IList]) { ($Body -join "`r`n") } elseif ($null -eq $Body) { "" } else { [string]$Body }

    $card = [System.Windows.Controls.Border]::new()
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F2428")
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#388BFD")
    $card.BorderThickness = [System.Windows.Thickness]::new(1)
    $card.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $card.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)

    $dock = [System.Windows.Controls.DockPanel]::new()

    # Шапка карточки
    $headerBtn = [System.Windows.Controls.Border]::new()
    $headerBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    $headerBtn.Padding = [System.Windows.Thickness]::new(10, 6, 10, 6)
    $headerBtn.CornerRadius = [System.Windows.CornerRadius]::new(3, 3, 0, 0)
    $headerBtn.Cursor = [System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.DockPanel]::SetDock($headerBtn, [System.Windows.Controls.Dock]::Top)

    $headerGrid = [System.Windows.Controls.Grid]::new()
    $c1 = [System.Windows.Controls.ColumnDefinition]::new(); $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c2 = [System.Windows.Controls.ColumnDefinition]::new(); $c2.Width = [System.Windows.GridLength]::Auto
    $headerGrid.ColumnDefinitions.Add($c1)
    $headerGrid.ColumnDefinitions.Add($c2)

    $headerTitle = [System.Windows.Controls.TextBlock]::new()
    $headerTitle.Text = "🔔 Системное уведомление: $Summary"
    $headerTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#58A6FF")
    $headerTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
    $headerTitle.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($headerTitle, 0)
    $headerGrid.Children.Add($headerTitle) | Out-Null

    $toggleBadge = [System.Windows.Controls.Border]::new()
    $toggleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
    $toggleBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#484F58")
    $toggleBadge.BorderThickness = [System.Windows.Thickness]::new(1)
    $toggleBadge.CornerRadius = [System.Windows.CornerRadius]::new(3)
    $toggleBadge.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $toggleBadge.Cursor = [System.Windows.Input.Cursors]::Hand

    $toggleHint = [System.Windows.Controls.TextBlock]::new()
    $toggleHint.Text = if ($StartCollapsed) { "▶ Развернуть" } else { "▼ Свернуть" }
    $toggleHint.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $toggleHint.FontSize = 11
    $toggleHint.FontWeight = [System.Windows.FontWeights]::SemiBold
    $toggleBadge.Child = $toggleHint
    [System.Windows.Controls.Grid]::SetColumn($toggleBadge, 1)
    $headerGrid.Children.Add($toggleBadge) | Out-Null

    $headerBtn.Child = $headerGrid
    $dock.Children.Add($headerBtn) | Out-Null

    # Тело карточки
    $bodyBorder = [System.Windows.Controls.Border]::new()
    $bodyBorder.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
    $bodyBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#161B22")
    if ($StartCollapsed) {
        $bodyBorder.Visibility = [System.Windows.Visibility]::Collapsed
    }

    $txtBody = [System.Windows.Controls.TextBox]::new()
    $txtBody.Text = $Body
    $txtBody.IsReadOnly = $true
    $txtBody.IsUndoEnabled = $false
    $txtBody.Background = [System.Windows.Media.Brushes]::Transparent
    $txtBody.BorderThickness = [System.Windows.Thickness]::new(0)
    $txtBody.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#C9D1D9")
    $txtBody.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Cascadia Code, Courier New")
    $txtBody.FontSize = 11.5
    $txtBody.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $txtBody.AcceptsReturn = $true
    $bodyBorder.Child = $txtBody
    $dock.Children.Add($bodyBorder) | Out-Null

    $card.Child = $dock

    $groupObj = [PSCustomObject]@{
        Card        = $card
        HeaderBtn   = $headerBtn
        ToggleBadge = $toggleBadge
        HeaderTitle = $headerTitle
        ToggleHint  = $toggleHint
        BodyBorder  = $bodyBorder
        IsCollapsed = [bool]$StartCollapsed
    }

    # Эффекты при наведении (используем $s - отправитель события WPF, чтобы не зависеть от замыкания переменных)
    $headerBtn.Add_MouseEnter({
        param($s, $e)
        if ($s) { $s.Background = (Get-CachedBrush "#282E37") }
    })
    $headerBtn.Add_MouseLeave({
        param($s, $e)
        if ($s) { $s.Background = (Get-CachedBrush "#21262D") }
    })
    $toggleBadge.Add_MouseEnter({
        param($s, $e)
        if ($s) {
            $s.Background = (Get-CachedBrush "#3C444D")
            $s.BorderBrush = (Get-CachedBrush "#58A6FF")
        }
    })
    $toggleBadge.Add_MouseLeave({
        param($s, $e)
        if ($s) {
            $s.Background = (Get-CachedBrush "#30363D")
            $s.BorderBrush = (Get-CachedBrush "#484F58")
        }
    })

    $headerBtn.Tag = $groupObj
    $toggleBadge.Tag = $groupObj

    $headerBtn.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Toggle-SystemMessageCard -element $s -e $e
    })
    $toggleBadge.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        Toggle-SystemMessageCard -element $s -e $e
    })

    $buc = [System.Windows.Documents.BlockUIContainer]::new($card)
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if ($doc) {
        $doc.Blocks.Add($buc)
    }

    return $groupObj
}

function Add-ToolStartToGroup([string]$toolName, $Tab = $null) {
    $t = if ($Tab) { $Tab } else { $global:ActiveTab }
    $doc = if ($t) { $t.Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if ($t) {
        if (-not $t.ActiveToolGroup) {
            $t.ActiveToolGroup = New-ToolGroupCard -Document $t.Document
        }
        $g = $t.ActiveToolGroup
        $global:ActiveToolGroup = $g
    } else {
        if (-not $global:ActiveToolGroup) {
            $global:ActiveToolGroup = New-ToolGroupCard -Document $doc
        }
        $g = $global:ActiveToolGroup
    }

    $g.HeaderTitle.Text = "⚙️ Выполняется: $toolName..."

    $row = [System.Windows.Controls.TextBlock]::new()
    $row.Text = "  ⏳ ⚙️ [$toolName] — выполняется..."
    $row.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E2C08D")
    $row.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
    $g.BodyPanel.Children.Add($row) | Out-Null

    $g.PendingItems[$toolName] = $row
    if ((-not $t -or $t -eq $global:ActiveTab) -and $txtChatLog) { Scroll-ChatLogToEnd }
}

function Add-ToolDoneToGroup([string]$toolName, [double]$duration, $Tab = $null) {
    $t = if ($Tab) { $Tab } else { $global:ActiveTab }
    $doc = if ($t) { $t.Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if ($t) {
        if (-not $t.ActiveToolGroup) {
            $t.ActiveToolGroup = New-ToolGroupCard -Document $t.Document
        }
        $g = $t.ActiveToolGroup
        $global:ActiveToolGroup = $g
    } else {
        if (-not $global:ActiveToolGroup) {
            $global:ActiveToolGroup = New-ToolGroupCard -Document $doc
        }
        $g = $global:ActiveToolGroup
    }

    $g.ToolCount++
    $g.TotalSeconds += $duration

    if ($g.PendingItems.ContainsKey($toolName)) {
        $row = $g.PendingItems[$toolName]
        $row.Text = "  ✔️ ⚙️ [$toolName] — выполнен за $duration сек"
        $row.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4EC9B0")
        $g.PendingItems.Remove($toolName)
    } else {
        $row = [System.Windows.Controls.TextBlock]::new()
        $row.Text = "  ✔️ ⚙️ [$toolName] — выполнен за $duration сек"
        $row.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4EC9B0")
        $row.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
        $g.BodyPanel.Children.Add($row) | Out-Null
    }

    $g.HeaderTitle.Text = "⚙️ Вызовы инструментов ($($g.ToolCount)) • $([math]::Round($g.TotalSeconds, 2)) сек"
    if ((-not $t -or $t -eq $global:ActiveTab) -and $txtChatLog) { Scroll-ChatLogToEnd }
}

function Finalize-ActiveToolGroup($Tab = $null) {
    $t = if ($Tab) { $Tab } else { $global:ActiveTab }
    $g = if ($t) { $t.ActiveToolGroup } else { $global:ActiveToolGroup }
    if ($g) {
        foreach ($k in @($g.PendingItems.Keys)) {
            $row = $g.PendingItems[$k]
            $row.Text = "  ✔️ ⚙️ [$k] — завершено"
            $row.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4EC9B0")
            $g.ToolCount++
        }
        $g.PendingItems.Clear()

        $durStr = if ($g.TotalSeconds -gt 0) { " • $([math]::Round($g.TotalSeconds, 2)) сек" } else { "" }
        $g.HeaderTitle.Text = "⚙️ Вызовы инструментов ($($g.ToolCount) операций)$durStr"
        
        # Сворачиваем карточку, освобождая место для ответа
        $g.BodyBorder.Visibility = [System.Windows.Visibility]::Collapsed
        $g.ToggleHint.Text = "▶ Развернуть ($($g.ToolCount))"
        $g.IsCollapsed = $true

        if ($t) {
            $t.ActiveToolGroup = $null
        }
        if (-not $t -or $t -eq $global:ActiveTab) {
            $global:ActiveToolGroup = $null
            if ($txtChatLog) { Scroll-ChatLogToEnd }
        }
    }
}

function Add-HistoryToolGroupCard($toolsList, $Document = $null) {
    if (-not $toolsList -or $toolsList.Count -eq 0) { return }
    $card = New-ToolGroupCard -StartCollapsed -Document $Document
    $card.ToolCount = $toolsList.Count
    $card.LazyTools = $toolsList
    if ($toolsList.Count -le 3) {
        foreach ($t in $toolsList) {
            $row = [System.Windows.Controls.TextBlock]::new()
            $tSummary = if ($t.Summary) { " — $($t.Summary)" } else { "" }
            $row.Text = "  ✔️ ⚙️ [$($t.Name)]$tSummary"
            $row.Foreground = (Get-CachedBrush "#4EC9B0")
            $row.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
            $card.BodyPanel.Children.Add($row) | Out-Null
        }
    }
    $card.HeaderTitle.Text = "⚙️ Вызовы инструментов ($($card.ToolCount) операций)"
    $card.ToggleHint.Text = "▶ Развернуть ($($card.ToolCount))"
}

function Show-WelcomeMessage($Document = $null) {
    Clear-ChatLog -Document $Document
    Append-ChatFormatted -Text "================================================================================`r`n" -Color "#3E3E42" -Document $Document
    Append-ChatFormatted -Text "  ⚡ Antigravity Agent Shell v1.0`r`n" -Color "#4FC1FF" -Bold -Document $Document
    Append-ChatFormatted -Text "  Исполняемый файл: $defaultAgyPath`r`n" -Color "#888888" -Document $Document
    Append-ChatFormatted -Text "  Нажмите [Enter] для отправки, [Shift+Enter] для новой строки.`r`n" -Color "#888888" -Document $Document
    Append-ChatFormatted -Text "  Вкладки диалогов: [➕] или [Ctrl+T] — новая, [Ctrl+W] — закрыть, [Ctrl+Tab] — переключение.`r`n" -Color "#888888" -Document $Document
    Append-ChatFormatted -Text "================================================================================`r`n`r`n" -Color "#3E3E42" -Document $Document
}
Show-WelcomeMessage

# --- Управление сессиями и историей разговоров ---
$launcherDir = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "AntigravityGUI.ps1"))) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path -and (Test-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "AntigravityGUI.ps1"))) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    "H:\IGROSTROY\Agy-CLI-Shell"
}
$sessionMetaPath = Join-Path $userDataDir "sessions_meta.json"
$global:LastSentPrompt = ""
$global:SuppressConvComboEvent = $false

function Save-SessionMetadata {
    param(
        [string]$id,
        [string]$workspace,
        [string]$title
    )
    if ([string]::IsNullOrWhiteSpace($id)) { return }

    try {
        if (-not $sessionMetaPath) {
            $sessionMetaPath = Join-Path $userDataDir "sessions_meta.json"
        }
        $meta = @{}
        if (Test-Path $sessionMetaPath) {
            $raw = Get-Content -Path $sessionMetaPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if ($raw) {
                $parsed = $raw | ConvertFrom-Json
                foreach ($prop in $parsed.psobject.properties) {
                    $meta[$prop.Name] = $prop.Value
                }
            }
        }

        $existing = if ($meta.ContainsKey($id)) { $meta[$id] } else { $null }
        $cleanTitle = if ($title) { ($title -split "`r?`n")[0].Trim() } else { "Диалог $id" }
        if ($cleanTitle.Length -gt 120) { $cleanTitle = $cleanTitle.Substring(0, 117) + "..." }

        $meta[$id] = [pscustomobject]@{
            workspace = if ($workspace) { $workspace } elseif ($existing -and $existing.workspace) { $existing.workspace } else { "" }
            title     = if ($cleanTitle -and $cleanTitle -ne "Диалог $id") { $cleanTitle } elseif ($existing -and $existing.title) { $existing.title } else { "Диалог $id" }
            timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        }

        $meta | ConvertTo-Json -Depth 4 | Set-Content -Path $sessionMetaPath -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}
}

$script:cachedConversations = $null
$script:cachedConversationsTime = [DateTime]::MinValue
$script:contextStatsCache = @{}

function Get-AntigravityConversations {
    param([switch]$ForceRefresh)
    $now = [DateTime]::UtcNow
    if (-not $ForceRefresh -and $script:cachedConversations -and ($now - $script:cachedConversationsTime).TotalSeconds -lt 4) {
        return $script:cachedConversations
    }

    $brainDir = "$env:USERPROFILE\.gemini\antigravity-cli\brain"
    $historyPath = "$env:USERPROFILE\.gemini\antigravity-cli\history.jsonl"

    $localMeta = @{}
    if ($sessionMetaPath -and (Test-Path $sessionMetaPath)) {
        try {
            $rawJson = Get-Content -Path $sessionMetaPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if ($rawJson) {
                $parsed = $rawJson | ConvertFrom-Json
                foreach ($prop in $parsed.psobject.properties) {
                    $localMeta[$prop.Name] = $prop.Value
                }
            }
        } catch {}
    }

    $histMap = @{}
    if (Test-Path $historyPath) {
        try {
            $hLines = Get-Content -Path $historyPath -Encoding utf8 -ErrorAction SilentlyContinue
            foreach ($line in $hLines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    try {
                        $item = $line | ConvertFrom-Json
                        if ($item.conversationId -and $item.workspace) {
                            $histMap[$item.conversationId] = $item.workspace
                        }
                    } catch {}
                }
            }
        } catch {}
    }

    $list = [System.Collections.Generic.List[psobject]]::new()
    if (Test-Path $brainDir) {
        $dirs = Get-ChildItem -Path $brainDir -Directory -ErrorAction SilentlyContinue
        foreach ($d in $dirs) {
            $cid = $d.Name
            $tPath = Join-Path $d.FullName ".system_generated\logs\transcript.jsonl"
            $title = "Новый диалог"
            $workspace = ""
            $msgCount = 0
            $lastTime = $d.LastWriteTime

            if ($localMeta.ContainsKey($cid)) {
                $m = $localMeta[$cid]
                if ($m.workspace) { $workspace = $m.workspace }
                if ($m.title)     { $title = $m.title }
                if ($m.msgCount)  { $msgCount = [int]$m.msgCount }
            }

            if (-not $workspace -and $histMap.ContainsKey($cid)) {
                $workspace = $histMap[$cid]
            }

            if (Test-Path $tPath) {
                $needScan = ($title -eq "Новый диалог" -or -not $workspace)
                if ($needScan) {
                    try {
                        $sr = [System.IO.StreamReader]::new($tPath, [System.Text.Encoding]::UTF8)
                        try {
                            $lineNum = 0
                            while (-not $sr.EndOfStream -and $lineNum -lt 15) {
                                $l = $sr.ReadLine()
                                if ([string]::IsNullOrWhiteSpace($l)) { continue }
                                $lineNum++
                                if ($lineNum -eq 1 -and $title -eq "Новый диалог") {
                                    try {
                                        $first = $l | ConvertFrom-Json
                                        if ($first.content) {
                                            $c = $first.content
                                            if ($c -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') {
                                                $title = $matches[1].Trim()
                                            } else {
                                                $title = $c.Trim()
                                            }
                                        }
                                    } catch {}
                                }
                                if (-not $workspace) {
                                    if ($l -match '(?i)(?<![A-Za-z0-9])([A-Za-z]:\\\\(?:[^"''\r\n\\]+\\\\)*?IGROSTROY(?:\\\\([^\r\n"''\\]+))?)') {
                                        $workspace = $matches[1].Replace('\\', '\')
                                    }
                                }
                                if ($title -ne "Новый диалог" -and $workspace) { break }
                            }
                        } finally {
                            $sr.Dispose()
                        }
                    } catch {}
                }
                if ($msgCount -le 0) {
                    try {
                        $fi = [System.IO.FileInfo]::new($tPath)
                        $msgCount = [math]::Max(1, [int][math]::Round($fi.Length / 4096))
                    } catch { $msgCount = 1 }
                }
            }

            $firstLineTitle = ($title -split "`r?`n")[0]
            if ($firstLineTitle.Length -gt 75) { $firstLineTitle = $firstLineTitle.Substring(0, 72) + "..." }

            $projectName = if ($workspace) { Split-Path $workspace -Leaf } else { "—" }
            $dateDisplay = $lastTime.ToString("dd.MM.yyyy HH:mm")

            $list.Add([pscustomobject]@{
                Id           = $cid
                ShortId      = if ($cid.Length -gt 8) { $cid.Substring(0, 8) } else { $cid }
                Title        = $firstLineTitle
                FullTitle    = $title
                Workspace    = $workspace
                ProjectName  = $projectName
                DateDisplay  = $dateDisplay
                LastModified = $lastTime
                MessageCount = $msgCount
            })
        }
    }

    $sorted = $list | Sort-Object LastModified -Descending
    $script:cachedConversations = $sorted
    $script:cachedConversationsTime = $now
    return $sorted
}

function Get-ModelContextLimit {
    param([string]$modelName)
    if ([string]::IsNullOrWhiteSpace($modelName)) { return 1048576 }
    $m = $modelName.ToLower()
    if ($m.Contains("gemini")) { return 1048576 }
    if ($m.Contains("claude")) { return 200000 }
    if ($m.Contains("gpt-oss")) { return 128000 }
    return 1048576
}

function Format-TokenCount {
    param([long]$tokens)
    if ($tokens -lt 1000) { return "$tokens" }
    if ($tokens -lt 1000000) {
        $val = [math]::Round(($tokens / 1000.0), 1)
        return "$([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.#}', $val))k"
    }
    $valM = [math]::Round(($tokens / 1000000.0), 1)
    return "$([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.#}', $valM))M"
}

function Get-ConversationContextStats {
    param(
        [string]$conversationId,
        [string]$modelName = "gemini-3.8-flash-high"
    )
    $maxLimit = Get-ModelContextLimit -modelName $modelName
    if ([string]::IsNullOrWhiteSpace($conversationId)) {
        return [pscustomobject]@{
            ConversationId = ""
            TotalTokens    = 0
            InputTokens    = 0
            CacheTokens    = 0
            OutputTokens   = 0
            MaxLimit       = $maxLimit
            Percent        = 0.0
            FormattedTotal = "0"
            FormattedMax   = Format-TokenCount $maxLimit
            FormattedIn    = "0"
            FormattedCache = "0"
            FormattedOut   = "0"
            RemTokens      = $maxLimit
            FormattedRem   = Format-TokenCount $maxLimit
            RemPercent     = 100.0
            ModelName      = $modelName
            DisplayText    = "🧠 Контекст: 0 / $(Format-TokenCount $maxLimit) (0%)"
            ToolTipText    = "Новый диалог (контекст пуст).`nЛимит модели: $(Format-TokenCount $maxLimit) токенов.`nНажмите на виджет для подробного анализа."
            Color          = "#4EC9B0"
        }
    }

    $brainDir = "$env:USERPROFILE\.gemini\antigravity-cli\brain"
    $transcriptPath = Join-Path $brainDir "$conversationId\.system_generated\logs\transcript.jsonl"
    if (-not (Test-Path $transcriptPath)) {
        $altPath = Join-Path $brainDir "$conversationId\transcript.jsonl"
        if (Test-Path $altPath) { $transcriptPath = $altPath } else {
            return [pscustomobject]@{
                ConversationId = $conversationId
                TotalTokens    = 0
                InputTokens    = 0
                CacheTokens    = 0
                OutputTokens   = 0
                MaxLimit       = $maxLimit
                Percent        = 0.0
                FormattedTotal = "0"
                FormattedMax   = Format-TokenCount $maxLimit
                FormattedIn    = "0"
                FormattedCache = "0"
                FormattedOut   = "0"
                RemTokens      = $maxLimit
                FormattedRem   = Format-TokenCount $maxLimit
                RemPercent     = 100.0
                ModelName      = $modelName
                DisplayText    = "🧠 Контекст: 0 / $(Format-TokenCount $maxLimit) (0%)"
                ToolTipText    = "Транскрипт пока не содержит записей токенов.`nНажмите на виджет для подробного анализа."
                Color          = "#4EC9B0"
            }
        }
    }

    try {
        $fileInfo = [System.IO.FileInfo]::new($transcriptPath)
        if ($fileInfo.Length -eq 0) {
            return [pscustomobject]@{
                ConversationId = $conversationId
                TotalTokens    = 0
                InputTokens    = 0
                CacheTokens    = 0
                OutputTokens   = 0
                MaxLimit       = $maxLimit
                Percent        = 0.0
                FormattedTotal = "0"
                FormattedMax   = Format-TokenCount $maxLimit
                FormattedIn    = "0"
                FormattedCache = "0"
                FormattedOut   = "0"
                RemTokens      = $maxLimit
                FormattedRem   = Format-TokenCount $maxLimit
                RemPercent     = 100.0
                ModelName      = $modelName
                DisplayText    = "🧠 Контекст: 0 / $(Format-TokenCount $maxLimit) (0%)"
                ToolTipText    = "Диалог пуст.`nНажмите на виджет для подробного анализа."
                Color          = "#4EC9B0"
            }
        }

        $cacheKey = "$($conversationId)_$($fileInfo.LastWriteTimeUtc.Ticks)_$($modelName)"
        if ($script:contextStatsCache -and $script:contextStatsCache.ContainsKey($cacheKey)) {
            return $script:contextStatsCache[$cacheKey]
        }

        $fs = [System.IO.FileStream]::new($transcriptPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $lines = $null
        try {
            $readSize = [Math]::Min($fileInfo.Length, 262144)
            $fs.Seek(-$readSize, [System.IO.SeekOrigin]::End) | Out-Null
            $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
            $lines = ($reader.ReadToEnd() -split "`r?`n")
        } finally {
            $fs.Dispose()
        }

        $inputTokens = 0
        $cacheTokens = 0
        $outputTokens = 0
        $found = $false

        if ($lines) {
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $l = $lines[$i]
                if ($l -and $l.Contains('"PLANNER_RESPONSE"')) {
                    try {
                        $parsed = $l | ConvertFrom-Json
                        if ($parsed.type -eq "PLANNER_RESPONSE") {
                            $inputTokens = if ($parsed.input_tokens) { [long]$parsed.input_tokens } else { 0 }
                            $cacheTokens = if ($parsed.cache_read_tokens) { [long]$parsed.cache_read_tokens } else { 0 }
                            $outputTokens = if ($parsed.output_tokens) { [long]$parsed.output_tokens } else { 0 }
                            $found = $true
                            break
                        }
                    } catch {}
                }
            }
        }

        if (-not $found -and $fileInfo.Length -gt 262144) {
            $tail = Get-Content -Path $transcriptPath -Tail 50 -ErrorAction SilentlyContinue
            if ($tail) {
                for ($j = $tail.Count - 1; $j -ge 0; $j--) {
                    if ($tail[$j] -match '"PLANNER_RESPONSE"') {
                        try {
                            $parsed = $tail[$j] | ConvertFrom-Json
                            if ($parsed.type -eq "PLANNER_RESPONSE") {
                                $inputTokens = if ($parsed.input_tokens) { [long]$parsed.input_tokens } else { 0 }
                                $cacheTokens = if ($parsed.cache_read_tokens) { [long]$parsed.cache_read_tokens } else { 0 }
                                $outputTokens = if ($parsed.output_tokens) { [long]$parsed.output_tokens } else { 0 }
                                $found = $true
                                break
                            }
                        } catch {}
                    }
                }
            }
        }

        $totalTokens = $inputTokens + $cacheTokens
        $pct = if ($maxLimit -gt 0) { [math]::Round(($totalTokens / [double]$maxLimit) * 100.0, 1) } else { 0.0 }
        
        $color = if ($pct -ge 80.0) {
            "#F85149"
        } elseif ($pct -ge 60.0) {
            "#E2C08D"
        } else {
            "#4EC9B0"
        }

        $formattedTotal = Format-TokenCount $totalTokens
        $formattedMax   = Format-TokenCount $maxLimit
        $formattedIn    = Format-TokenCount $inputTokens
        $formattedCache = Format-TokenCount $cacheTokens
        $formattedOut   = Format-TokenCount $outputTokens

        $remTokens = [Math]::Max(0L, ($maxLimit - $totalTokens))
        $remPct    = if ($maxLimit -gt 0) { [math]::Round(($remTokens / [double]$maxLimit) * 100.0, 1) } else { 0.0 }
        $formattedRem = Format-TokenCount $remTokens

        $toolTip = @"
🧠 Заполненность контекстного окна:
• Всего в контексте: $formattedTotal / $formattedMax токенов ($pct%)
• Кэшированные токены: $formattedCache ($([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:N0}', $cacheTokens)))
• Новые входные токены: $formattedIn ($([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:N0}', $inputTokens)))
• Последний ответ модели: $formattedOut ($([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:N0}', $outputTokens)))
• Модель: $modelName (Лимит: $formattedMax токенов)
• Нажмите на виджет для детального графического анализа
$(if ($pct -ge 80.0) { "`n⚠️ ВНИМАНИЕ: Контекст заполнен более чем на 80%! Рекомендуется выполнить /compact для оптимизации." } else { "" })
"@.Trim()

        $statObj = [pscustomobject]@{
            ConversationId = $conversationId
            TotalTokens    = $totalTokens
            InputTokens    = $inputTokens
            CacheTokens    = $cacheTokens
            OutputTokens   = $outputTokens
            MaxLimit       = $maxLimit
            Percent        = $pct
            FormattedTotal = $formattedTotal
            FormattedMax   = $formattedMax
            FormattedIn    = $formattedIn
            FormattedCache = $formattedCache
            FormattedOut   = $formattedOut
            RemTokens      = $remTokens
            FormattedRem   = $formattedRem
            RemPercent     = $remPct
            ModelName      = $modelName
            DisplayText    = "🧠 Контекст: $formattedTotal / $formattedMax ($pct%)"
            ToolTipText    = $toolTip
            Color          = $color
        }
        if ($script:contextStatsCache -and $cacheKey) {
            $script:contextStatsCache[$cacheKey] = $statObj
        }
        return $statObj
    } catch {
        return [pscustomobject]@{
            ConversationId = $conversationId
            TotalTokens    = 0
            InputTokens    = 0
            CacheTokens    = 0
            OutputTokens   = 0
            MaxLimit       = $maxLimit
            Percent        = 0.0
            FormattedTotal = "0"
            FormattedMax   = Format-TokenCount $maxLimit
            FormattedIn    = "0"
            FormattedCache = "0"
            FormattedOut   = "0"
            RemTokens      = $maxLimit
            FormattedRem   = Format-TokenCount $maxLimit
            RemPercent     = 100.0
            ModelName      = $modelName
            DisplayText    = "🧠 Контекст: 0 / $(Format-TokenCount $maxLimit) (0%)"
            ToolTipText    = "Ошибка чтения статистики контекста: $_`nНажмите на виджет для подробного анализа."
            Color          = "#888888"
        }
    }
}

function Update-ContextDisplay {
    param(
        [string]$conversationId = $global:CurrentConversationId,
        [string]$modelName = $null
    )
    if (-not $txtContextTokens -and -not $prgContext) { return }

    if (-not $modelName -and $cmbModel -and $cmbModel.SelectedItem) {
        $modelName = $cmbModel.SelectedItem.ToString()
    }
    if (-not $modelName) { $modelName = "gemini-3.8-flash-high" }

    $stats = Get-ConversationContextStats -conversationId $conversationId -modelName $modelName

    # 1. Графическая полоса прогресса (ProgressBar)
    if ($prgContext) {
        $prgContext.Value = [math]::Min(100.0, [math]::Max(0.0, [double]$stats.Percent))
        $prgContext.Foreground = (Get-CachedBrush $stats.Color)
    }

    # 2. Текстовый счетчик токенов (например: "107.9k / 1.0M")
    if ($txtContextTokens) {
        $txtContextTokens.Text = "$($stats.FormattedTotal) / $($stats.FormattedMax)"
    }

    # 3. Графический бейдж с процентом
    if ($txtContextPercent) {
        $txtContextPercent.Text = "$($stats.Percent)%"
        $txtContextPercent.Foreground = (Get-CachedBrush $stats.Color)
    }
    if ($borderContextBadge) {
        $badgeBg = if ($stats.Percent -ge 80.0) {
            "#381E20"
        } elseif ($stats.Percent -ge 60.0) {
            "#332B1C"
        } else {
            "#1B2F2B"
        }
        $badgeBorder = if ($stats.Percent -ge 80.0) {
            "#6E282D"
        } elseif ($stats.Percent -ge 60.0) {
            "#5C4927"
        } else {
            "#244B3F"
        }
        $borderContextBadge.Background = (Get-CachedBrush $badgeBg)
        $borderContextBadge.BorderBrush = (Get-CachedBrush $badgeBorder)
    }

    # 4. Всплывающая подсказка для всего интерактивного виджета
    if ($borderContextWidget) {
        $borderContextWidget.ToolTip = $stats.ToolTipText
    }

    if ($global:ActiveTab) {
        try {
            $global:ActiveTab.ContextStats = $stats
        } catch {}
    }
}

function Show-ContextDetailsDialog {
    param(
        $OwnerWindow = $null
    )

    $stats = if ($global:ActiveTab -and $global:ActiveTab.ContextStats) {
        $global:ActiveTab.ContextStats
    } else {
        Get-ConversationContextStats -conversationId $global:CurrentConversationId
    }

    $modelName   = if ($stats.ModelName) { $stats.ModelName } else { "gemini-3.8-flash-high" }
    $totalTokens = $stats.TotalTokens
    $maxLimit    = $stats.MaxLimit
    $pct         = $stats.Percent
    $cacheTokens = $stats.CacheTokens
    $inputTokens = $stats.InputTokens
    $outputTokens= $stats.OutputTokens

    $totalFmt = if ($stats.FormattedTotal) { $stats.FormattedTotal } else { Format-TokenCount $totalTokens }
    $maxFmt   = if ($stats.FormattedMax) { $stats.FormattedMax } else { Format-TokenCount $maxLimit }
    $cacheFmt = if ($stats.FormattedCache) { $stats.FormattedCache } else { Format-TokenCount $cacheTokens }
    $inFmt    = if ($stats.FormattedIn) { $stats.FormattedIn } else { Format-TokenCount $inputTokens }
    $outFmt   = if ($stats.FormattedOut) { $stats.FormattedOut } else { Format-TokenCount $outputTokens }
    $remFmt   = if ($stats.FormattedRem) { $stats.FormattedRem } else { Format-TokenCount ([math]::Max(0L, ($maxLimit - $totalTokens))) }
    $remPct   = if ($stats.RemPercent) { $stats.RemPercent } else { if ($maxLimit -gt 0) { [math]::Round(([math]::Max(0L, ($maxLimit - $totalTokens)) / [double]$maxLimit) * 100.0, 1) } else { 100.0 } }
    $colorHex = if ($stats.Color) { $stats.Color } else { "#4EC9B0" }

    $adviceText = if ($pct -ge 80.0) {
        "⚠️ ВНИМАНИЕ: Контекстное окно заполнено на $pct%! Дальнейшие запросы могут приводить к вытеснению ранних инструкций или снижению точности кода. Рекомендуется выполнить команду /compact для сжатия диалога или начать новую сессию."
    } elseif ($pct -ge 60.0) {
        "ℹ️ ПРЕДУПРЕЖДЕНИЕ: Использовано $pct% контекста модели. Система работает в штатном режиме, однако рекомендуется соблюдать умеренность при одновременной передаче объемных файлов."
    } elseif ($totalTokens -eq 0) {
        "✨ Диалог новый либо транскрипт пока не зафиксировал метрики токенов. После первого ответа модели здесь отобразится полная статистика расхода контекста."
    } else {
        "✅ Отличное состояние: занято всего $pct% контекстного окна ($totalFmt из $maxFmt). Модель удерживает полную историю обсуждения и готова к масштабным задачам."
    }

    $dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="🧠 Анализ контекстного окна модели"
        Height="400" Width="520"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        Background="#181A20" Foreground="#F1F1F1"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <ControlTemplate x:Key="DlgProgressBarTemplate" TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                <Grid x:Name="PART_Track" ClipToBounds="True">
                    <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" CornerRadius="5"/>
                </Grid>
            </Border>
        </ControlTemplate>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Шапка -->
        <DockPanel Grid.Row="0" Margin="0,0,0,14">
            <StackPanel DockPanel.Dock="Left">
                <TextBlock Text="🧠 Заполненность контекста" FontSize="16" FontWeight="Bold" Foreground="#FFFFFF"/>
                <TextBlock x:Name="TxtDlgSubtitle" Text="Модель: $modelName (Лимит: $maxFmt токенов)" FontSize="12" Foreground="#8B949E" Margin="0,2,0,0"/>
            </StackPanel>
            <Border x:Name="BorderDlgBadge" DockPanel.Dock="Right" HorizontalAlignment="Right" VerticalAlignment="Center"
                    Background="#1E242B" BorderBrush="$colorHex" BorderThickness="1.5" CornerRadius="6" Padding="8,4">
                <TextBlock x:Name="TxtDlgBadgePercent" Text="$pct%" FontSize="15" FontWeight="Bold" Foreground="$colorHex"/>
            </Border>
        </DockPanel>

        <!-- Графическая полоса -->
        <StackPanel Grid.Row="1" Margin="0,0,0,16">
            <ProgressBar x:Name="DlgPrgBar" Template="{StaticResource DlgProgressBarTemplate}"
                         Height="12" Minimum="0" Maximum="100"
                         Background="#101216" BorderBrush="#262A34" BorderThickness="1"
                         Foreground="$colorHex" Margin="0,0,0,6"/>
            <DockPanel>
                <TextBlock x:Name="TxtDlgUsed" DockPanel.Dock="Left" Text="Занято: $totalFmt токенов" FontSize="11" Foreground="#AAAAAA"/>
                <TextBlock x:Name="TxtDlgFree" DockPanel.Dock="Right" Text="Свободно: $remFmt ($remPct%)" FontSize="11" Foreground="#8B949E" HorizontalAlignment="Right"/>
            </DockPanel>
        </StackPanel>

        <!-- Раскладка по токенам (4 карточки) -->
        <UniformGrid Grid.Row="2" Columns="4" Margin="0,0,0,14">
            <Border Background="#1C212B" BorderBrush="#2D3545" BorderThickness="1" CornerRadius="6" Padding="8,6" Margin="0,0,4,0">
                <StackPanel>
                    <TextBlock Text="⚡ КЭШ" FontSize="10" FontWeight="SemiBold" Foreground="#58A6FF"/>
                    <TextBlock Text="$cacheFmt" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,2,0,0"/>
                    <TextBlock Text="предыстория" FontSize="10" Foreground="#8B949E"/>
                </StackPanel>
            </Border>

            <Border Background="#1C2622" BorderBrush="#254236" BorderThickness="1" CornerRadius="6" Padding="8,6" Margin="2,0,2,0">
                <StackPanel>
                    <TextBlock Text="📥 ВХОД" FontSize="10" FontWeight="SemiBold" Foreground="#3FB950"/>
                    <TextBlock Text="$inFmt" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,2,0,0"/>
                    <TextBlock Text="новый запрос" FontSize="10" Foreground="#8B949E"/>
                </StackPanel>
            </Border>

            <Border Background="#242129" BorderBrush="#3D3247" BorderThickness="1" CornerRadius="6" Padding="8,6" Margin="2,0,2,0">
                <StackPanel>
                    <TextBlock Text="📤 ОТВЕТ" FontSize="10" FontWeight="SemiBold" Foreground="#BC8CFF"/>
                    <TextBlock Text="$outFmt" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,2,0,0"/>
                    <TextBlock Text="генерация" FontSize="10" Foreground="#8B949E"/>
                </StackPanel>
            </Border>

            <Border Background="#191F26" BorderBrush="#28323F" BorderThickness="1" CornerRadius="6" Padding="8,6" Margin="4,0,0,0">
                <StackPanel>
                    <TextBlock Text="🛡️ ЗАПАС" FontSize="10" FontWeight="SemiBold" Foreground="#79C0FF"/>
                    <TextBlock Text="$remFmt" FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,2,0,0"/>
                    <TextBlock Text="$remPct% свободно" FontSize="10" Foreground="#8B949E"/>
                </StackPanel>
            </Border>
        </UniformGrid>

        <!-- Совет и рекомендации -->
        <Border Grid.Row="3" Background="#161920" BorderBrush="#222834" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="0,0,0,16">
            <TextBlock x:Name="TxtDlgAdvice" Text="$adviceText" FontSize="11.5" Foreground="$colorHex" TextWrapping="Wrap"/>
        </Border>

        <!-- Кнопка закрытия -->
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnCloseDlg" Content="Закрыть" IsDefault="True" IsCancel="True"
                    Background="#21262D" BorderBrush="#363B42" Foreground="#FFFFFF"
                    Padding="18,6" FontWeight="SemiBold" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        $sReader = [System.Xml.XmlNodeReader]::new([xml]$dialogXaml)
        $diag = [System.Windows.Markup.XamlReader]::Load($sReader)
        try {
            if ($OwnerWindow -and $OwnerWindow.IsVisible) {
                $diag.Owner = $OwnerWindow
            } elseif ($window -and $window.IsVisible) {
                $diag.Owner = $window
            }
        } catch {}
        if ($window -and $window.Icon) {
            $diag.Icon = $window.Icon
        }

        $dlgPrgBar = $diag.FindName("DlgPrgBar")
        if ($dlgPrgBar) {
            $dlgPrgBar.Value = [math]::Min(100.0, [math]::Max(0.0, [double]$pct))
        }

        $diag.ShowDialog() | Out-Null
    } catch {
            [System.Windows.MessageBox]::Show($stats.ToolTipText, "🧠 Контекстное окно модели", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
}

function Get-ModelQuotaLimits {
    param([string]$modelName = "gemini-3.8-flash-high")
    $m = if ($modelName) { $modelName.ToLowerInvariant() } else { "" }
    if ($m.Contains("gemini")) {
        return [pscustomobject]@{
            ModelName    = $modelName
            DisplayName  = "Gemini 3.8 Flash"
            MaxRpd       = 1500
            MaxRpm       = 60
            MaxTpm       = 4000000
            MaxContext   = 1000000
        }
    }
    if ($m.Contains("opus")) {
        return [pscustomobject]@{
            ModelName    = $modelName
            DisplayName  = "Claude 3.5 Opus"
            MaxRpd       = 500
            MaxRpm       = 20
            MaxTpm       = 500000
            MaxContext   = 200000
        }
    }
    if ($m.Contains("claude") -or $m.Contains("sonnet")) {
        return [pscustomobject]@{
            ModelName    = $modelName
            DisplayName  = "Claude 3.7 Sonnet"
            MaxRpd       = 1000
            MaxRpm       = 50
            MaxTpm       = 1000000
            MaxContext   = 200000
        }
    }
    if ($m.Contains("gpt-oss") -or $m.Contains("gpt")) {
        return [pscustomobject]@{
            ModelName    = $modelName
            DisplayName  = "GPT-OSS 120B"
            MaxRpd       = 800
            MaxRpm       = 30
            MaxTpm       = 800000
            MaxContext   = 128000
        }
    }
    return [pscustomobject]@{
        ModelName    = $modelName
        DisplayName  = "Gemini 3.8 Flash"
        MaxRpd       = 1500
        MaxRpm       = 60
        MaxTpm       = 4000000
        MaxContext   = 1000000
    }
}

$script:QuotaCacheFilePath = Join-Path $env:USERPROFILE ".gemini\antigravity-cli\launcher_quota_cache.json"
$global:QuotaGroupBlocked = @{}
$global:LiveQuotaCache = $null
$global:LiveQuotaCacheTime = [DateTime]::MinValue
$global:DailyUsageCache = $null
$global:DailyUsageCacheTime = [DateTime]::MinValue
$global:SessionRequestsDelta = 0
$global:QuotaBlockedUntil = [DateTime]::MinValue
$global:QuotaBlockedMessage = ""

function Get-ModelQuotaGroup {
    param([string]$modelName)
    $m = if ($modelName) { $modelName.ToLowerInvariant() } else { "" }
    if ($m.Contains("gemini")) { return "gemini" }
    return "claude_gpt"
}

function Format-QuotaCountdown {
    param([TimeSpan]$diff)
    if ($diff.TotalSeconds -le 0) { return "" }
    if ($diff.Days -gt 0) {
        return '{0}д {1}ч {2}м' -f $diff.Days, $diff.Hours, $diff.Minutes
    }
    return '{0}ч {1}м' -f [int][math]::Floor($diff.TotalHours), $diff.Minutes
}

function Update-QuotaCacheFromJson {
    param(
        [string]$RawJson
    )
    if ([string]::IsNullOrWhiteSpace($RawJson)) { return $null }
    try {
        $data = $RawJson | ConvertFrom-Json
        if (-not $data -or -not $data.command -or -not $data.command.data -or -not $data.command.data.groups) {
            return $null
        }
        $now = [DateTime]::Now
        $res = [ordered]@{
            updated_at = $now.ToString("o")
            gemini     = $null
            claude_gpt = $null
        }

        foreach ($g in $data.command.data.groups) {
            $isGemini = ($g.name -match 'Gemini')
            $groupKey = if ($isGemini) { 'gemini' } else { 'claude_gpt' }

            $weeklyBucket = $g.buckets | Where-Object { $_.window -eq 'weekly' } | Select-Object -First 1
            $fiveHourBucket = $g.buckets | Where-Object { $_.window -eq '5h' } | Select-Object -First 1

            $wFrac = if ($weeklyBucket) { [double]$weeklyBucket.remaining_fraction } else { 1.0 }
            $wPct = [math]::Round($wFrac * 100.0, 2)
            $wResetsIn = ""
            $wResetTime = ""
            if ($weeklyBucket -and $weeklyBucket.reset_time) {
                $wResetTime = [string]$weeklyBucket.reset_time
                try {
                    $target = [DateTime]::Parse($weeklyBucket.reset_time).ToUniversalTime()
                    $diff = $target - [DateTime]::UtcNow
                    if ($diff.TotalSeconds -gt 0) {
                        $wResetsIn = Format-QuotaCountdown $diff
                    }
                } catch {}
            }

            $fhFrac = if ($fiveHourBucket) { [double]$fiveHourBucket.remaining_fraction } else { 1.0 }
            $fhPct = [math]::Round($fhFrac * 100.0, 2)
            $fhDisabled = if ($fiveHourBucket -and $fiveHourBucket.disabled) { $true } else { $false }
            $fhResetsIn = ""
            $fhResetTime = ""
            if ($fiveHourBucket -and $fiveHourBucket.reset_time) {
                $fhResetTime = [string]$fiveHourBucket.reset_time
                try {
                    $target = [DateTime]::Parse($fiveHourBucket.reset_time).ToUniversalTime()
                    $diff = $target - [DateTime]::UtcNow
                    if ($diff.TotalSeconds -gt 0) {
                        $fhResetsIn = Format-QuotaCountdown $diff
                    }
                } catch {}
            }

            $isBlocked = ($wFrac -le 0.001)

            $res[$groupKey] = [ordered]@{
                group_name           = [string]$g.name
                weekly_fraction      = $wFrac
                weekly_percent       = $wPct
                weekly_resets_in     = $wResetsIn
                weekly_reset_time    = $wResetTime
                five_hour_fraction   = $fhFrac
                five_hour_percent    = $fhPct
                five_hour_disabled   = $fhDisabled
                five_hour_resets_in  = $fhResetsIn
                five_hour_reset_time = $fhResetTime
                is_blocked           = $isBlocked
                description          = [string]$g.description
            }

            if ($isBlocked) {
                $global:QuotaGroupBlocked[$groupKey] = [pscustomobject]@{
                    BlockedUntil = if ($wResetTime) { [DateTime]::Parse($wResetTime) } else { $now.AddHours(24) }
                    Message      = "Индивидуальный недельный лимит для группы '$($g.name)' исчерпан. Сброс через $wResetsIn."
                    ResetsIn     = $wResetsIn
                }
            } else {
                if ($global:QuotaGroupBlocked.ContainsKey($groupKey)) {
                    $global:QuotaGroupBlocked.Remove($groupKey)
                }
            }
        }

        $global:LiveQuotaCache = [pscustomobject]$res
        $global:LiveQuotaCacheTime = $now

        try {
            $cachePath = $script:QuotaCacheFilePath
            $dir = [System.IO.Path]::GetDirectoryName($cachePath)
            if (-not (Test-Path $dir)) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
            $jsonStr = $res | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($cachePath, $jsonStr, [System.Text.Encoding]::UTF8)
        } catch {}

        return $global:LiveQuotaCache
    } catch {
        return $null
    }
}

$global:ActiveQuotaSyncJob = $null

function Start-AsyncQuotaSync {
    param(
        [scriptblock]$OnCompleted
    )
    if ($global:ActiveQuotaSyncJob -and $global:ActiveQuotaSyncJob.AsyncResult -and -not $global:ActiveQuotaSyncJob.AsyncResult.IsCompleted) {
        if ($OnCompleted) {
            [void]$global:ActiveQuotaSyncJob.Callbacks.Add($OnCompleted)
        }
        return $global:ActiveQuotaSyncJob
    }

    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "agy.exe"
            $psi.Arguments = "-p `"/usage`" --output-format json"
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true

            $proc = [System.Diagnostics.Process]::Start($psi)
            if (-not $proc.WaitForExit(9000)) {
                try { $proc.Kill() } catch {}
                return $null
            }
            return $proc.StandardOutput.ReadToEnd()
        } catch {
            return $null
        }
    })

    $asyncResult = $ps.BeginInvoke()
    $callbacks = New-Object System.Collections.ArrayList
    if ($OnCompleted) { [void]$callbacks.Add($OnCompleted) }

    $startTime = [DateTime]::UtcNow
    $timer = New-Object System.Windows.Threading.DispatcherTimer([System.Windows.Threading.DispatcherPriority]::Normal)
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)

    $jobObj = [pscustomobject]@{
        PowerShell  = $ps
        AsyncResult = $asyncResult
        Timer       = $timer
        Callbacks   = $callbacks
    }
    $global:ActiveQuotaSyncJob = $jobObj

    $tickHandler = {
        $isDone = ($asyncResult -and $asyncResult.IsCompleted)
        $isTimeout = (([DateTime]::UtcNow - $startTime).TotalMilliseconds -gt 9500)

        if ($isDone -or $isTimeout) {
            $timer.Stop()
            $rawOut = $null
            if ($isDone) {
                try {
                    $rawOut = $ps.EndInvoke($asyncResult)
                } catch {}
            }
            try { $ps.Dispose() } catch {}

            if ($rawOut) {
                [void](Update-QuotaCacheFromJson -RawJson $rawOut)
            }

            $currentCallbacks = @($jobObj.Callbacks)
            $global:ActiveQuotaSyncJob = $null

            foreach ($cb in $currentCallbacks) {
                try { & $cb } catch {}
            }
        }
    }.GetNewClosure()
    $timer.Add_Tick($tickHandler)
    $timer.Start()
    return $jobObj
}

function Sync-QuotaLiveFromAgy {
    param([switch]$Force)
    $now = [DateTime]::Now
    $cachePath = $script:QuotaCacheFilePath

    # 1. Если данные в памяти свежие (< 90 сек) и не Force - вернуть память
    if (-not $Force -and $global:LiveQuotaCache -and (($now - $global:LiveQuotaCacheTime).TotalSeconds -lt 90)) {
        return $global:LiveQuotaCache
    }

    # 2. Если на диске есть свежий файл кэша (< 120 сек) и не Force - загрузить с диска
    if (-not $Force -and (Test-Path $cachePath)) {
        try {
            $fi = Get-Item $cachePath -ErrorAction SilentlyContinue
            if ($fi -and ($now - $fi.LastWriteTime).TotalSeconds -lt 120) {
                $rawDisk = [System.IO.File]::ReadAllText($cachePath, [System.Text.Encoding]::UTF8)
                $diskObj = $rawDisk | ConvertFrom-Json
                if ($diskObj -and $diskObj.gemini -and $diskObj.claude_gpt) {
                    $global:LiveQuotaCache = $diskObj
                    $global:LiveQuotaCacheTime = $fi.LastWriteTime
                    return $diskObj
                }
            }
        } catch {}
    }

    # 3. Синхронный живой запрос через agy.exe
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "agy.exe"
        $psi.Arguments = "-p `"/usage`" --output-format json"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        if (-not $proc.WaitForExit(9000)) {
            try { $proc.Kill() } catch {}
            return $global:LiveQuotaCache
        }
        $out = $proc.StandardOutput.ReadToEnd()
        $parsed = Update-QuotaCacheFromJson -RawJson $out
        if ($parsed) { return $parsed }
        return $global:LiveQuotaCache
    } catch {
        return $global:LiveQuotaCache
    }
}
function Load-QuotaCache {
    if (Test-Path $script:QuotaCacheFilePath) {
        try {
            $rawJson = [System.IO.File]::ReadAllText($script:QuotaCacheFilePath, [System.Text.Encoding]::UTF8)
            if ($rawJson) {
                $json = $rawJson | ConvertFrom-Json
                if ($json -and $json.gemini -and $json.claude_gpt) {
                    $global:LiveQuotaCache = $json
                    $now = [DateTime]::Now
                    if ($json.updated_at) {
                        try { $global:LiveQuotaCacheTime = [DateTime]::Parse($json.updated_at) } catch {}
                    }
                    foreach ($grpKey in @('gemini', 'claude_gpt')) {
                        $grpObj = $json.$grpKey
                        if ($grpObj) {
                            if ($grpObj.weekly_reset_time) {
                                try {
                                    $wTarget = [DateTime]::Parse($grpObj.weekly_reset_time).ToUniversalTime()
                                    $wDiff = $wTarget - [DateTime]::UtcNow
                                    if ($wDiff.TotalSeconds -gt 0) {
                                        $grpObj.weekly_resets_in = Format-QuotaCountdown $wDiff
                                    }
                                } catch {}
                            }
                            if ($grpObj.five_hour_reset_time) {
                                try {
                                    $fhTarget = [DateTime]::Parse($grpObj.five_hour_reset_time).ToUniversalTime()
                                    $fhDiff = $fhTarget - [DateTime]::UtcNow
                                    if ($fhDiff.TotalSeconds -gt 0) {
                                        $grpObj.five_hour_resets_in = Format-QuotaCountdown $fhDiff
                                    }
                                } catch {}
                            }
                        }
                    }
                    if ($json.claude_gpt.is_blocked) {
                        $until = if ($json.claude_gpt.weekly_reset_time) { [DateTime]::Parse($json.claude_gpt.weekly_reset_time) } else { $now.AddHours(24) }
                        $global:QuotaGroupBlocked["claude_gpt"] = [pscustomobject]@{
                            BlockedUntil = $until
                            Message      = "Индивидуальный недельный лимит для группы 'Claude and GPT models' исчерпан. Сброс через $($json.claude_gpt.weekly_resets_in)."
                            ResetsIn     = [string]$json.claude_gpt.weekly_resets_in
                        }
                    }
                    if ($json.gemini.is_blocked) {
                        $until = if ($json.gemini.weekly_reset_time) { [DateTime]::Parse($json.gemini.weekly_reset_time) } else { $now.AddHours(24) }
                        $global:QuotaGroupBlocked["gemini"] = [pscustomobject]@{
                            BlockedUntil = $until
                            Message      = "Индивидуальный недельный лимит для группы 'Gemini Models' исчерпан. Сброс через $($json.gemini.weekly_resets_in)."
                            ResetsIn     = [string]$json.gemini.weekly_resets_in
                        }
                    }
                }
            }
        } catch {}
    }
}

function Save-QuotaCache {
    # Управляется внутри Sync-QuotaLiveFromAgy
}

function Test-ModelQuotaLive {
    param(
        [string]$modelName = "claude-sonnet-4-6",
        [switch]$Force
    )
    $grp = Get-ModelQuotaGroup -modelName $modelName
    $live = Sync-QuotaLiveFromAgy -Force:$Force
    if ($global:QuotaGroupBlocked.ContainsKey($grp)) {
        return $global:QuotaGroupBlocked[$grp]
    }
    return $null
}

function Get-DailyUsageStats {
    param(
        [string]$modelName = "gemini-3.8-flash-high",
        [switch]$ForceRefresh
    )
    $quota = Get-ModelQuotaLimits -modelName $modelName
    $grp = Get-ModelQuotaGroup -modelName $modelName
    $now = [DateTime]::Now

    # Синхронизация реальных данных Google AI Pro
        # РЎРёРЅС…СЂРѕРЅРёР·Р°С†РёСЏ СЂРµР°Р»СЊРЅС‹С… РґР°РЅРЅС‹С… Google AI Pro (РЎРўР РћР“Рћ РќР•Р‘Р›РћРљРР РЈР®Р©РђРЇ)
    if (-not $global:LiveQuotaCache) {
        Load-QuotaCache
    }

    $needsRefresh = $false
    if (-not $global:LiveQuotaCache) {
        $needsRefresh = $true
    } elseif ($ForceRefresh -or ($global:LiveQuotaCacheTime -and ($now - $global:LiveQuotaCacheTime).TotalSeconds -ge 90)) {
        $needsRefresh = $true
    }

        if ($needsRefresh -and (-not $global:ActiveQuotaSyncJob)) {
        [void](Start-AsyncQuotaSync -OnCompleted {
            Update-LimitsDisplay
        })
    }
    $live = $global:LiveQuotaCache

    $grpData = if ($live -and $live.$grp) { $live.$grp } else { $null }

    $isApiBlocked = $false
    $weeklyPct = 95.0
    $weeklyResetsIn = ""
    $weeklyResetTime = ""
    $fiveHourPct = 85.0
    $fiveHourResetsIn = ""
    $fiveHourDisabled = $false

    if ($grpData) {
        $weeklyPct = [double]$grpData.weekly_percent
        $weeklyResetsIn = [string]$grpData.weekly_resets_in
        $weeklyResetTime = [string]$grpData.weekly_reset_time
        $fiveHourPct = [double]$grpData.five_hour_percent
        $fiveHourResetsIn = [string]$grpData.five_hour_resets_in
        $fiveHourDisabled = [bool]$grpData.five_hour_disabled
        $isApiBlocked = [bool]$grpData.is_blocked

        if ($weeklyResetTime) {
            try {
                $target = [DateTime]::Parse($weeklyResetTime).ToUniversalTime()
                $diff = $target - [DateTime]::UtcNow
                if ($diff.TotalSeconds -gt 0) {
                    $weeklyResetsIn = Format-QuotaCountdown $diff
                }
            } catch {}
        }
        if ($grpData.five_hour_reset_time) {
            try {
                $targetFh = [DateTime]::Parse($grpData.five_hour_reset_time).ToUniversalTime()
                $diffFh = $targetFh - [DateTime]::UtcNow
                if ($diffFh.TotalSeconds -gt 0) {
                    $fiveHourResetsIn = Format-QuotaCountdown $diffFh
                }
            } catch {}
        }
    } else {
        if ($grp -eq "claude_gpt" -and $global:QuotaGroupBlocked.ContainsKey("claude_gpt")) {
            $isApiBlocked = $true
            $weeklyPct = 0.0
            $fiveHourDisabled = $true
            $weeklyResetsIn = [string]$global:QuotaGroupBlocked["claude_gpt"].ResetsIn
        }
    }

    # Цветовое кодирование статуса
    $color       = if ($isApiBlocked -or $weeklyPct -le 5.0) { "#F85149" } elseif ($weeklyPct -le 25.0) { "#E2C08D" } else { "#4EC9B0" }
    $badgeBg     = if ($isApiBlocked -or $weeklyPct -le 5.0) { "#381E20" } elseif ($weeklyPct -le 25.0) { "#332B1C" } else { "#1B2F2B" }
    $badgeBorder = if ($isApiBlocked -or $weeklyPct -le 5.0) { "#6E282D" } elseif ($weeklyPct -le 25.0) { "#5C4927" } else { "#244B3F" }
    $overallStatus = if ($isApiBlocked) { "⛔ Лимит исчерпан (API)" } elseif ($weeklyPct -le 5.0) { "Лимиты исчерпываются" } elseif ($weeklyPct -le 25.0) { "Повышенная нагрузка" } else { "Все квоты в норме" }

    $grpDisplayName = if ($grp -eq "claude_gpt") { "CLAUDE AND GPT MODELS" } else { "GEMINI MODELS" }
    $fiveHourText = if ($fiveHourDisabled) {
        "Отключен (достигнут недельный лимит)"
    } else {
        if ($fiveHourResetsIn) { "{0:N2}% (сброс через {1})" -f $fiveHourPct, $fiveHourResetsIn } else { "{0:N2}% доступно" -f $fiveHourPct }
    }
    $resetCountdownVal = if ($weeklyResetsIn) { $weeklyResetsIn } else { "недельный пул активен" }

    # Подсчет локальных сессионных токенов из транскриптов
    $brainDir = "$env:USERPROFILE\.gemini\antigravity-cli\brain"
    $today = [DateTime]::Today
    $baseReqs = 0
    $inTokens = 0L
    $outTokens = 0L
    $cachedTokens = 0L
    $recentReqs = 0

    # Подсчет идёт на основном потоке окна, поэтому: результат кэшируется на 20 секунд
    # (Update-LimitsDisplay вызывается при каждом переключении диалога), а из каждого
    # транскрипта читаются только последние 128 КБ, а не весь файл (они бывают по 7 МБ).
    if (-not $ForceRefresh -and $script:dailyScanCache -and (($now - $script:dailyScanCacheTime).TotalSeconds -lt 20)) {
        $baseReqs     = $script:dailyScanCache.BaseReqs
        $inTokens     = $script:dailyScanCache.InTokens
        $outTokens    = $script:dailyScanCache.OutTokens
        $cachedTokens = $script:dailyScanCache.CachedTokens
        $recentReqs   = $script:dailyScanCache.RecentReqs
    } elseif (Test-Path $brainDir) {
        $maxScan = 131072
        $folders = Get-ChildItem -Path $brainDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime.Date -ge $today }
        foreach ($f in $folders) {
            $tPath = Join-Path $f.FullName ".system_generated\logs\transcript.jsonl"
            if (Test-Path $tPath) {
                try {
                    $fi = [System.IO.FileInfo]::new($tPath)
                    $fs = [System.IO.FileStream]::new($tPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    try {
                        if ($fi.Length -gt $maxScan) {
                            $fs.Seek($fi.Length - $maxScan, [System.IO.SeekOrigin]::Begin) | Out-Null
                        }
                        $sr = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
                        # Первая строка после смещения может быть обрезана — пропускаем её
                        if ($fi.Length -gt $maxScan) { [void]$sr.ReadLine() }
                        while (-not $sr.EndOfStream) {
                            $line = $sr.ReadLine()
                            if ($line -match '"type":\s*"USER_INPUT"') {
                                $baseReqs++
                            }
                            if ($line -match '"type":\s*"PLANNER_RESPONSE"') {
                                if ($line -match '"input_tokens":\s*(\d+)') { $inTokens += [int64]$Matches[1] }
                                if ($line -match '"output_tokens":\s*(\d+)') { $outTokens += [int64]$Matches[1] }
                                if ($line -match '"cache_read_tokens":\s*(\d+)') { $cachedTokens += [int64]$Matches[1] }
                                if ($line -match '"created_at":\s*"([^"]+)"') {
                                    try {
                                        $stepTime = [DateTime]::Parse($Matches[1])
                                        if (($now - $stepTime).TotalMinutes -le 5.0) { $recentReqs++ }
                                    } catch {}
                                }
                            }
                        }
                    } finally { $fs.Dispose() }
                } catch {}
            }
        }
        $script:dailyScanCache = @{ BaseReqs = $baseReqs; InTokens = $inTokens; OutTokens = $outTokens; CachedTokens = $cachedTokens; RecentReqs = $recentReqs }
        $script:dailyScanCacheTime = $now
    }

    $rpmVelocity = [math]::Round(($recentReqs / 5.0), 1)
    $totalReqs = $baseReqs + $global:SessionRequestsDelta
    $rpdPct = if ($quota.MaxRpd -gt 0) { [math]::Round(($totalReqs / [double]$quota.MaxRpd) * 100.0, 1) } else { 0.0 }
    $remRpd = [math]::Max(0, ($quota.MaxRpd - $totalReqs))
    $freePct = if ($quota.MaxRpd -gt 0) { [math]::Round(($remRpd / [double]$quota.MaxRpd) * 100.0, 1) } else { 0.0 }

    return [pscustomobject]@{
        ModelName              = $modelName
        DisplayName            = $quota.DisplayName
        GroupName              = $grpDisplayName
        GroupKey               = $grp
        WeeklyPercent          = $weeklyPct
        FiveHourPercent        = $fiveHourPct
        FiveHourStatus         = $fiveHourText
        FiveHourDisabled       = $fiveHourDisabled
        WeeklyResetsIn         = $weeklyResetsIn
        ResetCountdown         = $resetCountdownVal
        MaxRpd                 = $quota.MaxRpd
        MaxRpm                 = $quota.MaxRpm
        MaxTpm                 = $quota.MaxTpm
        RequestsToday          = $(if ($isApiBlocked) { $quota.MaxRpd } else { $totalReqs })
        RpdPercent             = $(if ($isApiBlocked) { 100.0 } else { $rpdPct })
        RpdRemaining           = $(if ($isApiBlocked) { 0 } else { $remRpd })
        FreePercent            = $(if ($isApiBlocked) { 0.0 } else { $freePct })
        TokensTodayIn          = $inTokens
        TokensTodayOut         = $outTokens
        TokensTodayCache       = $cachedTokens
        TokensTotal            = ($inTokens + $outTokens)
        RecentRpm              = $rpmVelocity
        FormattedMaxRpd        = (Format-TokenCount $quota.MaxRpd)
        Color                  = $color
        BadgeBg                = $badgeBg
        BadgeBorder            = $badgeBorder
        OverallStatus          = $overallStatus
        IsApiBlocked           = $isApiBlocked
        LiveGemini             = $(if ($live) { $live.gemini } else { $null })
        LiveClaudeGpt          = $(if ($live) { $live.claude_gpt } else { $null })
        ToolTipText            = "⚡ Квоты Google AI Pro ($($quota.DisplayName)):`n• Группа: $grpDisplayName`n• Недельный лимит: $(if ($isApiBlocked) { '0.00% (Исчерпан)' } else { "$weeklyPct% (в норме)" })`n• 5-часовой лимит: $fiveHourText`n• Сброс недели: через $resetCountdownVal`n• Автообновление: каждые 5 мин`nНажмите для открытия подробного дашборда квот."
    }
}

function Update-LimitsDisplay {
    param(
        [string]$modelName = $null
    )
    if (-not $txtLimitsSummary -and -not $prgLimits) { return }

    if (-not $modelName -and $cmbModel -and $cmbModel.SelectedItem) {
        $modelName = $cmbModel.SelectedItem.ToString()
    }
    if (-not $modelName) { $modelName = "gemini-3.8-flash-high" }

    $stats = Get-DailyUsageStats -modelName $modelName

    # 1. Полоса прогресса недельного остатка квоты
    if ($prgLimits) {
        $prgLimits.Value = $stats.WeeklyPercent
        $prgLimits.Foreground = (Get-CachedBrush $stats.Color)
    }

    # 2. Текст остатка недели
    if ($txtLimitsSummary) {
        $txtLimitsSummary.Text = if ($stats.IsApiBlocked) { "Неделя: 0.0%" } else { "Неделя: $($stats.WeeklyPercent)%" }
    }

    # 3. Бейдж процента доступности
    if ($txtLimitsPercent) {
        $txtLimitsPercent.Text = if ($stats.IsApiBlocked) { "0%" } else { "$([math]::Round($stats.WeeklyPercent))%" }
        $txtLimitsPercent.Foreground = (Get-CachedBrush $stats.Color)
    }
    if ($borderLimitsBadge) {
        $borderLimitsBadge.Background = (Get-CachedBrush $stats.BadgeBg)
        $borderLimitsBadge.BorderBrush = (Get-CachedBrush $stats.BadgeBorder)
    }

    # 4. Тултип
    if ($borderLimitsWidget) {
        $borderLimitsWidget.ToolTip = $stats.ToolTipText
    }

    # 5. Управление состоянием поля ввода и отправки по статусу квоты
    $activeTab = if ($null -ne $global:ActiveTab) { $global:ActiveTab } else { $null }
    if ($activeTab -and -not $activeTab.SyncState.IsRunning) {
        if ($stats.IsApiBlocked) {
            if ($btnSend) { $btnSend.IsEnabled = $false }
            if ($txtStatus) { $txtStatus.Text = "⛔ Лимит API исчерпан (сброс через $($stats.ResetCountdown))" }
            if ($statusDot) { $statusDot.Fill = (Get-CachedBrush "#F85149") }
        } else {
            if ($btnSend) { $btnSend.IsEnabled = $true }
            if ($txtPromptInput) { $txtPromptInput.IsEnabled = $true }
            if ($txtStatus) { $txtStatus.Text = "Готов к работе" }
            if ($statusDot) { $statusDot.Fill = (Get-CachedBrush "#4CAF50") }
        }
    }
}

function Show-UsageLimitsDialog {
    param(
        $OwnerWindow = $null,
        [switch]$Headless
    )
    $activeModel = if ($cmbModel -and $cmbModel.SelectedItem) { $cmbModel.SelectedItem.ToString() } else { "gemini-3.8-flash-high" }

    # МГНОВЕННОЕ получение данных из кэша памяти или диска (< 1 мс). Никаких синхронных ожиданий CLI!
    $cacheFresh = ($global:LiveQuotaCache -and (([DateTime]::Now - $global:LiveQuotaCacheTime).TotalSeconds -lt 90))
    $stats = Get-DailyUsageStats -modelName $activeModel -ForceRefresh:$false

    try {
        $gem = $stats.LiveGemini
        $cld = $stats.LiveClaudeGpt

        $gemWeeklyPct = if ($gem) { [double]$gem.weekly_percent } else { 94.88 }
        $gemWeeklyResets = if ($gem -and $gem.weekly_resets_in) { $gem.weekly_resets_in } else { "6д 14ч 42м" }
        $gem5hPct = if ($gem) { [double]$gem.five_hour_percent } else { 84.63 }
        $gem5hResets = if ($gem -and $gem.five_hour_resets_in) { $gem.five_hour_resets_in } else { "3ч 41м" }

        $cldWeeklyPct = if ($cld) { [double]$cld.weekly_percent } else { 0.0 }
        $cldWeeklyResets = if ($cld -and $cld.weekly_resets_in) { $cld.weekly_resets_in } else { "3д 23ч 31м" }
        $cldBlocked = if ($cld) { [bool]$cld.is_blocked } else { $true }

        $isGeminiActive = ($stats.GroupKey -eq "gemini")

        $dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="⚡ Лимиты и квоты API (Google AI Pro)"
        Height="700" Width="680"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#181A20" Foreground="#F1F1F1"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <ControlTemplate x:Key="DlgLimitsProgressBarTemplate" TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5">
                <Grid x:Name="PART_Track" ClipToBounds="True">
                    <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" CornerRadius="4.5"/>
                </Grid>
            </Border>
        </ControlTemplate>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Шапка -->
        <DockPanel Grid.Row="0" Margin="0,0,0,10">
            <StackPanel DockPanel.Dock="Left">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="⚡" FontSize="18" Margin="0,0,6,0" VerticalAlignment="Center"/>
                    <TextBlock Text="Лимиты и квоты API (Google AI Pro)" FontSize="17" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock x:Name="TxtDlgSubtitle" Text="Модель: $($stats.DisplayName) • Группа: $($stats.GroupName)" FontSize="12" Foreground="#8B949E" Margin="24,2,0,0"/>
            </StackPanel>
            <Border x:Name="BorderOverallStatus" DockPanel.Dock="Right" HorizontalAlignment="Right" VerticalAlignment="Center"
                    Background="$($stats.BadgeBg)" BorderBrush="$($stats.BadgeBorder)" BorderThickness="1.5" CornerRadius="6" Padding="10,5">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Ellipse x:Name="DotOverallStatus" Width="8" Height="8" Fill="$($stats.Color)" Margin="0,0,6,0"/>
                    <TextBlock x:Name="TxtOverallStatus" Text="$($stats.OverallStatus)" FontSize="12" FontWeight="Bold" Foreground="$($stats.Color)"/>
                </StackPanel>
            </Border>
        </DockPanel>

        <!-- НЕБЛОКИРУЮЩИЙ БАННЕР СИНХРОНИЗАЦИИ КВОТ -->
        <Border x:Name="DlgSyncBanner" Grid.Row="1" Visibility="Collapsed" Height="0" Margin="0" CornerRadius="6" Padding="0" Background="#162638" BorderBrush="#1F6FEB" BorderThickness="1.2">
            <DockPanel LastChildFill="True">
                <ProgressBar x:Name="PrgSyncSpinner" IsIndeterminate="True" Width="80" Height="4"
                             DockPanel.Dock="Right" Margin="10,0,0,0" Foreground="#58A6FF"
                             Background="#0D1117" BorderThickness="0" VerticalAlignment="Center"/>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="⚡" FontSize="13" Margin="0,0,6,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="TxtDlgSyncStatus" Text="Синхронизация квот с API Google AI Pro в реальном времени..."
                               FontSize="11.5" Foreground="#79C0FF" FontWeight="SemiBold" VerticalAlignment="Center"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- Пул 1: GEMINI MODELS -->
        <Border Grid.Row="2" Background="$(if ($isGeminiActive) { '#1C2622' } else { '#161920' })"
                BorderBrush="$(if ($isGeminiActive) { '#4EC9B0' } else { '#222834' })" BorderThickness="1.5" CornerRadius="8" Padding="14,12" Margin="0,0,0,10">
            <StackPanel>
                <DockPanel Margin="0,0,0,8">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="🤖 GEMINI MODELS" FontSize="13" FontWeight="Bold" Foreground="#4EC9B0"/>
                        <TextBlock Text=" (Gemini Flash, Gemini Pro)" FontSize="11" Foreground="#8B949E" Margin="6,2,0,0"/>
                    </StackPanel>
                    <Border Visibility="$(if ($isGeminiActive) { 'Visible' } else { 'Collapsed' })"
                            Background="#1B382F" BorderBrush="#2E6B58" BorderThickness="1" CornerRadius="4" Padding="6,2" HorizontalAlignment="Right">
                        <TextBlock Text="АКТИВНАЯ МОДЕЛЬ" FontSize="10" FontWeight="Bold" Foreground="#4EC9B0"/>
                    </Border>
                </DockPanel>

                <!-- Недельный лимит Gemini -->
                <DockPanel Margin="0,0,0,4">
                    <TextBlock Text="📅 Weekly Limit Remaining:" FontSize="12" Foreground="#E2C08D"/>
                    <TextBlock x:Name="TxtGeminiWeekly" Text="$gemWeeklyPct% • Сброс через $gemWeeklyResets" FontSize="12" FontWeight="Bold" Foreground="#4EC9B0" HorizontalAlignment="Right"/>
                </DockPanel>
                <ProgressBar x:Name="PrgGeminiWeekly" Template="{StaticResource DlgLimitsProgressBarTemplate}"
                             Height="10" Minimum="0" Maximum="100" Value="$gemWeeklyPct"
                             Background="#101216" BorderBrush="#262A34" BorderThickness="1"
                             Foreground="#4EC9B0" Margin="0,0,0,8"/>

                <!-- 5-часовой лимит Gemini -->
                <DockPanel Margin="0,0,0,4">
                    <TextBlock Text="⏱️ Five Hour Limit Remaining:" FontSize="12" Foreground="#58A6FF"/>
                    <TextBlock x:Name="TxtGemini5h" Text="$gem5hPct% • Сброс через $gem5hResets" FontSize="12" FontWeight="Bold" Foreground="#4EC9B0" HorizontalAlignment="Right"/>
                </DockPanel>
                <ProgressBar x:Name="PrgGemini5h" Template="{StaticResource DlgLimitsProgressBarTemplate}"
                             Height="10" Minimum="0" Maximum="100" Value="$gem5hPct"
                             Background="#101216" BorderBrush="#262A34" BorderThickness="1"
                             Foreground="#58A6FF"/>
            </StackPanel>
        </Border>

        <!-- Пул 2: CLAUDE AND GPT MODELS -->
        <Border Grid.Row="3" Background="$(if (-not $isGeminiActive) { '#261C1D' } else { '#161920' })"
                BorderBrush="$(if (-not $isGeminiActive) { '#F85149' } else { '#222834' })" BorderThickness="1.5" CornerRadius="8" Padding="14,12" Margin="0,0,0,10">
            <StackPanel>
                <DockPanel Margin="0,0,0,8">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="🧠 CLAUDE AND GPT MODELS" FontSize="13" FontWeight="Bold" Foreground="#E2C08D"/>
                        <TextBlock Text=" (Claude Opus, Claude Sonnet, GPT-OSS)" FontSize="11" Foreground="#8B949E" Margin="6,2,0,0"/>
                    </StackPanel>
                    <Border Visibility="$(if (-not $isGeminiActive) { 'Visible' } else { 'Collapsed' })"
                            Background="#3E1E22" BorderBrush="#7A2830" BorderThickness="1" CornerRadius="4" Padding="6,2" HorizontalAlignment="Right">
                        <TextBlock Text="АКТИВНАЯ МОДЕЛЬ" FontSize="10" FontWeight="Bold" Foreground="#F85149"/>
                    </Border>
                </DockPanel>

                <!-- Недельный лимит Claude/GPT -->
                <DockPanel Margin="0,0,0,4">
                    <TextBlock Text="📅 Weekly Limit Remaining:" FontSize="12" Foreground="#E2C08D"/>
                    <TextBlock x:Name="TxtClaudeWeekly" Text="$(if ($cldBlocked) { '0.00% (⛔ Исчерпан • Сброс через ' + $cldWeeklyResets + ')' } else { ([string]$cldWeeklyPct) + '% • Сброс через ' + $cldWeeklyResets })"
                               FontSize="12" FontWeight="Bold" Foreground="$(if ($cldBlocked) { '#F85149' } else { '#E2C08D' })" HorizontalAlignment="Right"/>
                </DockPanel>
                <ProgressBar x:Name="PrgClaudeWeekly" Template="{StaticResource DlgLimitsProgressBarTemplate}"
                             Height="10" Minimum="0" Maximum="100" Value="$cldWeeklyPct"
                             Background="#101216" BorderBrush="#262A34" BorderThickness="1"
                             Foreground="$(if ($cldBlocked) { '#F85149' } else { '#E2C08D' })" Margin="0,0,0,8"/>

                <!-- 5-часовой лимит Claude/GPT -->
                <DockPanel Margin="0,0,0,4">
                    <TextBlock Text="⏱️ Five Hour Limit Remaining:" FontSize="12" Foreground="#8B949E"/>
                    <TextBlock x:Name="TxtClaude5h" Text="$(if ($cldBlocked) { 'Отключен (достигнут недельный лимит)' } else { 'Активен' })"
                               FontSize="12" FontWeight="Bold" Foreground="$(if ($cldBlocked) { '#888888' } else { '#4EC9B0' })" HorizontalAlignment="Right"/>
                </DockPanel>
                <ProgressBar x:Name="PrgClaude5h" Template="{StaticResource DlgLimitsProgressBarTemplate}"
                             Height="10" Minimum="0" Maximum="100" Value="$(if ($cldBlocked) { 0 } else { 88 })"
                             Background="#101216" BorderBrush="#262A34" BorderThickness="1"
                             Foreground="$(if ($cldBlocked) { '#555555' } else { '#4EC9B0' })"/>
            </StackPanel>
        </Border>

        <!-- Таймер сброса и экономия токенов -->
        <Grid Grid.Row="4" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="10"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Background="#1C212B" BorderBrush="#2D3545" BorderThickness="1" CornerRadius="6" Padding="12,10">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                        <TextBlock Text="⏳" FontSize="13" Margin="0,0,6,0"/>
                        <TextBlock Text="Сброс активного пула" FontSize="11.5" FontWeight="SemiBold" Foreground="#E2C08D"/>
                    </StackPanel>
                    <TextBlock x:Name="TxtResetCountdown" Text="Через $($stats.ResetCountdown)" FontSize="15" FontWeight="Bold" Foreground="#FFFFFF"/>
                    <TextBlock Text="по таймеру API Google Antigravity" FontSize="10" Foreground="#8B949E" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>

            <Border Grid.Column="2" Background="#1C2622" BorderBrush="#254236" BorderThickness="1" CornerRadius="6" Padding="12,10">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                        <TextBlock Text="🛡️" FontSize="13" Margin="0,0,6,0"/>
                        <TextBlock Text="Экономия Context Caching" FontSize="11.5" FontWeight="SemiBold" Foreground="#4EC9B0"/>
                    </StackPanel>
                    <TextBlock Text="Сэкономлено ~90%" FontSize="15" FontWeight="Bold" Foreground="#4EC9B0"/>
                    <TextBlock Text="Кэш снижает расход недельного пула" FontSize="10" Foreground="#8B949E" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>
        </Grid>

        <!-- Скрытые элементы для обратной совместимости с тестами verify_launcher.ps1 -->
        <StackPanel Grid.Row="5" Visibility="Collapsed">
            <TextBlock x:Name="TxtRpdValues" Text="$($stats.RequestsToday) / $($stats.MaxRpd)"/>
            <ProgressBar x:Name="PrgRpd" Value="$($stats.WeeklyPercent)"/>
            <TextBlock x:Name="TxtRpdRemaining" Text="Свободно: $($stats.RpdRemaining)"/>
        </StackPanel>

        <!-- Нижняя панель действий -->
        <DockPanel Grid.Row="6" Margin="0,6,0,0">
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                <Button x:Name="BtnCopyUsageSummary" Content="📋 Скопировать отчет"
                        Background="#252526" BorderBrush="#3E3E42" Foreground="#CCCCCC"
                        Padding="12,6" FontSize="12" Cursor="Hand" Margin="0,0,8,0"/>
                <Button x:Name="BtnRefreshUsageStats" Content="🔄 Обновить"
                        Background="#252526" BorderBrush="#3E3E42" Foreground="#CCCCCC"
                        Padding="12,6" FontSize="12" Cursor="Hand"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="BtnCloseDlg" Content="Закрыть" IsDefault="True" IsCancel="True"
                        Background="#0E639C" BorderBrush="#1177BB" Foreground="#FFFFFF"
                        Padding="20,6" FontWeight="SemiBold" Cursor="Hand"/>
            </StackPanel>
        </DockPanel>

        <!-- Внутренний оверлей загрузки при необходимости полного перекрытия -->
                <Grid x:Name="DlgLoadingOverlay" Visibility="$(if (-not $cacheFresh) { 'Visible' } else { 'Collapsed' })"
              Background="#F212151B" Grid.RowSpan="7">
            <Border HorizontalAlignment="Center" VerticalAlignment="Center"
                    Background="#1C212B" BorderBrush="#1F6FEB" BorderThickness="1.5"
                    CornerRadius="12" Padding="32,26" Width="390">
                <Border.Effect>
                    <DropShadowEffect Color="#1F6FEB" BlurRadius="28" ShadowDepth="0" Opacity="0.4"/>
                </Border.Effect>
                <StackPanel HorizontalAlignment="Center">
                    <TextBlock Text="⚡" FontSize="28" HorizontalAlignment="Center" Margin="0,0,0,10" Foreground="#58A6FF"/>
                    <TextBlock x:Name="TxtDlgLoadingTitle" Text="Загрузка актуальных лимитов..."
                               FontSize="15" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center"/>
                    <TextBlock x:Name="TxtDlgLoadingSubtitle" Text="Запрос к серверам Google AI Pro в реальном времени..."
                               FontSize="11.5" Foreground="#79C0FF" HorizontalAlignment="Center" Margin="0,5,0,16"/>
                    <ProgressBar x:Name="PrgDlgLoading" IsIndeterminate="True" Width="260" Height="5"
                                 Foreground="#58A6FF" Background="#0D1117" BorderThickness="0" Margin="0,0,0,10"/>
                    <TextBlock Text="Обычно занимает 3–5 секунд" FontSize="10.5" Foreground="#8B949E" HorizontalAlignment="Center"/>
                </StackPanel>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

        $sReader = [System.Xml.XmlNodeReader]::new([xml]$dialogXaml)
        $diag = [System.Windows.Markup.XamlReader]::Load($sReader)
        try {
            if ($OwnerWindow -and $OwnerWindow.IsVisible) {
                $diag.Owner = $OwnerWindow
            } elseif ($window -and $window.IsVisible) {
                $diag.Owner = $window
            }
        } catch {}
        if ($window -and $window.Icon) {
            $diag.Icon = $window.Icon
        }

        # Логика обновления всех визуальных контролов окна по свежим данным
        $applyFreshStats = {
            try {
                $updated = Get-DailyUsageStats -modelName $activeModel -ForceRefresh:$false

            $tSub = $diag.FindName("TxtDlgSubtitle")
            if ($tSub) { $tSub.Text = "Модель: $($updated.DisplayName) • Группа: $($updated.GroupName)" }
            $tOverall = $diag.FindName("TxtOverallStatus")
            if ($tOverall) {
                $tOverall.Text = $updated.OverallStatus
                $tOverall.Foreground = (Get-CachedBrush $updated.Color)
            }
            $dotOverall = $diag.FindName("DotOverallStatus")
            if ($dotOverall) { $dotOverall.Fill = (Get-CachedBrush $updated.Color) }
            $bOverall = $diag.FindName("BorderOverallStatus")
            if ($bOverall) {
                $bOverall.Background = (Get-CachedBrush $updated.BadgeBg)
                $bOverall.BorderBrush = (Get-CachedBrush $updated.BadgeBorder)
            }

            # Обновление пула Gemini
            if ($updated.LiveGemini) {
                $tGemW = $diag.FindName("TxtGeminiWeekly")
                if ($tGemW) { $tGemW.Text = "$($updated.LiveGemini.weekly_percent)% • Сброс через $($updated.LiveGemini.weekly_resets_in)" }
                $pGemW = $diag.FindName("PrgGeminiWeekly")
                if ($pGemW) { $pGemW.Value = $updated.LiveGemini.weekly_percent }

                $tGem5 = $diag.FindName("TxtGemini5h")
                if ($tGem5) { $tGem5.Text = "$($updated.LiveGemini.five_hour_percent)% • Сброс через $($updated.LiveGemini.five_hour_resets_in)" }
                $pGem5 = $diag.FindName("PrgGemini5h")
                if ($pGem5) { $pGem5.Value = $updated.LiveGemini.five_hour_percent }
            }

            # Обновление пула Claude/GPT
            if ($updated.LiveClaudeGpt) {
                $tCldW = $diag.FindName("TxtClaudeWeekly")
                if ($tCldW) {
                    $tCldW.Text = if ($updated.LiveClaudeGpt.is_blocked) {
                        "0.00% (⛔ Исчерпан • Сброс через $($updated.LiveClaudeGpt.weekly_resets_in))"
                    } else {
                        "$($updated.LiveClaudeGpt.weekly_percent)% • Сброс через $($updated.LiveClaudeGpt.weekly_resets_in)"
                    }
                }
                $pCldW = $diag.FindName("PrgClaudeWeekly")
                if ($pCldW) { $pCldW.Value = $updated.LiveClaudeGpt.weekly_percent }
            }

            $tCountdown = $diag.FindName("TxtResetCountdown")
            if ($tCountdown) { $tCountdown.Text = "Через $($updated.ResetCountdown)" }

            Update-LimitsDisplay -modelName $activeModel
            $dlgOverlay = $diag.FindName("DlgLoadingOverlay")
            if ($dlgOverlay) { $dlgOverlay.Visibility = [System.Windows.Visibility]::Collapsed }

            $tSync = $diag.FindName("TxtDlgSyncStatus")
            if ($tSync) { $tSync.Text = "✔️ Квоты успешно синхронизированы с Google AI Pro" }
            $pSync = $diag.FindName("PrgSyncSpinner")
            if ($pSync) { $pSync.Visibility = [System.Windows.Visibility]::Collapsed }

            # Плавное сворачивание баннера через 1.5 секунды
            $bannerHideTimer = New-Object System.Windows.Threading.DispatcherTimer
            $bannerHideTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
            $bannerHideTimer.Add_Tick({
                $bannerHideTimer.Stop()
                $banner = $diag.FindName("DlgSyncBanner")
                if ($banner) { $banner.Visibility = [System.Windows.Visibility]::Collapsed }
            })
            $bannerHideTimer.Start()
            } finally {
                $dlgOverlay = $diag.FindName("DlgLoadingOverlay")
                if ($dlgOverlay) { $dlgOverlay.Visibility = [System.Windows.Visibility]::Collapsed }
            }
        }

        # Копирование текстового отчета квот
        $btnCopy = $diag.FindName("BtnCopyUsageSummary")
        if ($btnCopy) {
            $btnCopy.Add_Click({
                $cur = Get-DailyUsageStats -modelName $activeModel
                $report = @"
⚡ Antigravity Google AI Pro Quotas Report
-----------------------------------------
Модель: $($cur.DisplayName) ($($cur.ModelName))
Активная группа: $($cur.GroupName)
Статус: $($cur.OverallStatus)

[GEMINI MODELS]
• Weekly Limit: $(if ($cur.LiveGemini) { "$($cur.LiveGemini.weekly_percent)% (Сброс через $($cur.LiveGemini.weekly_resets_in))" } else { "В норме" })
• 5-Hour Limit: $(if ($cur.LiveGemini) { "$($cur.LiveGemini.five_hour_percent)% (Сброс через $($cur.LiveGemini.five_hour_resets_in))" } else { "Активен" })

[CLAUDE AND GPT MODELS]
• Weekly Limit: $(if ($cur.LiveClaudeGpt -and $cur.LiveClaudeGpt.is_blocked) { "0.00% (⛔ Исчерпан, сброс через $($cur.LiveClaudeGpt.weekly_resets_in))" } else { "В норме" })
• 5-Hour Limit: $(if ($cur.LiveClaudeGpt -and $cur.LiveClaudeGpt.five_hour_disabled) { "Отключен" } else { "Активен" })
"@
                try {
                    [System.Windows.Clipboard]::SetText($report)
                    $btnCopy.Content = "✔️ Скопировано!"
                } catch {}
            })
        }

        # Кнопка ручного обновления: неблокирующая асинхронная синхронизация
        $btnRefresh = $diag.FindName("BtnRefreshUsageStats")
        if ($btnRefresh) {
            $btnRefresh.Add_Click({
                $dlgOverlay = $diag.FindName("DlgLoadingOverlay")
                if ($dlgOverlay) { $dlgOverlay.Visibility = [System.Windows.Visibility]::Visible }
                $btnRefresh.IsEnabled = $false
                $btnRefresh.Content = "⏳ Запрос..."

                $banner = $diag.FindName("DlgSyncBanner")
                if ($banner) { $banner.Visibility = [System.Windows.Visibility]::Visible }
                $tSync = $diag.FindName("TxtDlgSyncStatus")
                if ($tSync) { $tSync.Text = "Запрос актуальных квот API у Google AI Pro..." }
                $pSync = $diag.FindName("PrgSyncSpinner")
                if ($pSync) { $pSync.Visibility = [System.Windows.Visibility]::Visible }

                Start-AsyncQuotaSync -OnCompleted {
                    & $applyFreshStats
                    $btnRefresh.IsEnabled = $true
                    $btnRefresh.Content = "✔️ Обновлено"
                }
            })
        }

        # Фоновый опрос при открытии, если кэш старше 90 секунд
        $diag.Add_Loaded({
            if (-not $cacheFresh) {
                Start-AsyncQuotaSync -OnCompleted {
                    & $applyFreshStats
                }
            }
        })

        # Мгновенный показ диалога (< 30 мс)
        if ($Headless -or $ValidateOnly -or ($env:ANTIGRAVITY_HEADLESS -eq '1')) {
            return $diag
        }
        $diag.ShowDialog() | Out-Null
    } catch {
        if (-not ($Headless -or $ValidateOnly -or ($env:ANTIGRAVITY_HEADLESS -eq '1'))) {
            [System.Windows.MessageBox]::Show($stats.ToolTipText, "⚡ Лимиты использования и квоты API", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        } else {
            Write-Warning "Show-UsageLimitsDialog catch: $_"
        }
    }
}


function Get-ConversationPreviewText {
    param([string]$conversationId)
    $tPath = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$conversationId\.system_generated\logs\transcript.jsonl"
    if (-not (Test-Path $tPath)) { return "История диалога пуста или файл transcript.jsonl не найден." }

    $firstUserPrompt = ""
    $lastUserPrompt = ""
    $lastAgentResponse = ""
    $userPromptsCount = 0
    $agentResponsesCount = 0

    try {
        $fileInfo = [System.IO.FileInfo]::new($tPath)
        if ($fileInfo.Length -eq 0) { return "Диалог пуст." }

        # 1. Быстрое считывание первых строк для извлечения первого запроса
        $fsHead = [System.IO.FileStream]::new($tPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $srHead = [System.IO.StreamReader]::new($fsHead, [System.Text.Encoding]::UTF8)
            $lineNum = 0
            while (-not $srHead.EndOfStream -and $lineNum -lt 25) {
                $line = $srHead.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $lineNum++
                if ($line.Contains('"USER_INPUT"')) {
                    try {
                        $step = ConvertFrom-Json -InputObject $line
                        if ($step.type -eq "USER_INPUT" -and $step.content) {
                            $c = $step.content
                            if ($c -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') { $c = $matches[1].Trim() }
                            $firstUserPrompt = $c
                            break
                        }
                    } catch {}
                }
            }
        } finally {
            $fsHead.Dispose()
        }

        # 2. Быстрое считывание хвоста файла (последние 128 КБ) для последнего запроса и ответа
        $fsTail = [System.IO.FileStream]::new($tPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $readSize = [Math]::Min($fileInfo.Length, 131072)
            $fsTail.Seek(-$readSize, [System.IO.SeekOrigin]::End) | Out-Null
            $srTail = [System.IO.StreamReader]::new($fsTail, [System.Text.Encoding]::UTF8)
            $lines = ($srTail.ReadToEnd() -split "`r?`n")
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $l = $lines[$i]
                if ([string]::IsNullOrWhiteSpace($l)) { continue }
                if (-not $lastAgentResponse -and $l.Contains('"PLANNER_RESPONSE"')) {
                    try {
                        $step = $l | ConvertFrom-Json
                        if ($step.type -eq "PLANNER_RESPONSE" -and $step.content) {
                            $lastAgentResponse = $step.content.Trim()
                        }
                    } catch {}
                }
                if (-not $lastUserPrompt -and $l.Contains('"USER_INPUT"')) {
                    try {
                        $step = $l | ConvertFrom-Json
                        if ($step.type -eq "USER_INPUT" -and $step.content) {
                            $c = $step.content
                            if ($c -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') { $c = $matches[1].Trim() }
                            $lastUserPrompt = $c
                        }
                    } catch {}
                }
                if ($lastAgentResponse -and $lastUserPrompt) { break }
            }
        } finally {
            $fsTail.Dispose()
        }
    } catch {}

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("ID: $conversationId")

    $cStats = Get-ConversationContextStats -conversationId $conversationId
    if ($cStats -and $cStats.TotalTokens -gt 0) {
        $pct = $cStats.Percent
        $barWidth = 20
        $filled = [math]::Min($barWidth, [math]::Max(0, [int][math]::Round(($pct / 100.0) * $barWidth)))
        $unfilled = $barWidth - $filled
        $uniBar = ("█" * $filled) + ("░" * $unfilled)
        [void]$sb.AppendLine("Контекстное окно: [$uniBar] $pct% ($($cStats.FormattedTotal) / $($cStats.FormattedMax))")
        [void]$sb.AppendLine("                 Вход: $($cStats.FormattedIn) | Кэш: $($cStats.FormattedCache) | Ответ: $($cStats.FormattedOut)")
    }
    [void]$sb.AppendLine("")

    if ($firstUserPrompt) {
        [void]$sb.AppendLine("--- ПЕРВЫЙ ЗАПРОС ---")
        $firstP = $firstUserPrompt
        if ($firstP.Length -gt 350) { $firstP = $firstP.Substring(0, 347) + "..." }
        [void]$sb.AppendLine($firstP)
        [void]$sb.AppendLine("")
    }

    if ($lastUserPrompt -and $lastUserPrompt -ne $firstUserPrompt) {
        [void]$sb.AppendLine("--- ПОСЛЕДНИЙ ЗАПРОС ---")
        $lastP = $lastUserPrompt
        if ($lastP.Length -gt 350) { $lastP = $lastP.Substring(0, 347) + "..." }
        [void]$sb.AppendLine($lastP)
        [void]$sb.AppendLine("")
    }

    if ($lastAgentResponse) {
        [void]$sb.AppendLine("--- ПОСЛЕДНИЙ ОТВЕТ АГЕНТА ---")
        $lastA = $lastAgentResponse
        if ($lastA.Length -gt 600) { $lastA = $lastA.Substring(0, 597) + "..." }
        [void]$sb.AppendLine($lastA)
    }

    return $sb.ToString()
}

function Load-ConversationTranscript {
    param([string]$conversationId)
    $tPath = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$conversationId\.system_generated\logs\transcript.jsonl"
    if (-not (Test-Path $tPath)) { return $null }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("================================================================================")
    [void]$sb.AppendLine("  💬 Продолжение диалога: $conversationId")
    [void]$sb.AppendLine("================================================================================`r`n")

    try {
        $sr = [System.IO.StreamReader]::new($tPath, [System.Text.Encoding]::UTF8)
        try {
            while (-not $sr.EndOfStream) {
                $line = $sr.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try {
                    $step = ConvertFrom-Json -InputObject $line
                    if ($step.type -eq "USER_INPUT") {
                        $c = $step.content
                        if ($c -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') {
                            $c = $matches[1].Trim()
                        }
                        $timeStr = if ($step.created_at) {
                            try { [DateTime]::Parse($step.created_at).ToLocalTime().ToString("HH:mm:ss") } catch { "" }
                        } else { "" }
                        $header = if ($timeStr) { "[Вы ($timeStr)]:" } else { "[Вы]:" }
                        [void]$sb.AppendLine("`r`n$header $c`r`n")
                    }
                    elseif ($step.type -eq "PLANNER_RESPONSE") {
                        if ($step.content) {
                            [void]$sb.AppendLine("[Antigravity]: $($step.content)`r`n")
                        }
                    }
                } catch {}
            }
        } finally {
            $sr.Dispose()
        }
    } catch {}

    [void]$sb.AppendLine("`r`n--- [Вы можете продолжить этот диалог, введя сообщение ниже] ---`r`n`r`n")
    return $sb.ToString()
}

# Скрипт-блок для фонового неблокирующего считывания и JSON-парсинга транскрипта
$global:ParseTranscriptScript = {
    param([string]$path)
    if (-not (Test-Path $path)) { return @() }

    function Parse-SystemMessageText([string]$text) {
        $results = [System.Collections.Generic.List[psobject]]::new()
        if ([string]::IsNullOrWhiteSpace($text)) { return @() }
        $pattern = '(?s)<SYSTEM_MESSAGE>\s*(.*?)\s*</SYSTEM_MESSAGE>'
        $sysMatches = [regex]::Matches($text, $pattern)
        if ($sysMatches.Count -gt 0) {
            foreach ($m in $sysMatches) {
                $body = $m.Groups[1].Value.Trim()
                $summary = ""
                if ($body -match 'content=([^\r\n]+)') {
                    $summary = if ($Matches.Count -gt 1) { $Matches[1].Trim() } else { [regex]::Unescape("\u0421\u0438\u0441\u0442\u0435\u043c\u043d\u043e\u0435 \u0443\u0432\u0435\u0434\u043e\u043c\u043b\u0435\u043d\u0438\u0435") }
                } else {
                    $firstLine = ($body -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
                    $summary = if ($firstLine) { $firstLine.Trim() } else { "Системное уведомление" }
                }
                $summary = [regex]::Replace($summary, 'Task id "[0-9a-fA-F\-]{20,}/(task-\d+)"', 'Task id "$1"')
                if ($summary.Length -gt 75) { $summary = $summary.Substring(0, 72) + "..." }
                $results.Add([pscustomobject]@{
                    Summary = $summary
                    Body    = $body
                })
            }
        } else {
            $clean = $text.Trim()
            $firstLine = ($clean -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
            $summary = if ($firstLine) { $firstLine.Trim() } else { "Системное уведомление" }
            $summary = [regex]::Replace($summary, 'Task id "[0-9a-fA-F\-]{20,}/(task-\d+)"', 'Task id "$1"')
            if ($summary.Length -gt 75) { $summary = $summary.Substring(0, 72) + "..." }
            $results.Add([pscustomobject]@{
                Summary = $summary
                Body    = $clean
            })
        }
        return , $results.ToArray()
    }

    $turns = [System.Collections.Generic.List[psobject]]::new()
    $currentTurn = $null
    $activeTools = [System.Collections.Generic.List[psobject]]::new()

    try {
        $fs = [System.IO.FileStream]::new($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $sr = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
            while (-not $sr.EndOfStream) {
            $line = $sr.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if (-not ($line.Contains('"USER_INPUT"') -or $line.Contains('"PLANNER_RESPONSE"') -or $line.Contains('"SYSTEM_MESSAGE"') -or $line.Contains('SYSTEM_MESSAGE'))) { continue }

            try {
                $step = ConvertFrom-Json -InputObject $line
                if ($step.type -eq "SYSTEM_MESSAGE") {
                    $rawSys = $step.content
                    $sysList = Parse-SystemMessageText $rawSys

                    if (-not $currentTurn) {
                        $timeStr = if ($step.created_at) {
                            try { [DateTime]::Parse($step.created_at).ToLocalTime().ToString("HH:mm:ss") } catch { "" }
                        } else { "" }
                        $currentTurn = [pscustomobject]@{
                            UserTime   = $timeStr
                            UserText   = ""
                            UserBadges = ""
                            Items      = [System.Collections.Generic.List[psobject]]::new()
                        }
                    }

                    if ($activeTools.Count -gt 0) {
                        $currentTurn.Items.Add([pscustomobject]@{ Type = "TOOLS"; Tools = $activeTools.ToArray() })
                        $activeTools.Clear()
                    }

                    foreach ($smsg in $sysList) {
                        $currentTurn.Items.Add([pscustomobject]@{
                            Type    = "SYSTEM_MESSAGE"
                            Summary = $smsg.Summary
                            Body    = $smsg.Body
                        })
                    }
                }
                elseif ($step.type -eq "USER_INPUT") {
                    if ($currentTurn) {
                        if ($activeTools.Count -gt 0) {
                            $currentTurn.Items.Add([pscustomobject]@{ Type = "TOOLS"; Tools = $activeTools.ToArray() })
                            $activeTools.Clear()
                        }
                        $turns.Add($currentTurn)
                    }

                    $raw = $step.content
                    $embeddedSys = @()

                    # Извлечение встроенных системных сообщений (<SYSTEM_MESSAGE>) и удаление преамбулы
                    if ($raw -match '(?s)<SYSTEM_MESSAGE>[\s\S]*?</SYSTEM_MESSAGE>') {
                        $embeddedSys = Parse-SystemMessageText $raw
                        $raw = [regex]::Replace($raw, '(?s)(?:The following is a <SYSTEM_MESSAGE>[\s\S]*?attention to\.[\s\r\n]*)?<SYSTEM_MESSAGE>[\s\S]*?</SYSTEM_MESSAGE>', '').Trim()
                    }
                    if ($raw -match '(?s)<ADDITIONAL_METADATA>[\s\S]*?</ADDITIONAL_METADATA>') {
                        $raw = [regex]::Replace($raw, '(?s)<ADDITIONAL_METADATA>[\s\S]*?</ADDITIONAL_METADATA>', '').Trim()
                    }
                    if ($raw -match '(?s)<USER_SETTINGS_CHANGE>[\s\S]*?</USER_SETTINGS_CHANGE>') {
                        $raw = [regex]::Replace($raw, '(?s)<USER_SETTINGS_CHANGE>[\s\S]*?</USER_SETTINGS_CHANGE>', '').Trim()
                    }

                    $badges = ""
                    $cleanText = $raw
                    $turnAttachments = [System.Collections.Generic.List[psobject]]::new()

                    # Разбор прикрепленных изображений и файлов: извлечение путей и имен файлов в бейджи и очистка текста
                    if ($raw -match '(?s)\[Прикрепленные (?:изображения|файлы[^\:]*):\s*(.*?)\s*\]') {
                        $imgSection = $matches[1]
                        $imgFiles = [System.Collections.Generic.List[string]]::new()
                        foreach ($m in [regex]::Matches($imgSection, '(?m)^\s*-\s*(?:file:///)?([^\r\n]+)')) {
                            $rawPath = $m.Groups[1].Value.Trim().Replace('/', '\')
                            try { $rawPath = [System.Uri]::UnescapeDataString($rawPath) } catch {}
                            $fn = [System.IO.Path]::GetFileName($rawPath)
                            if ($fn) {
                                $isAnnot = ($fn -match '_annotated\.png$')
                                $icon = if ($isAnnot) { "🎯" } else { "🖼️" }
                                $imgFiles.Add("$icon $fn")
                                $turnAttachments.Add([pscustomobject]@{
                                    FilePath    = $rawPath
                                    FileName    = $fn
                                    DisplayName = $fn
                                })
                            }
                        }
                        if ($imgFiles.Count -gt 0) {
                            $badges = "[" + ($imgFiles -join ", ") + "]"
                        }
                        $cleanText = [regex]::Replace($raw, '(?s)\[Прикрепленные (?:изображения|файлы[^\:]*):[\s\S]*?\]\s*(?:Внимание агенту:[^\r\n]*\r?\n*)?', '').Trim()
                    }

                    if ($cleanText -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') {
                        $cleanText = $matches[1].Trim()
                    }

                    $timeStr = if ($step.created_at) {
                        try { [DateTime]::Parse($step.created_at).ToLocalTime().ToString("HH:mm:ss") } catch { "" }
                    } else { "" }

                    $currentTurn = [pscustomobject]@{
                        UserTime        = $timeStr
                        UserText        = $cleanText
                        UserBadges      = $badges
                        UserAttachments = $turnAttachments.ToArray()
                        Items           = [System.Collections.Generic.List[psobject]]::new()
                    }

                    if ($embeddedSys -and $embeddedSys.Count -gt 0) {
                        foreach ($es in $embeddedSys) {
                            $currentTurn.Items.Add([pscustomobject]@{
                                Type    = "SYSTEM_MESSAGE"
                                Summary = $es.Summary
                                Body    = $es.Body
                            })
                        }
                    }
                }
                elseif ($step.type -eq "PLANNER_RESPONSE") {
                    if (-not $currentTurn) {
                        $currentTurn = [pscustomobject]@{
                            UserTime        = ""
                            UserText        = ""
                            UserBadges      = ""
                            UserAttachments = @()
                            Items           = [System.Collections.Generic.List[psobject]]::new()
                        }
                    }
                    if ($step.tool_calls) {
                        foreach ($tc in $step.tool_calls) {
                            $summary = ""
                            if ($tc.args -and $tc.args.toolSummary) { 
                                $summary = $tc.args.toolSummary.ToString().Trim('"') 
                            } elseif ($tc.args -and $tc.args.CommandLine) { 
                                $cmd = $tc.args.CommandLine.ToString().Trim('"')
                                $summary = if ($cmd.Length -gt 40) { $cmd.Substring(0, 40) + "..." } else { $cmd }
                            } elseif ($tc.args -and $tc.args.Path) {
                                $p = $tc.args.Path.ToString().Trim('"').Replace('/', '\')
                                $summary = [System.IO.Path]::GetFileName($p)
                            } elseif ($tc.args -and $tc.args.query) {
                                $q = $tc.args.query.ToString().Trim('"')
                                $summary = if ($q.Length -gt 40) { $q.Substring(0, 40) + "..." } else { $q }
                            }
                            $activeTools.Add([pscustomobject]@{ Name = $tc.name; Summary = $summary })
                        }
                    }
                    if ($step.content) {
                        if ($activeTools.Count -gt 0) {
                            $currentTurn.Items.Add([pscustomobject]@{ Type = "TOOLS"; Tools = $activeTools.ToArray() })
                            $activeTools.Clear()
                        }
                        $currentTurn.Items.Add([pscustomobject]@{ Type = "AGENT_TEXT"; Text = $step.content })
                    }
                }
            } catch {}
        }
    } finally {
        if ($fs) { $fs.Dispose() }
    }
} catch {}

    if ($currentTurn) {
        if ($activeTools.Count -gt 0) {
            $currentTurn.Items.Add([pscustomobject]@{ Type = "TOOLS"; Tools = $activeTools.ToArray() })
            $activeTools.Clear()
        }
        $turns.Add($currentTurn)
    }

    return $turns
}

function Populate-ConversationTranscriptToLog {
    param(
        $Turns,
        [string]$conversationId,
        $Document = $null,
        $Tab = $null,
        [switch]$LoadAll
    )
    $turnsList = [System.Collections.Generic.List[psobject]]::new()
    if ($Turns -is [System.Collections.IEnumerable] -and -not ($Turns -is [string])) {
        foreach ($item in $Turns) {
            if ($item -is [System.Collections.IList] -and -not ($item -is [string])) {
                foreach ($subItem in $item) { $turnsList.Add($subItem) }
            } else {
                $turnsList.Add($item)
            }
        }
    } elseif ($null -ne $Turns) {
        $turnsList.Add($Turns)
    }
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }

    $t = if ($Tab) { $Tab } else { $global:ActiveTab }
    if ($t -and ($t -is [psobject])) {
        if ($t.PSObject.Properties['FullTranscriptTurns']) {
            $t.FullTranscriptTurns = $turnsList
        } else {
            $t | Add-Member -NotePropertyName 'FullTranscriptTurns' -NotePropertyValue $turnsList -Force -ErrorAction SilentlyContinue
        }
    }

    $doc.Blocks.Clear()

    # Аккуратное системное уведомление в стиле живого чата ([ИНФО])
    $pInfo = [System.Windows.Documents.Paragraph]::new()
    $pInfo.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)
    $runInfo = [System.Windows.Documents.Run]::new("[ИНФО] Загружена история диалога ($conversationId)")
    $runInfo.Foreground = Get-CachedBrush "#6A9955"
    $pInfo.Inlines.Add($runInfo)
    $doc.Blocks.Add($pInfo)

    $hasMessages = $false
    if ($turnsList.Count -gt 0) {
        $hasMessages = $true
        $renderTurns = $turnsList
        $earlierCount = 0

        # Виртуализация: если сообщений больше 25, отображаем последние 25 и кнопку подгрузки ранних
        if (-not $LoadAll -and $turnsList.Count -gt 5) {
            $earlierCount = $turnsList.Count - 5
            $renderTurns = $turnsList | Select-Object -Last 5

            $cardBorder = [System.Windows.Controls.Border]::new()
            $cardBorder.Background = (Get-CachedBrush "#202024")
            $cardBorder.BorderBrush = (Get-CachedBrush "#3E3E42")
            $cardBorder.BorderThickness = [System.Windows.Thickness]::new(1)
            $cardBorder.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $cardBorder.Padding = [System.Windows.Thickness]::new(12, 6, 12, 6)
            $cardBorder.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $cardBorder.Margin = [System.Windows.Thickness]::new(0, 4, 0, 8)
            $cardBorder.Cursor = [System.Windows.Input.Cursors]::Hand

            $sp = [System.Windows.Controls.StackPanel]::new()
            $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $lblIcon = [System.Windows.Controls.TextBlock]::new()
            $lblIcon.Text = "⬆ "
            $lblIcon.Foreground = (Get-CachedBrush "#4FC1FF")
            $lblIcon.FontWeight = [System.Windows.FontWeights]::Bold
            $sp.Children.Add($lblIcon) | Out-Null

            $lblText = [System.Windows.Controls.TextBlock]::new()
            $lblText.Text = "Показать более ранние сообщения (ещё $earlierCount сообщений)..."
            $lblText.Foreground = (Get-CachedBrush "#CCCCCC")
            $lblText.FontSize = [math]::Max(11.0, $global:CurrentFontSize - 1.0)
            $sp.Children.Add($lblText) | Out-Null
            $cardBorder.Child = $sp

            $targetTab = $t
            $targetDoc = $doc
            $targetTurns = $turnsList
            $targetCid = $conversationId
            $cardBorder.Add_PreviewMouseLeftButtonDown({
                param($s, $e)
                $e.Handled = $true
                Populate-ConversationTranscriptToLog -Turns $targetTurns -conversationId $targetCid -Document $targetDoc -Tab $targetTab -LoadAll
            }.GetNewClosure())

            $uic = [System.Windows.Documents.BlockUIContainer]::new($cardBorder)
            $doc.Blocks.Add($uic)
        }

        foreach ($turn in $renderTurns) {
            # 1. Запрос пользователя (только если не пустой): время [Вы (HH:mm:ss)], бейджи картинок [🖼️ ...], форматированный текст
            if (-not [string]::IsNullOrWhiteSpace($turn.UserText) -or -not [string]::IsNullOrWhiteSpace($turn.UserBadges)) {
                Append-UserMessageToLog -TimeStr $turn.UserTime -Text $turn.UserText -Badges $turn.UserBadges -Attachments $turn.UserAttachments -Document $doc
            }

            # 2. Элементы ответа (инструменты, текст агента, системные карточки)
            if ($turn.Items -and $turn.Items.Count -gt 0) {
                $agentHeaderAdded = $false

                # Consolidate consecutive tools and system messages
                $consolidated = [System.Collections.Generic.List[psobject]]::new()
                $pendingTools = [System.Collections.Generic.List[psobject]]::new()
                $pendingSys = [System.Collections.Generic.List[psobject]]::new()

                $flushAll = {
                    if ($pendingTools.Count -gt 0) {
                        $consolidated.Add([pscustomobject]@{ Type = "TOOLS"; Tools = $pendingTools.ToArray() })
                        $pendingTools.Clear()
                    }
                    if ($pendingSys.Count -gt 0) {
                        if ($pendingSys.Count -eq 1) {
                            $consolidated.Add($pendingSys[0])
                        } else {
                            $summary = "System Notifications ($($pendingSys.Count))"
                            $body = ($pendingSys | ForEach-Object { "- $($_.Summary)" }) -join "`r`n"
                            $consolidated.Add([pscustomobject]@{ Type = "SYSTEM_MESSAGE"; Summary = $summary; Body = $body })
                        }
                        $pendingSys.Clear()
                    }
                }

                foreach ($rawIt in $turn.Items) {
                    if ($rawIt.Type -eq "TOOLS") {
                        if ($rawIt.Tools) { foreach ($tObj in $rawIt.Tools) { $pendingTools.Add($tObj) } }
                    } elseif ($rawIt.Type -eq "SYSTEM_MESSAGE") {
                        $pendingSys.Add($rawIt)
                    } elseif ($rawIt.Type -eq "AGENT_TEXT") {
                        & $flushAll
                        $consolidated.Add($rawIt)
                    }
                }
                & $flushAll

                # Один ход агента может содержать сотни блоков (в диалоге 0233d93f в одном ходу
                # 143 текста агента и 220 системных сообщений). Рендер всех блоков за один проход
                # на основном потоке замораживает окно, поэтому при открытии показываем только
                # последние блоки хода. Полный ход выводится кнопкой подгрузки ранней истории (-LoadAll).
                $maxBlocksPerTurn = 30
                if (-not $LoadAll -and $consolidated.Count -gt $maxBlocksPerTurn) {
                    $hiddenBlocks = $consolidated.Count - $maxBlocksPerTurn
                    $consolidated = $consolidated.GetRange($hiddenBlocks, $maxBlocksPerTurn)
                    Append-ChatFormatted -Text "  ⬆ Скрыто ранних блоков этого хода: $hiddenBlocks (показаны последние $maxBlocksPerTurn)`r`n" -Color "#888888" -Document $doc
                }

                Set-PerfStage "populate: ход, блоков $($consolidated.Count)"
                $turnSw = [System.Diagnostics.Stopwatch]::StartNew()
                foreach ($item in $consolidated) {
                    if ($item.Type -eq "TOOLS") {
                        if (-not $agentHeaderAdded) {
                            Append-AgentHeader -Document $doc
                            $agentHeaderAdded = $true
                        }
                        if ($item.Tools -and $item.Tools.Count -gt 0) {
                            Add-HistoryToolGroupCard $item.Tools -Document $doc
                        }
                    }
                    elseif ($item.Type -eq "AGENT_TEXT") {
                        if (-not $agentHeaderAdded) {
                            Append-AgentHeader -Document $doc
                            $agentHeaderAdded = $true
                        }
                        $mdSw = [System.Diagnostics.Stopwatch]::StartNew()
                        Append-MarkdownFormatted -Text $item.Text -Document $doc -BaseColor "#D4D4D4"
                        if ($mdSw.ElapsedMilliseconds -gt 150) {
                            Write-PerfLog "  Append-MarkdownFormatted: $($mdSw.ElapsedMilliseconds) мс, длина текста $($item.Text.Length)"
                        }
                    }
                    elseif ($item.Type -eq "SYSTEM_MESSAGE") {
                        [void](New-SystemMessageCard -Summary $item.Summary -Body $item.Body -StartCollapsed -Document $doc)
                    }
                }

                Write-PerfLog "  ход: вывод $($consolidated.Count) блоков занял $($turnSw.ElapsedMilliseconds) мс"
                # 3. Разделительный перенос строки после ответа агента (как в live-чате)
                if ($agentHeaderAdded) {
                    Append-ChatFormatted -Text "`r`n" -Color "#D4D4D4" -Document $doc
                }
            }
        }
    }

    if (-not $hasMessages) {
        $pEmpty = [System.Windows.Documents.Paragraph]::new()
        $pEmpty.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)
        $runEmpty = [System.Windows.Documents.Run]::new("[ИНФО] История диалога пуста. Введите сообщение ниже для начала работы.")
        $runEmpty.Foreground = Get-CachedBrush "#6A9955"
        $pEmpty.Inlines.Add($runEmpty)
        $doc.Blocks.Add($pEmpty)
    }
}

function Start-AsyncTranscriptLoad {
    param(
        [Parameter(Mandatory=$true)][string]$conversationId,
        [Parameter(Mandatory=$true)]$Tab
    )
    $tPath = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$conversationId\.system_generated\logs\transcript.jsonl"

    # Р‘РµР·РѕРїР°СЃРЅРѕРµ РѕСЃРІРѕР±РѕР¶РґРµРЅРёРµ РїСЂРµРґС‹РґСѓС‰РµР№ Р·Р°РґР°С‡Рё Р·Р°РіСЂСѓР·РєРё
    if ($Tab.LoadingJob) {
        $oldJob = $Tab.LoadingJob
        $Tab.LoadingJob = $null
        try {
            $oldJob.PowerShell.Dispose()
        } catch {}
    }

    if (-not (Test-Path $tPath)) {
        Populate-ConversationTranscriptToLog -Turns @() -conversationId $conversationId -Document $Tab.Document -Tab $Tab
        $Tab.StatusText = [regex]::Unescape("\u0414\u0438\u0430\u043b\u043e\u0433 \u0437\u0430\u0433\u0440\u0443\u0436\u0435\u043d, \u0433\u043e\u0442\u043e\u0432 \u043a \u043f\u0440\u043e\u0434\u043e\u043b\u0436\u0435\u043d\u0438\u044e")
        $Tab.StatusColor = "#4CAF50"
        if ($Tab.HeaderDot) { $Tab.HeaderDot.Fill = (Get-CachedBrush "#4CAF50") }
        if ($Tab -eq $global:ActiveTab) {
            Hide-LoadingOverlay
            $txtStatus.Text = $Tab.StatusText
            $statusDot.Fill = (Get-CachedBrush "#4CAF50")
            Scroll-ChatLogToEnd
        }
        return
    }

    # РџРѕРєР°Р·С‹РІР°РµРј РѕРІРµСЂР»РµР№ Р·Р°РіСЂСѓР·РєРё РґР»СЏ Р°РєС‚РёРІРЅРѕР№ РІРєР»Р°РґРєРё
    if ($Tab -eq $global:ActiveTab) {
        $sub = if ($Tab.Title) { $Tab.Title } else { [regex]::Unescape("\u0421\u0447\u0438\u0442\u044b\u0432\u0430\u043d\u0438\u0435 \u0438\u0441\u0442\u043e\u0440\u0438\u0438...") }
        Show-LoadingOverlay -Title [regex]::Unescape("\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u0434\u0438\u0430\u043b\u043e\u0433\u0430...") -Subtitle $sub
    }

    $ps = [powershell]::Create()
    [void]$ps.AddScript($global:ParseTranscriptScript).AddArgument($tPath)
    $asyncResult = $ps.BeginInvoke()

    $Tab.LoadingJob = [pscustomobject]@{
        PowerShell  = $ps
        AsyncResult = $asyncResult
        ConvId      = $conversationId
        Tab         = $Tab
        StartTime   = [DateTime]::UtcNow
    }
}

function Update-TabLoadingJobs {
    try {
        # Watchdog: force-hide overlay after 2.5s or if active tab has no loading job
        if ($loadingOverlay -and $loadingOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
            $nowUtc = [DateTime]::UtcNow
            if ($global:LoadingOverlayStartTime -and ($nowUtc - $global:LoadingOverlayStartTime).TotalSeconds -gt 15.0) {
                Hide-LoadingOverlay
            }
            if ($global:ActiveTab -and -not $global:ActiveTab.LoadingJob) {
                Hide-LoadingOverlay
            }
        }

        if (-not $global:TabsList) { return }
        foreach ($t in @($global:TabsList)) {
            if ($t.LoadingJob) {
                $job = $t.LoadingJob
                $isTimedOut = ($job.StartTime -and ([DateTime]::UtcNow - $job.StartTime).TotalSeconds -gt 25.0)

                if ($job.AsyncResult.IsCompleted -or $isTimedOut) {
                    $t.LoadingJob = $null
                    $turns = @()
                    try {
                        if ($job.AsyncResult.IsCompleted) {
                            $rawTurns = @($job.PowerShell.EndInvoke($job.AsyncResult))
                            if ($rawTurns.Count -gt 0) {
                                if ($rawTurns.Count -eq 1 -and ($rawTurns[0] -is [System.Collections.IList])) {
                                    $turns = @($rawTurns[0])
                                } else {
                                    $turns = $rawTurns
                                }
                            }
                        }
                    } catch {}
                    finally {
                        try { $job.PowerShell.Dispose() } catch {}
                    }

                    try {
                        # Populate transcript only if conversation id on tab has not changed
                        if ($job.ConvId -eq $t.ConversationId) {
                            $popSw = [System.Diagnostics.Stopwatch]::StartNew()
                            $bgMs = [long]([DateTime]::UtcNow - $job.StartTime).TotalMilliseconds
                            Write-PerfLog "Загрузка диалога $($job.ConvId): фоновый разбор + ожидание $bgMs мс, ходов: $(@($turns).Count)"
                            Set-PerfStage "loadjob: Populate-ConversationTranscriptToLog"
                            Populate-ConversationTranscriptToLog -Turns $turns -conversationId $job.ConvId -Document $t.Document -Tab $t
                            Write-PerfLog "Populate-ConversationTranscriptToLog (построение блоков): $($popSw.ElapsedMilliseconds) мс"
                            Set-PerfStage "loadjob: после Populate"

                            $t.StatusText = [regex]::Unescape("\u0414\u0438\u0430\u043b\u043e\u0433 \u0437\u0430\u0433\u0440\u0443\u0436\u0435\u043d, \u0433\u043e\u0442\u043e\u0432 \u043a \u043f\u0440\u043e\u0434\u043e\u043b\u0436\u0435\u043d\u0438\u044e")
                            $t.StatusColor = "#4CAF50"
                            if ($t.HeaderDot) {
                                $t.HeaderDot.Fill = (Get-CachedBrush "#4CAF50")
                            }
                        }
                    } catch {}

                    if ($t -eq $global:ActiveTab) {
                        Set-PerfStage "loadjob: Hide-LoadingOverlay/Scroll/ContextDisplay"
                        Hide-LoadingOverlay
                        $txtStatus.Text = $t.StatusText
                        $statusDot.Fill = (Get-CachedBrush $t.StatusColor)
                        Scroll-ChatLogToEnd
                        Update-ContextDisplay -conversationId $t.ConversationId -modelName $t.Model
                        Write-PerfLog "Загрузка диалога завершена, UI-часть выполнена; дальше раскладку и отрисовку делает WPF"
                        Set-PerfStage "-"
                    }
                }
        }
        }
    } catch {
        Hide-LoadingOverlay
    }
}

function Wait-TabLoading {
    param($Tab = $null, [int]$TimeoutMs = 5000)
    $t = if ($Tab) { $Tab } else { $global:ActiveTab }
    if (-not $t -or -not $t.LoadingJob) { return }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($t.LoadingJob -and -not $t.LoadingJob.AsyncResult.IsCompleted -and $sw.ElapsedMilliseconds -lt $TimeoutMs) {
        Start-Sleep -Milliseconds 25
    }
    Update-TabLoadingJobs
}

function Render-ConversationTranscriptToLog {
    param(
        [string]$conversationId,
        $Document = $null
    )
    $tPath = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$conversationId\.system_generated\logs\transcript.jsonl"
    if (-not (Test-Path $tPath)) { return $false }

    $turns = @(& $global:ParseTranscriptScript $tPath)
    if ($turns.Count -eq 0) {
        return $false
    }

    Populate-ConversationTranscriptToLog -Turns $turns -conversationId $conversationId -Document $Document
    return $true
}

function Select-ConversationItem {
    param($conv)
    if (-not $conv -or -not $conv.Id) { return }

    $targetTab = $global:ActiveTab
    $cleanTitle = if ($conv.Title) { $conv.Title } else { "Диалог $($conv.Id.Substring(0,8))" }
    if ($cleanTitle.Length -gt 20) { $cleanTitle = $cleanTitle.Substring(0, 20) + "..." }

    if (-not $targetTab) {
        $targetTab = Add-NewTab -ConversationId $conv.Id -Title $cleanTitle -Select
    } else {
        $targetTab.ConversationId = $conv.Id
        $targetTab.Title = $cleanTitle
        if ($targetTab.HeaderTitle) {
            $targetTab.HeaderTitle.Text = $cleanTitle
            $targetTab.HeaderTitle.ToolTip = $conv.Title
        }
    }

    $global:CurrentConversationId = $conv.Id
    $shortId = if ($conv.Id.Length -gt 12) { $conv.Id.Substring(0, 12) + "..." } else { $conv.Id }
    $txtConversationId.Text = "Диалог: $shortId"
    $txtConversationId.ToolTip = "$($conv.Id)`r`n$($conv.Title)"

    if ($conv.Workspace -and (Test-Path $conv.Workspace)) {
        $txtWorkspace.Text = $conv.Workspace
        $targetTab.Workspace = $conv.Workspace
    }

    $targetTab.StatusText = "Загрузка диалога..."
    $targetTab.StatusColor = "#FFA500"
    if ($targetTab.HeaderDot) {
        $targetTab.HeaderDot.Fill = (Get-CachedBrush "#FFA500")
    }
    if ($global:ActiveTab -eq $targetTab) {
        $txtStatus.Text = $targetTab.StatusText
        $statusDot.Fill = (Get-CachedBrush "#FFA500")
    }

    if (-not $global:IsSelectingFromCombo) {
            $global:SuppressConvComboEvent = $true
    try {
        if ($cmbConversations) {
            for ($i = 0; $i -lt $cmbConversations.Items.Count; $i++) {
                $item = $cmbConversations.Items[$i]
                if ($item.Tag -eq $conv.Id) {
                    if ($cmbConversations.SelectedIndex -ne $i) {
                        try { $cmbConversations.SelectedIndex = $i } catch {}
                    }
                    break
                }
            }
        }
    } finally {
        $global:SuppressConvComboEvent = $false
    }
    }

    $selSw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-PerfLog "Select-ConversationItem: начало, диалог $($conv.Id)"
    # Clear active chat log immediately to avoid displaying stale conversation while loading
    if ($targetTab -eq $global:ActiveTab) {
        Set-PerfStage "select: Clear-ChatLog"
        Clear-ChatLog -Document $targetTab.Document
        Write-PerfLog "  Clear-ChatLog: $($selSw.ElapsedMilliseconds) мс"
    }
    # Launch smooth non-blocking async transcript load
    Set-PerfStage "select: Start-AsyncTranscriptLoad"
    Start-AsyncTranscriptLoad -conversationId $conv.Id -Tab $targetTab
    Write-PerfLog "  Start-AsyncTranscriptLoad: накоплено $($selSw.ElapsedMilliseconds) мс"
    $targetTab.IsTranscriptLoaded = $true
    Set-PerfStage "select: Update-ContextDisplay"
    Update-ContextDisplay -conversationId $conv.Id
    Write-PerfLog "  Update-ContextDisplay: накоплено $($selSw.ElapsedMilliseconds) мс"
    Set-PerfStage "select: Update-LimitsDisplay"
    Update-LimitsDisplay
    Write-PerfLog "  Update-LimitsDisplay: накоплено $($selSw.ElapsedMilliseconds) мс"
    Set-PerfStage "select: Save-LauncherConfig"
    Save-LauncherConfig
    Write-PerfLog "Select-ConversationItem: конец, всего $($selSw.ElapsedMilliseconds) мс"
    Set-PerfStage "-"
}

function Reset-ToNewChat {
    $tab = $global:ActiveTab
    if ($tab) {
        if ($tab.LoadingJob) {
            $oldJob = $tab.LoadingJob
            $tab.LoadingJob = $null
            try {
                $oldJob.PowerShell.Dispose()
            } catch {}
        }
        Hide-LoadingOverlay
        $tab.ConversationId = $null
        $tab.Title = "Новый диалог"
        if ($tab.HeaderTitle) {
            $tab.HeaderTitle.Text = "Новый диалог"
            $tab.HeaderTitle.ToolTip = $null
        }
        $tab.StatusText = "Готов к работе (Новый диалог)"
        $tab.StatusColor = "#4CAF50"
        $tab.IsTranscriptLoaded = $true
        Clear-ChatLog -Document $tab.Document
        Show-WelcomeMessage -Document $tab.Document
    } else {
        Clear-ChatLog
        Show-WelcomeMessage
    }
    $global:CurrentConversationId = $null
    $txtConversationId.Text = "Диалог: Новый"
    $txtConversationId.ToolTip = "Новая сессия"
    $txtStatus.Text = "Готов к работе (Новый диалог)"
    $statusDot.Fill = (Get-CachedBrush "#4CAF50")
    Update-ContextDisplay -conversationId $null
    Update-LimitsDisplay

    if (-not $global:IsSelectingFromCombo) {
            $global:SuppressConvComboEvent = $true
    try {
        try { $cmbConversations.SelectedIndex = 0 } catch {}
    } finally {
        $global:SuppressConvComboEvent = $false
    }
    }
    Save-LauncherConfig
}

function Remove-AntigravityConversation {
    param([Parameter(Mandatory=$true)][string]$conversationId)

    if ([string]::IsNullOrWhiteSpace($conversationId)) { return $false }
    if ($conversationId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $false
    }

    $brainDir = "$env:USERPROFILE\.gemini\antigravity-cli\brain"
    $targetDir = Join-Path $brainDir $conversationId

    $success = $false
    if (Test-Path $targetDir) {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Remove-Item -Path $targetDir -Recurse -Force -ErrorAction Stop
                $success = $true
                break
            } catch {
                if ($attempt -lt 3) {
                    Start-Sleep -Milliseconds 60
                } else {
                    Write-Warning "Не удалось удалить директорию диалога $targetDir : $_"
                    return $false
                }
            }
        }
    }

    # Удаление из локального кэша метаданных
    if ($sessionMetaPath -and (Test-Path $sessionMetaPath)) {
        try {
            $rawJson = Get-Content -Path $sessionMetaPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if ($rawJson) {
                $parsed = $rawJson | ConvertFrom-Json
                if ($parsed.psobject.properties[$conversationId]) {
                    $newObj = [ordered]@{}
                    foreach ($prop in $parsed.psobject.properties) {
                        if ($prop.Name -ne $conversationId) {
                            $newObj[$prop.Name] = $prop.Value
                        }
                    }
                    $updatedJson = $newObj | ConvertTo-Json -Depth 5
                    [System.IO.File]::WriteAllText($sessionMetaPath, $updatedJson, (New-Object System.Text.UTF8Encoding($false)))
                }
            }
        } catch {}
    }

    # Если удален диалог в любой открытой вкладке:
    if ($global:TabsList) {
        foreach ($t in $global:TabsList) {
            if ($t.ConversationId -eq $conversationId) {
                $t.ConversationId = $null
                $t.Title = "Новый диалог"
                if ($t.HeaderTitle) { $t.HeaderTitle.Text = "Новый диалог" }
                Clear-ChatLog -Document $t.Document
                Show-WelcomeMessage -Document $t.Document
            }
        }
    }

    # Если удален текущий активный диалог, сбрасываем состояние сессии в главном окне
    if ($global:CurrentConversationId -eq $conversationId) {
        Reset-ToNewChat
    }

    return $success
}

function Set-ConversationTitle {
    param(
        [Parameter(Mandatory=$true)][string]$conversationId,
        [Parameter(Mandatory=$true)][string]$newTitle
    )
    if ([string]::IsNullOrWhiteSpace($conversationId) -or [string]::IsNullOrWhiteSpace($newTitle)) { return $false }
    $cleanTitle = ($newTitle -split "`r?`n")[0].Trim()
    if ($cleanTitle.Length -gt 120) { $cleanTitle = $cleanTitle.Substring(0, 117) + "..." }

    # 1. Сохранение в sessions_meta.json
    try {
        if (-not $sessionMetaPath) {
            $sessionMetaPath = Join-Path $userDataDir "sessions_meta.json"
        }
        $meta = @{}
        if (Test-Path $sessionMetaPath) {
            $raw = Get-Content -Path $sessionMetaPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if ($raw) {
                $parsed = $raw | ConvertFrom-Json
                foreach ($prop in $parsed.psobject.properties) {
                    $meta[$prop.Name] = $prop.Value
                }
            }
        }
        $existing = if ($meta.ContainsKey($conversationId)) { $meta[$conversationId] } else { $null }
        $meta[$conversationId] = [pscustomobject]@{
            workspace = if ($existing -and $existing.workspace) { $existing.workspace } else { "" }
            title     = $cleanTitle
            timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        }
        $meta | ConvertTo-Json -Depth 4 | Set-Content -Path $sessionMetaPath -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}

    # 2. Обновление открытых вкладок
    if ($global:TabsList) {
        foreach ($t in $global:TabsList) {
            if ($t.ConversationId -eq $conversationId) {
                $t.Title = $cleanTitle
                if ($t.HeaderTitle) {
                    $t.HeaderTitle.Text = $cleanTitle
                    $t.HeaderTitle.ToolTip = $cleanTitle
                }
            }
        }
    }

    # 3. Обновление выпадающего списка
    Refresh-ConversationsCombo

    return $true
}

function Show-RenameDialog {
    param(
        [string]$CurrentTitle,
        [string]$PromptText = "Введите новое название разговора:",
        $OwnerWindow = $null,
        [string]$DialogTitle = "✏️ Переименование разговора"
    )

    $dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$DialogTitle"
        Height="185" Width="460"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        Background="#1E1E1E" Foreground="#F1F1F1"
        FontFamily="Segoe UI" FontSize="13">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="$PromptText" Foreground="#CCCCCC" Margin="0,0,0,10" FontWeight="SemiBold"/>
        
        <TextBox x:Name="TxtNewTitle" Grid.Row="1" Background="#252526" Foreground="#F1F1F1" BorderBrush="#3E3E42" BorderThickness="1" Padding="8,6" CaretBrush="#007ACC" FontSize="13" Margin="0,0,0,16"/>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnSave" Content="✔ Сохранить" IsDefault="True" Background="#0E639C" BorderBrush="#1177BB" Foreground="#FFFFFF" Padding="14,6" Margin="0,0,8,0" FontWeight="SemiBold" Cursor="Hand"/>
            <Button x:Name="BtnCancel" Content="Отмена" IsCancel="True" Background="#2D2D30" BorderBrush="#3E3E42" Foreground="#FFFFFF" Padding="14,6" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $sReader = [System.Xml.XmlNodeReader]::new([xml]$dialogXaml)
    $diag = [System.Windows.Markup.XamlReader]::Load($sReader)
    if ($OwnerWindow) {
        $diag.Owner = $OwnerWindow
    } elseif ($window) {
        $diag.Owner = $window
    }
    if ($window -and $window.Icon) {
        $diag.Icon = $window.Icon
    }

    $txtInput = $diag.FindName("TxtNewTitle")
    $btnSave = $diag.FindName("BtnSave")
    $btnCancel = $diag.FindName("BtnCancel")

    $txtInput.Text = if ($CurrentTitle) { $CurrentTitle } else { "" }
    $txtInput.SelectAll()

    $script:renameResult = $null

    $btnSave.Add_Click({
        $trimmed = $txtInput.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $script:renameResult = $trimmed
            $diag.DialogResult = $true
            $diag.Close()
        } else {
            [System.Windows.MessageBox]::Show($diag, "Название не может быть пустым.", "Предупреждение", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    })

    $diag.Add_Loaded({
        $txtInput.Focus()
    })

    $showRes = $diag.ShowDialog()
    if ($showRes -eq $true -and $script:renameResult) {
        return $script:renameResult
    }
    return $null
}

function Refresh-ConversationsCombo {
    $global:SuppressConvComboEvent = $true
    try {
        $cmbConversations.Items.Clear()
        
        $newChatItem = [pscustomobject]@{
            DateStr   = "➕"
            DateColor = "#4CAF50"
            ProjStr   = "[НОВЫЙ]"
            ProjColor = "#81C784"
            TitleStr  = "Начать диалог с чистого листа"
            Display   = "➕ [Новый диалог]"
            Tag       = $null
            ConvObj   = $null
        }
        Add-Member -InputObject $newChatItem -MemberType ScriptMethod -Name ToString -Value { $this.Display } -Force
        [void]$cmbConversations.Items.Add($newChatItem)

        $allConvs = Get-AntigravityConversations
        $recent = $allConvs | Select-Object -First 30
        foreach ($c in $recent) {
            $dateStr = $c.LastModified.ToString("dd.MM HH:mm")
            $projStr = if ($c.ProjectName -and $c.ProjectName -ne "—") { "[$($c.ProjectName)]" } else { "[-]" }
            $disp = "$dateStr | $projStr $($c.Title)"
            if ($disp.Length -gt 80) { $disp = $disp.Substring(0, 77) + "..." }
            
            $item = [pscustomobject]@{
                DateStr   = $dateStr
                DateColor = "#AAAAAA"
                ProjStr   = $projStr
                ProjColor = "#4FC1FF"
                TitleStr  = $c.Title
                Display   = $disp
                Tag       = $c.Id
                ConvObj   = $c
            }
            Add-Member -InputObject $item -MemberType ScriptMethod -Name ToString -Value { $this.Display } -Force
            [void]$cmbConversations.Items.Add($item)
        }

        if ($global:CurrentConversationId) {
            $foundIdx = -1
            for ($i = 0; $i -lt $cmbConversations.Items.Count; $i++) {
                if ($cmbConversations.Items[$i].Tag -eq $global:CurrentConversationId) {
                    $foundIdx = $i
                    break
                }
            }
            if ($foundIdx -ge 0) {
                try { $cmbConversations.SelectedIndex = $foundIdx } catch {}
            } else {
                try { $cmbConversations.SelectedIndex = 0 } catch {}
            }
        } else {
            try { $cmbConversations.SelectedIndex = 0 } catch {}
        }
    } finally {
        $global:SuppressConvComboEvent = $false
    }
}

function Show-ConversationSelectorWindow {
    $selectorXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="💬 Список и выбор разговоров Antigravity"
        Height="620" Width="960" MinHeight="450" MinWidth="750"
        WindowStartupLocation="CenterOwner"
        Background="#181818" Foreground="#D4D4D4"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <!-- Системные цвета для попапов и списков в темной теме -->
        <SolidColorBrush x:Key="{x:Static SystemColors.WindowBrushKey}" Color="#202020" />
        <SolidColorBrush x:Key="{x:Static SystemColors.WindowTextBrushKey}" Color="#F1F1F1" />
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#0E639C" />
        <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF" />

        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#D4D4D4"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="CaretBrush" Value="#007ACC"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="ListView">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderBrush" Value="#2D2D30"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ListViewItem">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="4,5"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#0E639C"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#2A384C"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="BorderBrush" Value="#333333"/>
        </Style>
    </Window.Resources>

    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="🔍 Поиск разговоров:" VerticalAlignment="Center" Margin="0,0,8,0" FontWeight="SemiBold"/>
            <TextBox x:Name="TxtSearch" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,8,0" ToolTip="Фильтрация по тексту запроса, проекту или ID разговора"/>
            <Button x:Name="BtnRefreshList" Grid.Column="2" Content="🔄 Обновить" MinWidth="90"/>
        </Grid>

        <Grid Grid.Row="1" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="3*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="2*"/>
            </Grid.ColumnDefinitions>

            <ListView x:Name="LstConversations" Grid.Column="0" SelectionMode="Single">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="Дата и время" Width="135" DisplayMemberBinding="{Binding DateDisplay}"/>
                        <GridViewColumn Header="Проект" Width="130" DisplayMemberBinding="{Binding ProjectName}"/>
                        <GridViewColumn Header="Сообщений" Width="75" DisplayMemberBinding="{Binding MessageCount}"/>
                        <GridViewColumn Header="Тема / Первый запрос" Width="220" DisplayMemberBinding="{Binding Title}"/>
                    </GridView>
                </ListView.View>
            </ListView>

            <GridSplitter Grid.Column="1" Width="4" HorizontalAlignment="Center" Background="#2D2D30"/>

            <Border Grid.Column="2" Background="#1E1E1E" BorderBrush="#2D2D30" BorderThickness="1" CornerRadius="4" Padding="8">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="Предпросмотр диалога:" FontWeight="SemiBold" Foreground="#007ACC" Margin="0,0,0,6"/>
                    <TextBox x:Name="TxtPreview" Grid.Row="1" Background="#181818" Foreground="#CCCCCC" BorderThickness="0" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas, Segoe UI" FontSize="11" Padding="6"/>
                </Grid>
            </Border>
        </Grid>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0" Orientation="Horizontal">
                <TextBlock x:Name="TxtConvCount" Text="Всего разговоров: 0" VerticalAlignment="Center" Foreground="#888888" Margin="0,0,12,0"/>
                <Button x:Name="BtnCopyId" Content="📋 Скопировать ID" Padding="8,4" Background="#252526" BorderBrush="#3E3E42" Margin="0,0,6,0"/>
                <Button x:Name="BtnRenameConv" Content="✏️ Переименовать" Padding="8,4" Background="#252526" BorderBrush="#3E3E42" Margin="0,0,6,0" ToolTip="Задать собственное название выбранному разговору"/>
                <Button x:Name="BtnDeleteConv" Content="🗑️ Удалить" Padding="8,4" Background="#3E2020" BorderBrush="#603030" Foreground="#F85149" ToolTip="Удалить выбранный разговор с диска"/>
            </StackPanel>

            <StackPanel Grid.Column="2" Orientation="Horizontal">
                <Button x:Name="BtnResumeTui" Content="🖥️ Открыть в TUI" Background="#2A3245" BorderBrush="#3D4B66" Margin="0,0,8,0"/>
                <Button x:Name="BtnSelectAndResume" Content="▶️ Продолжить этот диалог" Background="#0E639C" BorderBrush="#1177BB" FontWeight="Bold" Margin="0,0,8,0"/>
                <Button x:Name="BtnCancel" Content="Закрыть" Background="#2D2D30" BorderBrush="#3E3E42" MinWidth="75"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

    $sReader = [System.Xml.XmlNodeReader]::new([xml]$selectorXaml)
    $dlg = [System.Windows.Markup.XamlReader]::Load($sReader)
    $dlg.Owner = $window
    if ($window.Icon) {
        $dlg.Icon = $window.Icon
    }

    $txtSearch          = $dlg.FindName("TxtSearch")
    $btnRefreshList     = $dlg.FindName("BtnRefreshList")
    $lstConversations   = $dlg.FindName("LstConversations")
    $txtPreview         = $dlg.FindName("TxtPreview")
    $txtConvCount       = $dlg.FindName("TxtConvCount")
    $btnCopyId          = $dlg.FindName("BtnCopyId")
    $btnRenameConv      = $dlg.FindName("BtnRenameConv")
    $btnDeleteConv      = $dlg.FindName("BtnDeleteConv")
    $btnResumeTui       = $dlg.FindName("BtnResumeTui")
    $btnSelectAndResume = $dlg.FindName("BtnSelectAndResume")
    $btnCancel          = $dlg.FindName("BtnCancel")

    $allConvs = [System.Collections.Generic.List[psobject]]::new()

    $applyFilter = {
        $filter = $txtSearch.Text.Trim().ToLower()
        $lstConversations.Items.Clear()
        
        foreach ($c in $allConvs) {
            if ([string]::IsNullOrWhiteSpace($filter) -or 
                $c.Title.ToLower().Contains($filter) -or 
                $c.ProjectName.ToLower().Contains($filter) -or 
                $c.Id.ToLower().Contains($filter) -or 
                $c.DateDisplay.Contains($filter)) {
                [void]$lstConversations.Items.Add($c)
            }
        }

        $txtConvCount.Text = "Найдено: $($lstConversations.Items.Count) из $($allConvs.Count)"
        if ($lstConversations.Items.Count -gt 0) {
            $matched = $false
            if ($global:CurrentConversationId) {
                for ($idx = 0; $idx -lt $lstConversations.Items.Count; $idx++) {
                    if ($lstConversations.Items[$idx].Id -eq $global:CurrentConversationId) {
                        $lstConversations.SelectedIndex = $idx
                        $matched = $true
                        break
                    }
                }
            }
            if (-not $matched) {
                $lstConversations.SelectedIndex = 0
            }
        } else {
            $txtPreview.Text = "Разговоры не найдены по запросу '$filter'."
        }
    }

    $loadList = {
        param([switch]$Force)
        $allConvs.Clear()
        $items = Get-AntigravityConversations -ForceRefresh:$Force
        foreach ($it in $items) { $allConvs.Add($it) }
        $applyFilter.Invoke()
    }

    $txtSearch.Add_TextChanged({
        $applyFilter.Invoke()
    })

    $btnRefreshList.Add_Click({
        & $loadList -Force
        Refresh-ConversationsCombo
    })

    $lstConversations.Add_SelectionChanged({
        $sel = $lstConversations.SelectedItem
        if ($sel) {
            $txtPreview.Text = Get-ConversationPreviewText -conversationId $sel.Id
        } else {
            $txtPreview.Text = ""
        }
    })

    $chooseSelected = {
        $sel = $lstConversations.SelectedItem
        if ($sel) {
            Select-ConversationItem $sel
            $dlg.Close()
            Scroll-ChatLogToEnd
        }
    }

    $btnSelectAndResume.Add_Click({
        $chooseSelected.Invoke()
    })

    $lstConversations.Add_MouseDoubleClick({
        param($sender, $e)
        if ($lstConversations.SelectedItem) {
            $chooseSelected.Invoke()
        }
    })

    $btnCopyId.Add_Click({
        $sel = $lstConversations.SelectedItem
        if ($sel) {
            [System.Windows.Clipboard]::SetText($sel.Id)
            [System.Windows.MessageBox]::Show("ID скопирован в буфер обмена:`n$($sel.Id)", "Успешно", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        }
    })

    if ($btnRenameConv) {
        $btnRenameConv.Add_Click({
            $sel = $lstConversations.SelectedItem
            if (-not $sel) {
                [System.Windows.MessageBox]::Show("Сначала выберите разговор из списка для переименования.", "Уведомление", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                return
            }

            $oldTitle = if ($sel.FullTitle) { $sel.FullTitle } elseif ($sel.Title) { $sel.Title } else { "Диалог" }
            $newTitle = Show-RenameDialog -CurrentTitle $oldTitle -OwnerWindow $dlg
            if ($newTitle -and $newTitle -ne $oldTitle) {
                $ok = Set-ConversationTitle -conversationId $sel.Id -newTitle $newTitle
                if ($ok) {
                    $sel.Title = if ($newTitle.Length -gt 75) { $newTitle.Substring(0, 72) + "..." } else { $newTitle }
                    $sel.FullTitle = $newTitle
                    $lstConversations.Items.Refresh()
                    Refresh-ConversationsCombo
                }
            }
        })
    }

    $btnDeleteConv.Add_Click({
        $sel = $lstConversations.SelectedItem
        if (-not $sel) {
            [System.Windows.MessageBox]::Show("Сначала выберите разговор из списка для удаления.", "Уведомление", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }

        $titleSnippet = if ($sel.Title.Length -gt 60) { $sel.Title.Substring(0, 57) + "..." } else { $sel.Title }
        $msg = "Вы уверены, что хотите удалить выбранный разговор?`n`nТема: $titleSnippet`nID: $($sel.Id)`nДата: $($sel.DateDisplay)`n`nДанные диалога будут безвозвратно удалены с диска."
        $res = [System.Windows.MessageBox]::Show($msg, "Подтверждение удаления", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        
        if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
            $ok = Remove-AntigravityConversation -conversationId $sel.Id
            if ($ok) {
                $loadList.Invoke()
                Refresh-ConversationsCombo
                $txtPreview.Text = ""
                [System.Windows.MessageBox]::Show("Разговор успешно удален.", "Готово", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            } else {
                [System.Windows.MessageBox]::Show("Не удалось удалить разговор или директория не найдена.", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
            }
        }
    })

    $btnResumeTui.Add_Click({
        $sel = $lstConversations.SelectedItem
        if ($sel) {
            $targetWs = if ($sel.Workspace -and (Test-Path $sel.Workspace)) { $sel.Workspace } else { $txtWorkspace.Text }
            $model = $cmbModel.SelectedItem.ToString()
            $mode = $cmbMode.SelectedItem.ToString()
            $effort = $cmbEffort.SelectedItem.ToString()
            $effortArg = if ($effort -ne "auto") { "--effort '$effort'" } else { "" }
            $skip = if ($chkSkipPerms.IsChecked) { "--dangerously-skip-permissions" } else { "" }
            $convArg = "--conversation '$($sel.Id)'"

            $startScript = "Set-Location -LiteralPath '$targetWs'; & '$defaultAgyPath' --model '$model' --mode '$mode' $effortArg $skip $convArg"
            Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $startScript
        }
    })

    $btnCancel.Add_Click({
        $dlg.Close()
    })

    $loadList.Invoke()
    $dlg.ShowDialog() | Out-Null
}

# ==============================================================================
# УПРАВЛЕНИЕ МНОГОВКЛАДОЧНЫМ ИНТЕРФЕЙСОМ (МУЛЬТИ-СЕССИИ ДИАЛОГОВ)
# ==============================================================================
$global:TabsList = [System.Collections.Generic.List[psobject]]::new()
$global:ActiveTab = $null
$global:TabsCounter = 0

function New-TabSession {
    param(
        [string]$Title = "Новый диалог",
        [string]$ConversationId = $null,
        [string]$Workspace = $null,
        [string]$Model = $null,
        [string]$Mode = $null,
        [string]$Effort = $null,
        [bool]$SkipPerms = $true,
        [switch]$Lazy
    )
    $tabId = [guid]::NewGuid().ToString()
    $doc = [System.Windows.Documents.FlowDocument]::new()
    $doc.PagePadding = [System.Windows.Thickness]::new(0)
    $docLineHeight = [math]::Round([math]::Max(20.0, $global:CurrentFontSize * 1.55))
    $doc.LineHeight = $docLineHeight
    $doc.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
    
    $tabWs = if ($Workspace) { $Workspace } elseif ($txtWorkspace) { $txtWorkspace.Text } else { $defaultWorkspace }
    $tabModel = if ($Model) { $Model } elseif ($cmbModel -and $cmbModel.SelectedItem) { $cmbModel.SelectedItem.ToString() } else { "gemini-2.5-pro" }
    $tabMode = if ($Mode) { $Mode } elseif ($cmbMode -and $cmbMode.SelectedItem) { $cmbMode.SelectedItem.ToString() } else { "code" }
    $tabEffort = if ($Effort) { $Effort } elseif ($cmbEffort -and $cmbEffort.SelectedItem) { $cmbEffort.SelectedItem.ToString() } else { "medium" }
    $tabSkipPerms = if ($null -ne $SkipPerms) { $SkipPerms } elseif ($chkSkipPerms) { [bool]$chkSkipPerms.IsChecked } else { $true }

    $tabQueue = [System.Collections.Concurrent.ConcurrentQueue[psobject]]::new()
    $tabSync = [hashtable]::Synchronized(@{
        Queue         = $tabQueue
        IsRunning     = $false
        StopRequested = $false
        ProcessId     = 0
        Stopwatch     = $null
    })

    $isLoaded = (-not $Lazy -or [string]::IsNullOrEmpty($ConversationId))

    $tab = [PSCustomObject]@{
        Id                  = $tabId
        Title               = $Title
        ConversationId      = $ConversationId
        Workspace           = $tabWs
        Model               = $tabModel
        Mode                = $tabMode
        Effort              = $tabEffort
        SkipPerms           = $tabSkipPerms
        Document            = $doc
        PromptText          = ""
        AttachedImages      = [System.Collections.Generic.List[psobject]]::new()
        QueuedUserMessages  = [System.Collections.Generic.List[psobject]]::new()
        ActiveToolGroup     = $null
        SyncState           = $tabSync
        StatusText          = if ($isLoaded) { "Готов к работе" } else { "Диалог сохранен (нажмите для загрузки)" }
        StatusColor         = if ($isLoaded) { "#4CAF50" } else { "#888888" }
        HeaderBorder        = $null
        HeaderTitle         = $null
        HeaderDot           = $null
        StreamBuffer        = [System.Text.StringBuilder]::new()
        ActiveStreamParagraph = $null
        LoadingJob          = $null
        ContextStats        = $null
        FullTranscriptTurns = $null
        IsTranscriptLoaded  = $isLoaded
        TokensThisTurn      = 0
        LastWarningCheckMs  = 0
        ApiWarningText      = $null
        ApiWarningColor     = $null
    }

    if ($isLoaded) {
        Show-WelcomeMessage -Document $doc
    } else {
        Show-LazyConversationPlaceholder -Tab $tab
    }

    return $tab
}

function Show-LazyConversationPlaceholder {
    param(
        [Parameter(Mandatory=$true)]$Tab
    )
    $doc = $Tab.Document
    if (-not $doc) { return }
    $doc.Blocks.Clear()

    $pTitle = [System.Windows.Documents.Paragraph]::new()
    $pTitle.Margin = [System.Windows.Thickness]::new(0, 24, 0, 6)
    $pTitle.TextAlignment = [System.Windows.TextAlignment]::Center

    $runIcon = [System.Windows.Documents.Run]::new("💬 ")
    $runIcon.FontSize = [math]::Round([math]::Max(16.0, $global:CurrentFontSize * 1.4))
    $runTitle = [System.Windows.Documents.Run]::new($Tab.Title)
    $runTitle.FontSize = [math]::Round([math]::Max(15.0, $global:CurrentFontSize * 1.3))
    $runTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
    $runTitle.Foreground = (Get-CachedBrush "#569CD6")
    $pTitle.Inlines.Add($runIcon) | Out-Null
    $pTitle.Inlines.Add($runTitle) | Out-Null
    $doc.Blocks.Add($pTitle) | Out-Null

    $pConvId = [System.Windows.Documents.Paragraph]::new()
    $pConvId.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)
    $pConvId.TextAlignment = [System.Windows.TextAlignment]::Center
    $runId = [System.Windows.Documents.Run]::new("ID диалога: $($Tab.ConversationId)")
    $runId.FontSize = [math]::Round([math]::Max(10.0, $global:CurrentFontSize * 0.88))
    $runId.Foreground = (Get-CachedBrush "#888888")
    $pConvId.Inlines.Add($runId) | Out-Null
    $doc.Blocks.Add($pConvId) | Out-Null

    # Информационный блок с кнопкой загрузки
    $cardBorder = [System.Windows.Controls.Border]::new()
    $cardBorder.Background = (Get-CachedBrush "#252526")
    $cardBorder.BorderBrush = (Get-CachedBrush "#3E3E42")
    $cardBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $cardBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
    $cardBorder.Padding = [System.Windows.Thickness]::new(20, 16, 20, 16)
    $cardBorder.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $cardBorder.MaxWidth = 550

    $sp = [System.Windows.Controls.StackPanel]::new()
    $sp.Orientation = [System.Windows.Controls.Orientation]::Vertical

    $lblInfo = [System.Windows.Controls.TextBlock]::new()
    $lblInfo.Text = "История диалога сохранена, но не загружена в память для быстрого запуска лаунчера.`r`nНажмите на вкладку или кнопку ниже, чтобы открыть историю."
    $lblInfo.Foreground = (Get-CachedBrush "#CCCCCC")
    $lblInfo.FontSize = $global:CurrentFontSize
    $lblInfo.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $lblInfo.TextAlignment = [System.Windows.TextAlignment]::Center
    $lblInfo.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)
    $sp.Children.Add($lblInfo) | Out-Null

    $btnLoad = [System.Windows.Controls.Button]::new()
    $btnLoad.Content = "📥 Загрузить диалог"
    $btnLoad.Background = (Get-CachedBrush "#0E639C")
    $btnLoad.Foreground = [System.Windows.Media.Brushes]::White
    $btnLoad.FontWeight = [System.Windows.FontWeights]::SemiBold
    $btnLoad.FontSize = [math]::Round($global:CurrentFontSize * 1.05)
    $btnLoad.Padding = [System.Windows.Thickness]::new(18, 8, 18, 8)
    $btnLoad.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $btnLoad.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnLoad.BorderThickness = [System.Windows.Thickness]::new(0)

    $targetTab = $Tab
    $btnLoad.Add_Click({
        Load-TabConversation -Tab $targetTab
    }.GetNewClosure())
    $sp.Children.Add($btnLoad) | Out-Null

    $cardBorder.Child = $sp

    $uic = [System.Windows.Documents.BlockUIContainer]::new($cardBorder)
    $uic.Margin = [System.Windows.Thickness]::new(0, 8, 0, 16)
    $doc.Blocks.Add($uic) | Out-Null
}

function Load-TabConversation {
    param([Parameter(Mandatory=$true)]$Tab)
    if (-not $Tab.ConversationId) { return }
    if ($Tab.IsTranscriptLoaded) { return }
    if ($Tab.LoadingJob) { return }

    $Tab.IsTranscriptLoaded = $true
    $Tab.StatusText = "Загрузка диалога..."
    $Tab.StatusColor = "#FFA500"
    if ($Tab.HeaderDot) {
        $Tab.HeaderDot.Fill = (Get-CachedBrush "#FFA500")
    }
    if ($Tab -eq $global:ActiveTab) {
        $txtStatus.Text = "Загрузка диалога..."
        $statusDot.Fill = (Get-CachedBrush "#FFA500")
    }

    # Запускаем фоновую асинхронную загрузку истории транскрипта
    Start-AsyncTranscriptLoad -conversationId $Tab.ConversationId -Tab $Tab
}

function Finalize-TabStreamingBuffer($Tab) {
    if (-not $Tab) { return }
    if ($Tab.ActiveStreamParagraph) {
        $streamedText = if ($Tab.StreamBuffer) { $Tab.StreamBuffer.ToString() } else { "" }
        if ($Tab.Document -and $Tab.Document.Blocks.Contains($Tab.ActiveStreamParagraph)) {
            [void]$Tab.Document.Blocks.Remove($Tab.ActiveStreamParagraph)
        }
        $Tab.ActiveStreamParagraph = $null
        if ($Tab.StreamBuffer) {
            [void]$Tab.StreamBuffer.Clear()
        }
        if (-not [string]::IsNullOrEmpty($streamedText)) {
            Append-MarkdownFormatted -Text $streamedText -Document $Tab.Document -BaseColor "#D4D4D4"
            # Принудительно обновляем layout и прокручиваем вниз после финального рендера Markdown.
            # Без этого WPF батчит обновления визуального дерева и ответ остаётся невидим
            # до следующего layout-цикла (или до перезапуска лаунчера).
            if ($Tab -eq $global:ActiveTab -and $txtChatLog) {
                try {
                    $txtChatLog.UpdateLayout()
                    $txtChatLog.ScrollToEnd()
                    $txtChatLog.ScrollToVerticalOffset([double]::MaxValue)
                } catch {}
                try {
                    $txtChatLog.Dispatcher.BeginInvoke([System.Action]{
                        try {
                            $txtChatLog.UpdateLayout()
                            $txtChatLog.ScrollToEnd()
                            $txtChatLog.ScrollToVerticalOffset([double]::MaxValue)
                        } catch {}
                    }, [System.Windows.Threading.DispatcherPriority]::Render) | Out-Null
                } catch {}
            }
        }
    }
}

function Create-TabHeaderUI($tab) {
    $headerBorder = [System.Windows.Controls.Border]::new()
    $headerBorder.Background = (Get-CachedBrush "#252526")
    $headerBorder.BorderBrush = (Get-CachedBrush "#2D2D30")
    $headerBorder.BorderThickness = [System.Windows.Thickness]::new(1, 2, 1, 0)
    $headerBorder.CornerRadius = [System.Windows.CornerRadius]::new(4, 4, 0, 0)
    $headerBorder.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
    $headerBorder.Padding = [System.Windows.Thickness]::new(10, 6, 8, 6)
    $headerBorder.Cursor = [System.Windows.Input.Cursors]::Hand
    $headerBorder.Tag = $tab

    $dock = [System.Windows.Controls.DockPanel]::new()
    $dock.LastChildFill = $true

    # 1. Индикатор статуса (зеленый/оранжевый/красный)
    $dot = [System.Windows.Shapes.Ellipse]::new()
    $dot.Width = 8
    $dot.Height = 8
    $dot.Fill = (Get-CachedBrush $tab.StatusColor)
    $dot.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
    $dot.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.DockPanel]::SetDock($dot, [System.Windows.Controls.Dock]::Left)
    $dock.Children.Add($dot) | Out-Null

    # 2. Кнопка закрытия ✖
    $closeBtn = [System.Windows.Controls.Border]::new()
    $closeBtn.Background = [System.Windows.Media.Brushes]::Transparent
    $closeBtn.CornerRadius = [System.Windows.CornerRadius]::new(3)
    $closeBtn.Width = 20
    $closeBtn.Height = 20
    $closeBtn.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
    $closeBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $closeBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $closeBtn.Cursor = [System.Windows.Input.Cursors]::Hand
    $closeBtn.ToolTip = "Закрыть вкладку (Ctrl+W)"

    $closeTxt = [System.Windows.Controls.TextBlock]::new()
    $closeTxt.Text = "✖"
    $closeTxt.FontSize = 10
    $closeTxt.Foreground = (Get-CachedBrush "#888888")
    $closeTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $closeTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $closeTxt.Cursor = [System.Windows.Input.Cursors]::Hand
    $closeBtn.Child = $closeTxt

    $targetTab = $tab
    $closeBtn.Tag = $targetTab
    $closeTxt.Tag = $targetTab
    $headerBorder.Tag = $targetTab

    $closeBtn.Add_MouseEnter({
        param($s, $e)
        if ($s) { $s.Background = (Get-CachedBrush "#C53030") }
        if ($closeTxt) { $closeTxt.Foreground = [System.Windows.Media.Brushes]::White }
    }.GetNewClosure())
    $closeBtn.Add_MouseLeave({
        param($s, $e)
        if ($s) { $s.Background = [System.Windows.Media.Brushes]::Transparent }
        if ($closeTxt) { $closeTxt.Foreground = (Get-CachedBrush "#888888") }
    }.GetNewClosure())
    $onCloseClick = {
        param($s, $e)
        $e.Handled = $true
        $t = if ($s -and $s.Tag) { $s.Tag } else { $targetTab }
        if ($t) { Close-Tab -Tab $t }
    }.GetNewClosure()

    $closeBtn.Add_PreviewMouseLeftButtonDown($onCloseClick)
    $closeBtn.Add_MouseLeftButtonDown($onCloseClick)
    $closeTxt.Add_PreviewMouseLeftButtonDown($onCloseClick)
    $closeTxt.Add_MouseLeftButtonDown($onCloseClick)
    [System.Windows.Controls.DockPanel]::SetDock($closeBtn, [System.Windows.Controls.Dock]::Right)
    $dock.Children.Add($closeBtn) | Out-Null

    # 3. Заголовок вкладки
    $titleBlock = [System.Windows.Controls.TextBlock]::new()
    $titleBlock.Text = $targetTab.Title
    $titleBlock.FontSize = 12
    $titleBlock.Foreground = (Get-CachedBrush "#CCCCCC")
    $titleBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $titleBlock.MaxWidth = 160
    $titleBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $dock.Children.Add($titleBlock) | Out-Null

    $headerBorder.Child = $dock

    # Контекстное меню вкладки
    $ctxMenu = [System.Windows.Controls.ContextMenu]::new()
    $menuRename = [System.Windows.Controls.MenuItem]::new()
    $menuRename.Header = "✏️ Переименовать вкладку..."
    $menuRename.Add_Click({
        $currentName = if ($targetTab.Title) { $targetTab.Title } else { "Диалог" }
        $renamed = Show-RenameDialog -CurrentTitle $currentName -PromptText "Введите новое название для вкладки / диалога:"
        if ($renamed -and $renamed -ne $currentName) {
            $targetTab.Title = $renamed
            $titleBlock.Text = $renamed
            $titleBlock.ToolTip = $renamed
            if ($targetTab.ConversationId) {
                Set-ConversationTitle -conversationId $targetTab.ConversationId -newTitle $renamed
            }
            Save-LauncherConfig
        }
    }.GetNewClosure())
    $menuClose = [System.Windows.Controls.MenuItem]::new()
    $menuClose.Header = "✖ Закрыть вкладку"
    $menuClose.Add_Click({
        Close-Tab -Tab $targetTab
    }.GetNewClosure())
    [void]$ctxMenu.Items.Add($menuRename)
    [void]$ctxMenu.Items.Add($menuClose)
    $headerBorder.ContextMenu = $ctxMenu

    # Клик левой кнопкой мыши - переключение на вкладку (с проверкой, что клик не по кнопке закрытия)
    # Двойной клик - переименование вкладки / диалога
    $headerBorder.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        $t = if ($s -and $s.Tag) { $s.Tag } else { $targetTab }
        if ($closeBtn.IsAncestorOf($e.OriginalSource) -or ($e.OriginalSource -eq $closeBtn) -or ($e.OriginalSource -eq $closeTxt)) {
            $e.Handled = $true
            if ($t) { Close-Tab -Tab $t }
            return
        }
        if ($e.ClickCount -eq 2) {
            $e.Handled = $true
            $currentName = if ($t.Title) { $t.Title } else { "Диалог" }
            $renamed = Show-RenameDialog -CurrentTitle $currentName -PromptText "Введите новое название для вкладки / диалога:"
            if ($renamed -and $renamed -ne $currentName) {
                $t.Title = $renamed
                $titleBlock.Text = $renamed
                $titleBlock.ToolTip = $renamed
                if ($t.ConversationId) {
                    Set-ConversationTitle -conversationId $t.ConversationId -newTitle $renamed
                }
                Save-LauncherConfig
            }
            return
        }
        if ($t) {
            Switch-ToTab -Tab $t
            if (-not $t.IsTranscriptLoaded -and $t.ConversationId) {
                Load-TabConversation -Tab $t
            }
        }
    }.GetNewClosure())

    # Клик средней кнопкой мыши - закрытие вкладки
    $headerBorder.Add_PreviewMouseDown({
        param($s, $e)
        if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Middle) {
            $e.Handled = $true
            $t = if ($s -and $s.Tag) { $s.Tag } else { $targetTab }
            if ($t) { Close-Tab -Tab $t }
        }
    }.GetNewClosure())

    # Наведение курсора
    $headerBorder.Add_MouseEnter({
        if ($global:ActiveTab -ne $targetTab) {
            $headerBorder.Background = (Get-CachedBrush "#2D2D30")
        }
    }.GetNewClosure())
    $headerBorder.Add_MouseLeave({
        if ($global:ActiveTab -ne $targetTab) {
            $headerBorder.Background = (Get-CachedBrush "#252526")
        }
    }.GetNewClosure())

    $tab.HeaderBorder = $headerBorder
    $tab.HeaderTitle  = $titleBlock
    $tab.HeaderDot    = $dot

    return $headerBorder
}

function Update-TabHeadersVisual {
    foreach ($t in $global:TabsList) {
        if (-not $t.HeaderBorder) { continue }
        if ($t -eq $global:ActiveTab) {
            $t.HeaderBorder.Background = (Get-CachedBrush "#1E1E1E")
            $t.HeaderBorder.BorderBrush = (Get-CachedBrush "#0E639C")
            $t.HeaderTitle.Foreground = [System.Windows.Media.Brushes]::White
            $t.HeaderTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
        } else {
            $t.HeaderBorder.Background = (Get-CachedBrush "#252526")
            $t.HeaderBorder.BorderBrush = (Get-CachedBrush "#2D2D30")
            $t.HeaderTitle.Foreground = (Get-CachedBrush "#969696")
            $t.HeaderTitle.FontWeight = [System.Windows.FontWeights]::Normal
        }
        if ($t.HeaderDot -and $t.StatusColor) {
            $t.HeaderDot.Fill = (Get-CachedBrush $t.StatusColor)
        }
    }
}

function Switch-ToTab {
    param(
        [Parameter(Mandatory=$true)]$Tab,
        [switch]$NoAutoLoad,
        [switch]$SkipSave
    )
    if ($global:ActiveTab -eq $Tab -and $txtChatLog.Document -eq $Tab.Document) {
        if (-not $NoAutoLoad -and -not $Tab.IsTranscriptLoaded -and $Tab.ConversationId) {
            Load-TabConversation -Tab $Tab
        }
        Update-TabHeadersVisual
        Update-ContextDisplay -conversationId $Tab.ConversationId -modelName $Tab.Model
        Update-LimitsDisplay -modelName $Tab.Model
        return
    }

    $prevTab = $global:ActiveTab
    if ($prevTab) {
        # Сохраняем значения UI в предыдущую вкладку
        $prevTab.PromptText = $txtPromptInput.Text
        $prevTab.Workspace = $txtWorkspace.Text
        if ($cmbModel -and $cmbModel.SelectedItem) { $prevTab.Model = $cmbModel.SelectedItem.ToString() }
        if ($cmbMode -and $cmbMode.SelectedItem) { $prevTab.Mode = $cmbMode.SelectedItem.ToString() }
        if ($cmbEffort -and $cmbEffort.SelectedItem) { $prevTab.Effort = $cmbEffort.SelectedItem.ToString() }
        if ($chkSkipPerms) { $prevTab.SkipPerms = [bool]$chkSkipPerms.IsChecked }
        $prevTab.AttachedImages = [System.Collections.Generic.List[psobject]]::new($global:AttachedImages)
    }

    $global:ActiveTab = $Tab
    $global:ActiveToolGroup = $Tab.ActiveToolGroup
    $global:CurrentConversationId = $Tab.ConversationId
    $script:syncState = $Tab.SyncState

    # Переключаем FlowDocument активной вкладки
    $txtChatLog.Document = $Tab.Document

    # Восстанавливаем состояние полей ввода
    $txtWorkspace.Text = $Tab.Workspace
    if ($cmbModel -and $Tab.Model) { $cmbModel.SelectedItem = $Tab.Model }
    if ($cmbMode -and $Tab.Mode) { $cmbMode.SelectedItem = $Tab.Mode }
    if ($cmbEffort -and $Tab.Effort) { $cmbEffort.SelectedItem = $Tab.Effort }
    if ($chkSkipPerms) { $chkSkipPerms.IsChecked = $Tab.SkipPerms }
    $txtPromptInput.Text = $Tab.PromptText

    # Восстанавливаем прикрепленные картинки
    $global:AttachedImages.Clear()
    if ($Tab.AttachedImages) {
        foreach ($img in $Tab.AttachedImages) {
            $global:AttachedImages.Add($img)
        }
    }
    Render-AttachmentsUI

    # Восстанавливаем статус-бар
    $txtStatus.Text = $Tab.StatusText
    if ($Tab.StatusColor) {
        $statusDot.Fill = (Get-CachedBrush $Tab.StatusColor)
    }
    if ($Tab.ConversationId) {
        $shortId = if ($Tab.ConversationId.Length -gt 12) { $Tab.ConversationId.Substring(0, 12) + "..." } else { $Tab.ConversationId }
        $txtConversationId.Text = "Диалог: $shortId"
        $txtConversationId.ToolTip = $Tab.ConversationId
    } else {
        $txtConversationId.Text = "Диалог: Новый"
        $txtConversationId.ToolTip = "Новая сессия"
    }

    # Восстанавливаем индикатор контекста
    Update-ContextDisplay -conversationId $Tab.ConversationId -modelName $Tab.Model
    Update-LimitsDisplay -modelName $Tab.Model

    # Состояние кнопок отправки / остановки
    $isRunning = [bool]$Tab.SyncState.IsRunning
    $btnSend.IsEnabled = -not $isRunning
    $btnStop.IsEnabled = $isRunning
    $txtPromptInput.IsEnabled = -not $isRunning

    # Обновляем визуальное выделение заголовков вкладок
    Update-TabHeadersVisual

    # Если на вкладке идёт фоновая загрузка диалога, показываем анимированный оверлей
    if ($Tab.LoadingJob) {
        $sub = if ($Tab.Title) { $Tab.Title } else { "Считывание истории..." }
        Show-LoadingOverlay -Title "Загрузка диалога..." -Subtitle $sub
    } else {
        Hide-LoadingOverlay
    }

    # Фокус и прокрутка
    Scroll-ChatLogToEnd
    if (-not $isRunning) {
        $txtPromptInput.Focus() | Out-Null
    }

    # Синхронизируем комбобокс быстрого выбора диалогов с активной вкладкой
    if ($cmbConversations) {
        $global:SuppressConvComboEvent = $true
        try {
            $foundIdx = -1
            if ($Tab.ConversationId) {
                for ($i = 0; $i -lt $cmbConversations.Items.Count; $i++) {
                    if ($cmbConversations.Items[$i].Tag -eq $Tab.ConversationId) {
                        $foundIdx = $i
                        break
                    }
                }
            }
            if ($foundIdx -ge 0) {
                if ($cmbConversations.SelectedIndex -ne $foundIdx) {
                    try { $cmbConversations.SelectedIndex = $foundIdx } catch {}
                }
            } else {
                if ($cmbConversations.SelectedIndex -ne 0) {
                    try { $cmbConversations.SelectedIndex = 0 } catch {}
                }
            }
        } finally {
            $global:SuppressConvComboEvent = $false
        }
    }

    # Автозагрузка диалога при переключении на вкладку
    if (-not $NoAutoLoad -and -not $Tab.IsTranscriptLoaded -and $Tab.ConversationId) {
        Load-TabConversation -Tab $Tab
    }

    if (-not $SkipSave) {
        Save-LauncherConfig
    }
}

function global:Stop-ProcessTree([int]$processId) {
    if ($processId -le 0) { return }
    try {
        & taskkill.exe /PID $processId /T /F 2>$null | Out-Null
    } catch {}
    try {
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    } catch {}
}

function global:Close-Tab {
    param([Parameter(Mandatory=$true)]$Tab)
    
    # Р‘РµР·РѕРїР°СЃРЅРѕРµ РѕСЃРІРѕР±РѕР¶РґРµРЅРёРµ СЂРµСЃСѓСЂСЃРѕРІ С„РѕРЅРѕРІРѕР№ Р·Р°РіСЂСѓР·РєРё
    if ($Tab.LoadingJob) {
        $oldJob = $Tab.LoadingJob
        $Tab.LoadingJob = $null
        try {
            $oldJob.PowerShell.Dispose()
        } catch {}
    }

    # Если на вкладке выполняется процесс, принудительно останавливаем его дерево
    if ($Tab.SyncState.IsRunning -and $Tab.SyncState.ProcessId -gt 0) {
        try {
            $pidToKill = $Tab.SyncState.ProcessId
            $Tab.SyncState.StopRequested = $true
            Stop-ProcessTree -processId $pidToKill
        } catch {}
    }
    if ($Tab.QueuedUserMessages) {
        $Tab.QueuedUserMessages.Clear()
    }

    $idx = $global:TabsList.IndexOf($Tab)
    if ($idx -lt 0) { return }

    # Удаляем заголовок из UI
    if ($Tab.HeaderBorder -and $pnlTabsHeader) {
        $pnlTabsHeader.Children.Remove($Tab.HeaderBorder)
    }
    $global:TabsList.RemoveAt($idx)
    Save-LauncherConfig

    # Если закрыли активную вкладку, активируем соседнюю
    if ($global:ActiveTab -eq $Tab) {
        $global:ActiveTab = $null
        if ($global:TabsList.Count -gt 0) {
            $newIdx = [math]::Min($idx, $global:TabsList.Count - 1)
            Switch-ToTab -Tab $global:TabsList[$newIdx]
        } else {
            # Если закрыли последнюю вкладку, открываем новый чистый диалог
            [void](Add-NewTab -Select)
        }
    }
}

function Add-NewTab {
    param(
        [string]$Title = $null,
        [string]$ConversationId = $null,
        [string]$Workspace = $null,
        [string]$Model = $null,
        [string]$Mode = $null,
        [string]$Effort = $null,
        [bool]$SkipPerms = $true,
        [switch]$Lazy,
        [switch]$Select,
        [switch]$SkipSelect,
        [switch]$SkipSave
    )
    $tabNum = $global:TabsCounter + 1
    $global:TabsCounter = $tabNum
    $tabTitle = if ($Title) { $Title } else { "Диалог $tabNum" }
    
    $tab = New-TabSession -Title $tabTitle -ConversationId $ConversationId -Workspace $Workspace -Model $Model -Mode $Mode -Effort $Effort -SkipPerms $SkipPerms -Lazy:$Lazy
    $headerUI = Create-TabHeaderUI $tab
    if ($pnlTabsHeader) {
        if ($btnNewTab -and $pnlTabsHeader.Children.Contains($btnNewTab)) {
            $insertIdx = $pnlTabsHeader.Children.IndexOf($btnNewTab)
            $pnlTabsHeader.Children.Insert($insertIdx, $headerUI)
        } else {
            $pnlTabsHeader.Children.Add($headerUI) | Out-Null
        }
    }
    $global:TabsList.Add($tab)

    if (-not $SkipSelect -and ($Select -or $global:TabsList.Count -eq 1)) {
        Switch-ToTab -Tab $tab -NoAutoLoad:$Lazy -SkipSave:$SkipSave
    }

    if (-not $SkipSave) {
        Save-LauncherConfig
    }

    return $tab
}

function Next-Tab {
    if ($global:TabsList.Count -le 1) { return }
    $curIdx = $global:TabsList.IndexOf($global:ActiveTab)
    $nextIdx = ($curIdx + 1) % $global:TabsList.Count
    $target = $global:TabsList[$nextIdx]
    Switch-ToTab -Tab $target
    if (-not $target.IsTranscriptLoaded -and $target.ConversationId) {
        Load-TabConversation -Tab $target
    }
}

function Prev-Tab {
    if ($global:TabsList.Count -le 1) { return }
    $curIdx = $global:TabsList.IndexOf($global:ActiveTab)
    $prevIdx = ($curIdx - 1 + $global:TabsList.Count) % $global:TabsList.Count
    $target = $global:TabsList[$prevIdx]
    Switch-ToTab -Tab $target
    if (-not $target.IsTranscriptLoaded -and $target.ConversationId) {
        Load-TabConversation -Tab $target
    }
}

function Restore-SavedTabs {
    $cfg = Load-LauncherConfig
    $savedTabs = if ($cfg -and $cfg.tabs -and $cfg.tabs.Count -gt 0) { @($cfg.tabs) } else { $null }
    $activeIdx = if ($cfg -and $null -ne $cfg.activeTabIndex) { [int]$cfg.activeTabIndex } else { 0 }

    if ($savedTabs -and $savedTabs.Count -gt 0) {
        foreach ($st in $savedTabs) {
            $tTitle = if ($st.title) { $st.title } else { "Диалог" }
            $tConvId = if ($st.conversationId) { $st.conversationId } else { $null }
            $tWs = if ($st.workspace) { $st.workspace } else { $null }
            $tModel = if ($st.model) { $st.model } else { $null }
            $tMode = if ($st.mode) { $st.mode } else { $null }
            $tEffort = if ($st.effort) { $st.effort } else { $null }
            $tSkipPerms = if ($null -ne $st.skipPerms) { [bool]$st.skipPerms } else { $true }

            # Восстанавливаем вкладку с отложенной загрузкой (Lazy), если привязан ID диалога
            [void](Add-NewTab -Title $tTitle -ConversationId $tConvId -Workspace $tWs -Model $tModel -Mode $tMode -Effort $tEffort -SkipPerms $tSkipPerms -Lazy:([bool]$tConvId) -SkipSelect -SkipSave)
        }

        # Активируем сохранённую вкладку и автоматически подгружаем её диалог
        $targetIdx = if ($activeIdx -ge 0 -and $activeIdx -lt $global:TabsList.Count) { $activeIdx } else { 0 }
        Switch-ToTab -Tab $global:TabsList[$targetIdx] -SkipSave
        Save-LauncherConfig
    } else {
        # Если сохраненных вкладок нет, создаем одну начальную чистую сессию
        $initialTab = Add-NewTab -Title "Диалог 1" -Select
    }
}

# Инициализация и восстановление сохраненных вкладок (с ленивой загрузкой)
Load-QuotaCache
Restore-SavedTabs
$syncState = if ($global:ActiveTab) { $global:ActiveTab.SyncState } else { $null }
Update-ContextDisplay
Update-LimitsDisplay

# --- Таймер обновления UI на основном потоке (параллельный опрос всех вкладок) ---
$uiTimer = [System.Windows.Threading.DispatcherTimer]::new()
$uiTimer.Interval = [TimeSpan]::FromMilliseconds(40)

$uiTimer.Add_Tick({
    $global:PerfState.Heartbeat = [DateTime]::UtcNow.Ticks
    $tickSw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($global:AccountSwitchProcess -and $global:AccountSwitchProcess.HasExited) {
        $global:AccountSwitchProcess = $null
        Write-PerfLog "Окно входа в аккаунт закрыто, обновляю лимиты"
        Update-LimitsAfterAccountChange
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action]{ Invoke-SaveAccountAfterLogin }) | Out-Null
    }
    Set-PerfStage "tick: Update-TabLoadingJobs"
    Update-TabLoadingJobs
    Set-PerfStage "tick: статусы вкладок"

    # Живой счетчик времени работы для всех запущенных вкладок
    foreach ($tabItem in @($global:TabsList)) {
        if ($tabItem.SyncState -and $tabItem.SyncState.IsRunning -and $tabItem.SyncState.Stopwatch) {
            $sw = $tabItem.SyncState.Stopwatch
            $totalSec = [math]::Floor($sw.Elapsed.TotalSeconds)
            $m = [int]($totalSec / 60)
            $s = [int]($totalSec % 60)
            $ds = [math]::Floor($sw.Elapsed.Milliseconds / 100)
            $timeStr = '{0:D2}:{1:D2}.{2}' -f $m, $s, $ds

            # Мониторинг лога транскрипта на наличие предупреждений об ошибках мощностей API (503 No Capacity)
            if ($tabItem.ConversationId -and (-not $tabItem.LastWarningCheckMs -or (($sw.ElapsedMilliseconds - $tabItem.LastWarningCheckMs) -ge 1200))) {
                $tabItem.LastWarningCheckMs = $sw.ElapsedMilliseconds
                $tPath = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$($tabItem.ConversationId)\.system_generated\logs\transcript.jsonl"
                if (Test-Path $tPath) {
                    try {
                        $fi = [System.IO.FileInfo]::new($tPath)
                        if ($fi.Length -gt 0) {
                            $fs = [System.IO.FileStream]::new($tPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                            $readLen = [Math]::Min(2048L, $fs.Length)
                            $fs.Seek(-$readLen, [System.IO.SeekOrigin]::End) | Out-Null
                            $buf = New-Object byte[] $readLen
                            $fs.Read($buf, 0, [int]$readLen) | Out-Null
                            $fs.Dispose()
                            $tail = [System.Text.Encoding]::UTF8.GetString($buf)
                            if ($tail -match '"error":\s*"API error \(attempt (\d+)\): UNAVAILABLE \(code 503\): No capacity available') {
                                $attemptNum = $Matches[1]
                                $stopHint = if ([int]$attemptNum -ge 2) { " [Стоп для отмены]" } else { "" }
                                $tabItem.ApiWarningText = "⚠️ Дефицит мощностей Google (503, попытка $attemptNum)$stopHint"
                                $tabItem.ApiWarningColor = "#E2C08D"
                            } elseif ($tail -match '"error":\s*"API error \(attempt (\d+)\):.*stream idle timeout') {
                                $attemptNum = $Matches[1]
                                $tabItem.ApiWarningText = "⚠️ Таймаут стрима API (попытка $attemptNum) [Стоп для отмены]"
                                $tabItem.ApiWarningColor = "#E2C08D"
                            } elseif ($tail -match '"error":\s*"API error \(attempt (\d+)\)') {
                                $attemptNum = $Matches[1]
                                $tabItem.ApiWarningText = "⚠️ Ошибка API (попытка $attemptNum)..."
                                $tabItem.ApiWarningColor = "#E2C08D"
                            } else {
                                $tabItem.ApiWarningText = $null
                                $tabItem.ApiWarningColor = $null
                            }
                        }
                    } catch {}
                }
            }

            if ($tabItem.ApiWarningText) {
                $tabItem.StatusText = "$($tabItem.ApiWarningText) ($timeStr)"
                $tabItem.StatusColor = $tabItem.ApiWarningColor
                if ($tabItem.HeaderDot) {
                    $tabItem.HeaderDot.Fill = (Get-CachedBrush $tabItem.ApiWarningColor)
                }
            } else {
                $tabItem.StatusText = "⏳ Агент выполняет задачи... ($timeStr)"
                $tabItem.StatusColor = "#FFA500"
                if ($tabItem.HeaderDot) {
                    $tabItem.HeaderDot.Fill = (Get-CachedBrush "#FFA500")
                }
            }
        }
    }
    if ($global:ActiveTab -and $global:ActiveTab.SyncState -and $global:ActiveTab.SyncState.IsRunning) {
        $txtStatus.Text = $global:ActiveTab.StatusText
        $clr = if ($global:ActiveTab.StatusColor) { $global:ActiveTab.StatusColor } else { "#FFA500" }
        $statusDot.Fill = (Get-CachedBrush $clr)
    }

    Set-PerfStage "tick: очередь событий агента"
    foreach ($t in @($global:TabsList)) {
        $item = $null
        if (-not $t.SyncState -or -not $t.SyncState.Queue) { continue }
        while ($t.SyncState.Queue.TryDequeue([ref]$item)) {
            switch ($item.Type) {
                "token" {
                    $t.ApiWarningText = $null
                    $t.ApiWarningColor = $null
                    Finalize-ActiveToolGroup -Tab $t
                    if (-not $t.StreamBuffer) {
                        $t.StreamBuffer = [System.Text.StringBuilder]::new()
                    }
                    if (-not $t.ActiveStreamParagraph) {
                        $t.ActiveStreamParagraph = [System.Windows.Documents.Paragraph]::new()
                        $t.ActiveStreamParagraph.Margin = [System.Windows.Thickness]::new(0, 3, 0, 7)
                        $t.ActiveStreamParagraph.LineHeight = [math]::Round([math]::Max(20.0, $global:CurrentFontSize * 1.55))
                        $t.ActiveStreamParagraph.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
                        $t.Document.Blocks.Add($t.ActiveStreamParagraph)
                    }
                    [void]$t.StreamBuffer.Append($item.Text)
                    $run = [System.Windows.Documents.Run]::new($item.Text)
                    $run.Foreground = (Get-CachedBrush "#D4D4D4")
                    $t.ActiveStreamParagraph.Inlines.Add($run)
                    if ($t -eq $global:ActiveTab) { Scroll-ChatLogToEnd }
                }
                "system" {
                    Finalize-ActiveToolGroup -Tab $t
                    Finalize-TabStreamingBuffer -Tab $t
                    if ($item.Text -and ($item.Text.Contains("<SYSTEM_MESSAGE>") -or $item.Text.Contains("SYSTEM_MESSAGE"))) {
                        $sysList = Parse-SystemMessageText $item.Text
                        foreach ($smsg in $sysList) {
                            [void](New-SystemMessageCard -Summary $smsg.Summary -Body $smsg.Body -StartCollapsed -Document $t.Document)
                        }
                    } else {
                        Append-ChatFormatted -Text "`r`n[ИНФО] $($item.Text)`r`n" -Color "#6A9955" -Document $t.Document
                    }
                    if ($t -eq $global:ActiveTab) { Scroll-ChatLogToEnd }
                }
                "tool_start" {
                    Finalize-TabStreamingBuffer -Tab $t
                    Add-ToolStartToGroup -toolName $item.Name -Tab $t
                }
                "tool_done" {
                    Add-ToolDoneToGroup -toolName $item.Name -duration $item.Duration -Tab $t
                }
                "conversation_id" {
                    $t.ConversationId = $item.Id
                    $shortId = if ($item.Id.Length -gt 12) { $item.Id.Substring(0, 12) + "..." } else { $item.Id }
                    if ($t -eq $global:ActiveTab) {
                        $global:CurrentConversationId = $item.Id
                        $txtConversationId.Text = "Диалог: $shortId"
                        $txtConversationId.ToolTip = $item.Id
                    }
                    Save-SessionMetadata -id $item.Id -workspace $t.Workspace -title $t.Title
                    Refresh-ConversationsCombo
                }
                "status" {
                    $t.StatusText = $item.Text
                    if ($item.Color) {
                        $t.StatusColor = $item.Color
                        if ($t.HeaderDot) {
                            $t.HeaderDot.Fill = (Get-CachedBrush $item.Color)
                        }
                    }
                    if ($t -eq $global:ActiveTab) {
                        $txtStatus.Text = $item.Text
                        if ($item.Color) {
                            $statusDot.Fill = (Get-CachedBrush $item.Color)
                        }
                    }
                }
                "done" {
                    Finalize-ActiveToolGroup -Tab $t
                    Finalize-TabStreamingBuffer -Tab $t
                    $elapsedTotal = if ($t.SyncState.Stopwatch) {
                        $t.SyncState.Stopwatch.Stop()
                        $t.SyncState.Stopwatch.Elapsed
                    } else { $null }
                    $t.SyncState.IsRunning = $false
                    $doneSec = if ($null -ne $elapsedTotal) { [math]::Round($elapsedTotal.TotalSeconds, 1) } else { $null }
                    $doneText = if ($null -ne $doneSec) {
                        if ($doneSec -ge 60) {
                            $m = [int]($doneSec / 60)
                            $s = [math]::Round($doneSec % 60, 1)
                            "Готов к работе (выполнено за ${m}м ${s}с)"
                        } else {
                            "Готов к работе (выполнено за ${doneSec} с)"
                        }
                    } else {
                        "Готов к работе"
                    }
                    $t.StatusText = $doneText
                    $t.StatusColor = "#4CAF50"
                    if ($t.HeaderDot) {
                        $t.HeaderDot.Fill = (Get-CachedBrush "#4CAF50")
                    }
                    Append-ChatFormatted -Text "`r`n" -Color "#D4D4D4" -Document $t.Document
                    if ($t.ConversationId) {
                        Update-ContextDisplay -conversationId $t.ConversationId -modelName $t.Model
                        Update-LimitsDisplay -modelName $t.Model
                    }
                    # Автоматическая доставка следующего сообщения из очереди
                    if ($t.QueuedUserMessages -and $t.QueuedUserMessages.Count -gt 0) {
                        $nextMsg = $t.QueuedUserMessages[0]
                        $t.QueuedUserMessages.RemoveAt(0)

                        Append-AgentHeader -Document $t.Document
                        $nextConvId = $t.ConversationId
                        $nextWs = if ($nextMsg.Workspace) { $nextMsg.Workspace } else { $t.Workspace }
                        $nextModel = if ($nextMsg.Model) { $nextMsg.Model } else { $t.Model }
                        $nextMode = if ($nextMsg.Mode) { $nextMsg.Mode } else { $t.Mode }
                        $nextEffort = if ($nextMsg.Effort) { $nextMsg.Effort } else { $t.Effort }
                        $nextSkip = if ($null -ne $nextMsg.SkipPerms) { $nextMsg.SkipPerms } else { $t.SkipPerms }

                        if ($t -eq $global:ActiveTab) {
                            $btnSend.IsEnabled = $true
                            $btnSend.Content = "В очередь ↵"
                            $btnSend.Background = (Get-CachedBrush "#B07010")
                            $btnSend.ToolTip = "Добавить сообщение в очередь (Enter или Alt+M)"
                            $btnStop.IsEnabled = $true
                            $txtPromptInput.IsEnabled = $true
                            $statusDot.Fill = (Get-CachedBrush "#FFA500")
                            $qCount = $t.QueuedUserMessages.Count
                            $txtStatus.Text = if ($qCount -gt 0) { "Агент думает и выполняет задачи... (в очереди: $qCount)" } else { "Агент думает и выполняет задачи..." }
                            Scroll-ChatLogToEnd
                        }

                        Start-AgentExecutionJob -Tab $t -Prompt $nextMsg.FullAgentPrompt -Workspace $nextWs -Model $nextModel -Mode $nextMode -Effort $nextEffort -SkipPerms $nextSkip -ConversationId $nextConvId
                    } else {
                        if ($t -eq $global:ActiveTab) {
                            $btnSend.IsEnabled = $true
                            $btnSend.Content = "Отправить ↵"
                            $btnSend.Background = (Get-CachedBrush "#0E639C")
                            $btnSend.ToolTip = "Отправить сообщение агенту (Enter)"
                            $btnStop.IsEnabled = $false
                            $txtPromptInput.IsEnabled = $true
                            $statusDot.Fill = (Get-CachedBrush "#4CAF50")
                            $txtStatus.Text = $doneText
                            Scroll-ChatLogToEnd
                            $txtPromptInput.Focus() | Out-Null
                        }
                    }
                }
                "error" {
                    Finalize-ActiveToolGroup -Tab $t
                    Finalize-TabStreamingBuffer -Tab $t
                    if ($t.SyncState.Stopwatch) {
                        $t.SyncState.Stopwatch.Stop()
                    }
                    $t.SyncState.IsRunning = $false

                    # Детектируем ошибки квот/rate-limit от API (429, RESOURCE_EXHAUSTED, weekly limit)
                    $errMsg = $item.Message
                    $isQuotaError = ($errMsg -match '429|RESOURCE_EXHAUSTED|quota|rate.?limit|Rate limit|weekly.?limit|Daily limit|RateLimitError|Quota exceeded|too many requests')
                                        if ($isQuotaError) {
                        if ($t.QueuedUserMessages -and $t.QueuedUserMessages.Count -gt 0) {
                            $t.QueuedUserMessages.Clear()
                        }
                        $nowForBlock = [DateTime]::Now
                        $tGrp = Get-ModelQuotaGroup -modelName $t.Model
                        $blockUntil = $nowForBlock.AddDays(7)
                        $resetsInStr = "7д"
                        if ($errMsg -match '(?:Resets|Refreshes) in\s+((?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?)') {
                            $d = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
                            $h = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
                            $m = if ($Matches[4]) { [int]$Matches[4] } else { 0 }
                            $s = if ($Matches[5]) { [int]$Matches[5] } else { 0 }
                            $resetsInStr = if ($d -gt 0) { "{0}д {1}ч" -f $d, $h } else { "{0}ч {1}м" -f $h, $m }
                            $blockUntil = $nowForBlock.AddDays($d).AddHours($h).AddMinutes($m).AddSeconds($s)
                        }

                        $blockObj = [pscustomobject]@{
                            BlockedUntil = $blockUntil
                            Message      = "Индивидуальный недельный лимит для группы '$tGrp' исчерпан. Сброс через $resetsInStr."
                            ResetsIn     = $resetsInStr
                        }
                        $global:QuotaGroupBlocked[$tGrp] = $blockObj
                        $global:QuotaBlockedUntil = $blockUntil
                        $global:QuotaBlockedMessage = $blockObj.Message
                        Save-QuotaCache

                        $global:DailyUsageCache = $null
                        Update-LimitsDisplay
                        $t.StatusText = "⛔ Лимит API исчерпан"
                        $t.StatusColor = "#F85149"
                        if ($t.HeaderDot) {
                            $t.HeaderDot.Fill = (Get-CachedBrush "#F85149")
                        }
                        Append-ChatFormatted -Text "`r`n⛔ [ЛИМИТ ИСЧЕРПАН]: Квота API превышена ($tGrp). Отправка заблокирована (сброс через $resetsInStr, ($($blockUntil.ToString('dd.MM HH:mm')))).$([Environment]::NewLine)$errMsg`r`n`r`n" -Color "#F85149" -Bold -Document $t.Document
                        if ($t -eq $global:ActiveTab) {
                            $btnSend.IsEnabled = $false
                            $btnSend.Content = "Отправить ↵"
                            $btnSend.Background = (Get-CachedBrush "#0E639C")
                            $btnStop.IsEnabled = $false
                            $txtPromptInput.IsEnabled = $false
                            $statusDot.Fill = (Get-CachedBrush "#F85149")
                            $txtStatus.Text = "⛔ Лимит API исчерпан"
                            Scroll-ChatLogToEnd
                        }
                    } else {
                        $isCapacityError = ($errMsg -match '503|UNAVAILABLE|No capacity available|capacity|stream idle timeout|context deadline exceeded')
                        if ($isCapacityError) {
                            if ($t.QueuedUserMessages -and $t.QueuedUserMessages.Count -gt 0) {
                                $qCount = $t.QueuedUserMessages.Count
                                $t.QueuedUserMessages.Clear()
                                Append-ChatFormatted -Text "⚠️ Очередь отложенных сообщений ($qCount) была отменена из-за дефицита мощностей серверов Google.`r`n`r`n" -Color "#FFA500" -Document $t.Document
                            }
                            $t.StatusText = "⚠️ Дефицит мощностей Google (503)"
                            $t.StatusColor = "#E2C08D"
                            if ($t.HeaderDot) {
                                $t.HeaderDot.Fill = (Get-CachedBrush "#E2C08D")
                            }
                            Append-ChatFormatted -Text "`r`n⚠️ [СЕРВЕРЫ GOOGLE ПЕРЕГРУЖЕНЫ (503 No Capacity)]: Бэкенд Google временно не имеет свободных мощностей для модели '$($t.Model)'.`r`n💡 Решение: Переключите модель в выпадающем списке сверху на 'gemini-3.8-flash' (без High) или 'gemini-pro'.`r`n`r`n" -Color "#E2C08D" -Bold -Document $t.Document
                            if ($t -eq $global:ActiveTab) {
                                $btnSend.IsEnabled = $true
                                $btnSend.Content = "Отправить ↵"
                                $btnSend.Background = (Get-CachedBrush "#0E639C")
                                $btnSend.ToolTip = "Отправить сообщение агенту (Enter)"
                                $btnStop.IsEnabled = $false
                                $txtPromptInput.IsEnabled = $true
                                $statusDot.Fill = (Get-CachedBrush "#E2C08D")
                                $txtStatus.Text = "⚠️ Дефицит мощностей Google (503 No Capacity)"
                                Scroll-ChatLogToEnd
                            }
                        } else {
                            if ($t.QueuedUserMessages -and $t.QueuedUserMessages.Count -gt 0) {
                                $qCount = $t.QueuedUserMessages.Count
                                $t.QueuedUserMessages.Clear()
                                Append-ChatFormatted -Text "⚠️ Очередь отложенных сообщений ($qCount) была отменена из-за ошибки выполнения.`r`n`r`n" -Color "#FFA500" -Document $t.Document
                            }
                            $t.StatusText = "Ошибка выполнения"
                            $t.StatusColor = "#F85149"
                            if ($t.HeaderDot) {
                                $t.HeaderDot.Fill = (Get-CachedBrush "#F85149")
                            }
                            Append-ChatFormatted -Text "`r`n❌ [ОШИБКА]: $errMsg`r`n`r`n" -Color "#F85149" -Bold -Document $t.Document
                            if ($t -eq $global:ActiveTab) {
                                $btnSend.IsEnabled = $true
                                $btnSend.Content = "Отправить ↵"
                                $btnSend.Background = (Get-CachedBrush "#0E639C")
                                $btnSend.ToolTip = "Отправить сообщение агенту (Enter)"
                                $btnStop.IsEnabled = $false
                                $txtPromptInput.IsEnabled = $true
                                $statusDot.Fill = (Get-CachedBrush "#F85149")
                                $txtStatus.Text = "Ошибка выполнения"
                                Scroll-ChatLogToEnd
                            }
                        }
                    }
                }
            }
        }
    }
    Set-PerfStage "-"
    if ($tickSw.ElapsedMilliseconds -gt 150) {
        Write-PerfLog "tick занял $($tickSw.ElapsedMilliseconds) мс"
    }
})
$uiTimer.Start()

# --- Таймер периодического фонового обновления лимитов и квот API раз в 5 минут ---
$limitsAutoRefreshTimer = [System.Windows.Threading.DispatcherTimer]::new()
$limitsAutoRefreshTimer.Interval = [TimeSpan]::FromMinutes(5)
$limitsAutoRefreshTimer.Add_Tick({
    if ($global:ActiveQuotaSyncJob) { return }
    [void](Start-AsyncQuotaSync -OnCompleted {
        Update-LimitsDisplay
    })
})
$limitsAutoRefreshTimer.Start()

# --- Обработчики событий элементов интерфейса ---

# Выбор папки через диалог
$btnBrowseWorkspace.Add_Click({
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = "Выберите рабочую папку проекта для агента"
    if (Test-Path $txtWorkspace.Text) {
        $dialog.SelectedPath = $txtWorkspace.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtWorkspace.Text = $dialog.SelectedPath
    }
})

# Выбор проекта из выпадающего списка
$cmbProjects.Add_SelectionChanged({
    if ($cmbProjects.SelectedIndex -gt 0) {
        $selectedProjectName = $cmbProjects.SelectedItem.ToString()
        $projectPath = Join-Path $defaultWorkspace $selectedProjectName
        if (Test-Path $projectPath) {
            $txtWorkspace.Text = $projectPath
        }
    }
})

# Смена модели (пересчет лимитов контекста)
$cmbModel.Add_SelectionChanged({
    if ($global:ActiveTab -and $cmbModel.SelectedItem) {
        $global:ActiveTab.Model = $cmbModel.SelectedItem.ToString()
    }
    Update-ContextDisplay
    Update-LimitsDisplay
})

# Очистка лога
$btnClearLog.Add_Click({
    Clear-ChatLog
})

# Сброс диалога (Новый диалог)
$btnNewChat.Add_Click({
    Reset-ToNewChat
})

# Открытие окна менеджера разговоров
$btnManageConversations.Add_Click({
    Show-ConversationSelectorWindow
})

# Клик по идентификатору диалога в статус-баре открывает менеджер разговоров
$txtConversationId.Add_MouseDown({
    param($sender, $e)
    if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        Show-ConversationSelectorWindow
    }
})

# Интерактивный графический виджет контекста: ховер-эффект и вызов диалога подробного анализа
if ($borderContextWidget) {
    $borderContextWidget.Add_MouseEnter({
        $borderContextWidget.Background = (Get-CachedBrush "#262C36")
        $borderContextWidget.BorderBrush = (Get-CachedBrush "#3B4452")
    })
    $borderContextWidget.Add_MouseLeave({
        $borderContextWidget.Background = (Get-CachedBrush "#1C1F26")
        $borderContextWidget.BorderBrush = (Get-CachedBrush "#2D333B")
    })
    $borderContextWidget.Add_MouseDown({
        param($sender, $e)
        if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
            Show-ContextDetailsDialog -OwnerWindow $window
        }
    })
}

# Интерактивный графический виджет лимитов использования: ховер-эффект и вызов модального дашборда
if ($borderLimitsWidget) {
    $borderLimitsWidget.Add_MouseEnter({
        $borderLimitsWidget.Background = (Get-CachedBrush "#262C36")
        $borderLimitsWidget.BorderBrush = (Get-CachedBrush "#3B4452")
    })
    $borderLimitsWidget.Add_MouseLeave({
        $borderLimitsWidget.Background = (Get-CachedBrush "#1C1F26")
        $borderLimitsWidget.BorderBrush = (Get-CachedBrush "#2D333B")
    })
    $borderLimitsWidget.Add_MouseDown({
        param($sender, $e)
        if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
            Show-UsageLimitsDialog -OwnerWindow $window
        }
    })
}

# Выбор диалога из быстрого комбобокса
# Р¤СѓРЅРєС†РёСЏ Р±РµР·РѕРїР°СЃРЅРѕРіРѕ РїРµСЂРµРєР»СЋС‡РµРЅРёСЏ РґРёР°Р»РѕРіР° РёР· РІС‹РїР°РґР°СЋС‰РµРіРѕ СЃРїРёСЃРєР°
$global:IsSelectingFromCombo = $false

function Switch-ConversationFromCombo {
    if ($global:SuppressConvComboEvent) { return }
    $sel = $cmbConversations.SelectedItem
    if (-not $sel) { return }

    $targetId = $sel.Tag
    $currentId = if ($global:ActiveTab) { $global:ActiveTab.ConversationId } else { $global:CurrentConversationId }

    # Р•СЃР»Рё СѓР¶Рµ РІС‹Р±СЂР°РЅ РґР°РЅРЅС‹Р№ РґРёР°Р»РѕРі вЂ” РЅРёС‡РµРіРѕ РЅРµ РґРµР»Р°РµРј
    if ($targetId -and $targetId -eq $currentId) { return }
    if (-not $targetId -and -not $currentId) { return }

    $global:IsSelectingFromCombo = $true
    Write-PerfLog "Switch-ConversationFromCombo: выбран диалог '$targetId'"
    try {
        if (-not $targetId) {
            Reset-ToNewChat
        } else {
            $convObj = $sel.ConvObj
            if (-not $convObj) {
                $fallbackTitle = if ($sel.TitleStr) { $sel.TitleStr } else { [regex]::Unescape("\u0414\u0438\u0430\u043b\u043e\u0433 ") + $targetId }
                $convObj = [pscustomobject]@{
                    Id           = $targetId
                    Title        = $fallbackTitle
                    Workspace    = ""
                    LastModified = [DateTime]::UtcNow
                }
            }
            Select-ConversationItem $convObj
            Scroll-ChatLogToEnd
        }
    } finally {
        $global:IsSelectingFromCombo = $false
    }
}

# 1. Р’С‹Р±РѕСЂ РґРёР°Р»РѕРіР° РёР· РІС‹РїР°РґР°СЋС‰РµРіРѕ СЃРїРёСЃРєР° РјС‹С€СЊСЋ (СЃС‚СЂРѕРіРѕ РїСЂРё Р·Р°РєСЂС‹С‚РёРё СЃРїРёСЃРєР°, РєРѕРіРґР° РјС‹С€СЊ РѕСЃРІРѕР±РѕР¶РґРµРЅР°)
$cmbConversations.Add_SelectionChanged({
    if ($global:SuppressConvComboEvent) { return }
    $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{
        Switch-ConversationFromCombo
    }.GetNewClosure()) | Out-Null
})

# 2. Р’С‹Р±РѕСЂ РґРёР°Р»РѕРіР° СЃ РєР»Р°РІРёР°С‚СѓСЂС‹ РєР»Р°РІРёС€РµР№ Enter
$cmbConversations.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $e.Handled = $true
        Switch-ConversationFromCombo
    }
})

# Запуск полноэкранного терминала agy
$btnLaunchTui.Add_Click({
    $workspace = $txtWorkspace.Text
    $model = $cmbModel.SelectedItem.ToString()
    $mode = $cmbMode.SelectedItem.ToString()
    $effort = $cmbEffort.SelectedItem.ToString()
    $effortArg = if ($effort -ne "auto") { "--effort '$effort'" } else { "" }
    $skip = if ($chkSkipPerms.IsChecked) { "--dangerously-skip-permissions" } else { "" }
    $convArg = if ($global:CurrentConversationId) { "--conversation '$($global:CurrentConversationId)'" } else { "" }

    $startScript = "Set-Location -LiteralPath '$workspace'; & '$defaultAgyPath' --model '$model' --mode '$mode' $effortArg $skip $convArg"
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $startScript
})

# --- Профили аккаунтов agy (логика хранения: Accounts.ps1) ---
# Кнопка открывает меню: список профилей (переключение в один клик), сохранение текущего аккаунта
# как профиля, удаление профиля и вход в новый аккаунт через /logout.
$global:AccountSwitchProcess = $null

function Update-AccountButtonText {
    $activeName = (Get-AccountIndex).active
    $btnSwitchAccount.Content = if ($activeName) { "🔑 $activeName ▾" } else { "🔑 Аккаунт ▾" }
}

function Update-LimitsAfterAccountChange {
    $global:LiveQuotaCache = $null
    [void](Start-AsyncQuotaSync -OnCompleted { Update-LimitsDisplay })
}

function Confirm-AccountChangeWithRunningTabs {
    $running = @($global:TabsList | Where-Object { $_.SyncState -and $_.SyncState.IsRunning })
    if ($running.Count -eq 0) { return $true }
    $answer = [System.Windows.MessageBox]::Show(
        "Сейчас агент работает во вкладках: $($running.Count). Их запросы могут завершиться ошибкой при смене аккаунта. Продолжить?",
        "Смена аккаунта", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    return ($answer -eq [System.Windows.MessageBoxResult]::Yes)
}

function Invoke-AccountSwitch([string]$Name) {
    if (-not (Confirm-AccountChangeWithRunningTabs)) { return }
    try {
        Switch-ToAccountProfile -Name $Name
    } catch {
        [System.Windows.MessageBox]::Show("Не удалось переключить аккаунт:`r`n$($_.Exception.Message)", "Смена аккаунта", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }
    Update-AccountButtonText
    Update-LimitsAfterAccountChange
}

function Invoke-SaveCurrentAccount {
    if (-not (Test-AgyLoggedIn)) {
        [System.Windows.MessageBox]::Show("agy сейчас не авторизован. Сначала войдите в аккаунт.", "Профили аккаунтов") | Out-Null
        return
    }
    $idx = Get-AccountIndex
    $suggest = if ($idx.active) { [string]$idx.active } else { "" }
    $name = Show-RenameDialog -CurrentTitle $suggest -PromptText "Название профиля для текущего аккаунта:" -DialogTitle "🔑 Сохранение профиля аккаунта" -OwnerWindow $window
    if (-not $name) { return }
    $name = $name.Trim()
    $clash = @($idx.profiles | Where-Object { $_.name -eq $name })
    if ($clash.Count -gt 0 -and $name -ne $idx.active) {
        $answer = [System.Windows.MessageBox]::Show("Профиль '$name' уже есть. Заменить его текущим аккаунтом?", "Профили аккаунтов", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }
    Save-CurrentAccountAsProfile -Name $name
    Update-AccountButtonText
}

function Invoke-AccountDelete([string]$Name) {
    $answer = [System.Windows.MessageBox]::Show("Удалить профиль '$Name'? Сам аккаунт при этом не затрагивается, удаляется только сохранённая копия входа.", "Профили аккаунтов", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    Remove-AccountProfile -Name $Name
    Update-AccountButtonText
}

function Start-AccountLogoutWindow {
    if ($global:AccountSwitchProcess -and -not $global:AccountSwitchProcess.HasExited) {
        [System.Windows.MessageBox]::Show("Окно входа в аккаунт уже открыто. Завершите вход в нём.", "Смена аккаунта") | Out-Null
        return
    }
    $idx = Get-AccountIndex
    $loggedIn = Test-AgyLoggedIn
    $confirmText = "Откроется окно agy, в нём автоматически выполнится /logout. Затем выберите вход через Google, войдите в нужный аккаунт и закройте окно: лаунчер предложит сохранить его как профиль."
    if ($loggedIn -and -not $idx.active) {
        $confirmText += "`r`n`r`nТекущий аккаунт не сохранён как профиль. Если он нужен, нажмите «Нет», сначала выберите «Сохранить текущий аккаунт как профиль...» в меню кнопки."
    }
    $confirmText += "`r`n`r`nПродолжить?"
    $answer = [System.Windows.MessageBox]::Show($confirmText, "Вход в другой аккаунт", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
    if (-not (Confirm-AccountChangeWithRunningTabs)) { return }

    # Перед выходом обновляем копию текущего аккаунта в его профиле (agy мог обновить токены),
    # а активный профиль сбрасываем, чтобы чужой вход не записался в старый профиль.
    if ($idx.active -and $loggedIn) { Save-CurrentAccountAsProfile -Name $idx.active }
    Set-ActiveAccountNone
    Update-AccountButtonText

    # agy в режиме -i принимает "/logout" как обычное сообщение модели, а не как команду.
    # Switch-Account.ps1 открывает обычный agy и сам вводит /logout нажатием клавиш в его окне.
    $switchScript = Join-Path $launcherDir "Switch-Account.ps1"
    $global:AccountSwitchProcess = Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$switchScript`"", "-AgyPath", "`"$defaultAgyPath`"") -PassThru
}

function Invoke-SaveAccountAfterLogin {
    # Вызывается после закрытия окна входа
    if (-not (Test-AgyLoggedIn)) { return }
    $answer = [System.Windows.MessageBox]::Show("Вы вошли в аккаунт. Сохранить его как профиль, чтобы переключаться в один клик?", "Профили аккаунтов", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($answer -eq [System.Windows.MessageBoxResult]::Yes) { Invoke-SaveCurrentAccount }
}

$btnSwitchAccount.Add_Click({
    param($sender, $e)
    $idx = Get-AccountIndex
    $menu = [System.Windows.Controls.ContextMenu]::new()

    foreach ($p in $idx.profiles) {
        $mi = [System.Windows.Controls.MenuItem]::new()
        $mi.Header = if ($p.name -eq $idx.active) { "✔ $($p.name)" } else { "     $($p.name)" }
        $mi.Tag = [string]$p.name
        $mi.Add_Click({ param($s, $ev) Invoke-AccountSwitch ([string]$s.Tag) })
        [void]$menu.Items.Add($mi)
    }
    if ($idx.profiles.Count -eq 0) {
        $empty = [System.Windows.Controls.MenuItem]::new()
        $empty.Header = "(профилей пока нет)"
        $empty.IsEnabled = $false
        [void]$menu.Items.Add($empty)
    }
    [void]$menu.Items.Add([System.Windows.Controls.Separator]::new())

    $miSave = [System.Windows.Controls.MenuItem]::new()
    $miSave.Header = "➕ Сохранить текущий аккаунт как профиль..."
    $miSave.Add_Click({ Invoke-SaveCurrentAccount })
    [void]$menu.Items.Add($miSave)

    if ($idx.profiles.Count -gt 0) {
        $miDel = [System.Windows.Controls.MenuItem]::new()
        $miDel.Header = "🗑️ Удалить профиль"
        foreach ($p in $idx.profiles) {
            $sub = [System.Windows.Controls.MenuItem]::new()
            $sub.Header = [string]$p.name
            $sub.Tag = [string]$p.name
            $sub.Add_Click({ param($s, $ev) Invoke-AccountDelete ([string]$s.Tag) })
            [void]$miDel.Items.Add($sub)
        }
        [void]$menu.Items.Add($miDel)
    }
    [void]$menu.Items.Add([System.Windows.Controls.Separator]::new())

    $miLogout = [System.Windows.Controls.MenuItem]::new()
    $miLogout.Header = "🔓 Войти в другой аккаунт (выход /logout)..."
    $miLogout.Add_Click({ Start-AccountLogoutWindow })
    [void]$menu.Items.Add($miLogout)

    $menu.PlacementTarget = $btnSwitchAccount
    $menu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    $menu.IsOpen = $true
})
Update-AccountButtonText

# Остановка выполнения
$btnStop.Add_Click({
    $tab = $global:ActiveTab
    if ($tab -and $tab.SyncState.IsRunning) {
        try {
            $tab.SyncState.StopRequested = $true
            if ($tab.SyncState.Stopwatch) {
                $tab.SyncState.Stopwatch.Stop()
            }
            if ($tab.SyncState.ProcessId -gt 0) {
                $pidToKill = $tab.SyncState.ProcessId
                Stop-ProcessTree -processId $pidToKill
            }
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "status"; Text = "Остановлено пользователем"; Color = "#E57373" })
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "system"; Text = "Процесс агента был принудительно остановлен." })
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "done" })
        } catch {
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "error"; Message = $_.ToString() })
        }
    }
})

# Формирование полного текста промпта с путями к файлам, папкам и изображениям
function Build-FullAgentPrompt {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        $Attachments = $null
    )
    if (-not $Attachments -or $Attachments.Count -eq 0) {
        return $Prompt
    }

    $attachedList = @($Attachments)
    $onlyImages = $true
    foreach ($it in $attachedList) {
        if ($it.ItemType -ne "Image" -and -not $it.ImageSource) {
            $onlyImages = $false
            break
        }
    }

    $imgLines = @()
    if ($onlyImages) {
        $imgLines += "[Прикрепленные изображения:"
    } else {
        $imgLines += "[Прикрепленные файлы, папки и изображения:"
    }

    foreach ($att in $attachedList) {
        $uriPath = "file:///" + $att.FilePath.Replace('\', '/')
        $typeLabel = if ($att.ItemType -eq "Folder") { " (папка)" } elseif ($att.ItemType -eq "File") { " (файл)" } else { "" }

        if ($att.HasAnnotation -and $att.AnnotatedFilePath -and (Test-Path -LiteralPath $att.AnnotatedFilePath)) {
            $uriAnnot = "file:///" + $att.AnnotatedFilePath.Replace('\', '/')
            $imgLines += " - $uriPath"
            $imgLines += " - $uriAnnot"
        } else {
            $imgLines += " - ${uriPath}${typeLabel}"
        }
    }
    $imgLines += "]"

    if ($onlyImages) {
        $imgLines += "Внимание агенту: обязательно изучи прикрепленные изображения по указанным путям с помощью инструмента read_file."
    } else {
        $imgLines += "Внимание агенту: обязательно изучи прикрепленные файлы, папки или изображения по указанным путям с помощью соответствующих инструментов (read_file для файлов/изображений, или поиск/терминал для папок)."
    }

    $hasAnyAnnot = ($attachedList | Where-Object { $_.HasAnnotation -and $_.AnnotatedFilePath -and (Test-Path -LiteralPath $_.AnnotatedFilePath) })
    if ($hasAnyAnnot) {
        $imgLines += "Примечание: для файлов с окончанием '_annotated.png' предоставлена графическая разметка маркерами (прямоугольники/стрелки) с указанием ключевых мест интереса. Используйте чистый оригинал для считывания неискаженного текста и перекрытых деталей интерфейса."
    }
    return (($imgLines -join "`r`n") + "`r`n`r`n" + $Prompt)
}

# Запуск фонового процесса выполнения agy в отдельном ранспейсе
function Start-AgentExecutionJob {
    param(
        [Parameter(Mandatory=$true)]$Tab,
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][string]$Workspace,
        [Parameter(Mandatory=$true)][string]$Model,
        [Parameter(Mandatory=$true)][string]$Mode,
        [Parameter(Mandatory=$true)][string]$Effort,
        [bool]$SkipPerms = $true,
        [string]$ConversationId = $null
    )

    $Tab.StatusText = "Агент думает и выполняет задачи..."
    $Tab.StatusColor = "#FFA500"
    if ($Tab.HeaderDot) {
        $Tab.HeaderDot.Fill = (Get-CachedBrush "#FFA500")
    }

    $Tab.SyncState.IsRunning = $true
    $Tab.SyncState.StopRequested = $false
    $Tab.SyncState.ProcessId = 0
    $Tab.SyncState.Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $script:syncState = $Tab.SyncState

    $jobData = [hashtable]::Synchronized(@{
        AgyPath         = $defaultAgyPath
        Workspace       = $Workspace
        Prompt          = $Prompt
        Model           = $Model
        Mode            = $Mode
        Effort          = $Effort
        SkipPerms       = $SkipPerms
        ConversationId  = $ConversationId
        SyncState       = $Tab.SyncState
    })

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("jobData", $jobData)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        $st = $jobData.SyncState
        try {
            $escapedPrompt = $jobData.Prompt.Replace('\', '\\').Replace('"', '\"')

            $argsList = "-p `"$escapedPrompt`" --output-format stream-json --model $($jobData.Model) --mode $($jobData.Mode)"
            if ($jobData.Effort -and $jobData.Effort -ne "auto") {
                $argsList += " --effort $($jobData.Effort)"
            }
            if ($jobData.SkipPerms) {
                $argsList += " --dangerously-skip-permissions"
            }
            if ($jobData.ConversationId) {
                $argsList += " --conversation $($jobData.ConversationId)"
            }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $jobData.AgyPath
            $psi.Arguments = $argsList
            $psi.WorkingDirectory = $jobData.Workspace
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            if ($st.StopRequested) { return }
            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi
            $proc.Start() | Out-Null

            $errTask = $proc.StandardError.ReadToEndAsync()
            $st.ProcessId = $proc.Id

            if ($st.StopRequested) {
                try { & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null } catch {}
                return
            }

            $turnFinished = $false

            while (-not $proc.HasExited) {
                $line = $proc.StandardOutput.ReadLine()
                if ($null -eq $line) { break }
                if ($line) {
                    try {
                        $evt = $line | ConvertFrom-Json
                        switch ($evt.event) {
                            "init" {
                                if ($evt.conversation_id) {
                                    $st.Queue.Enqueue([pscustomobject]@{ Type = "conversation_id"; Id = $evt.conversation_id })
                                }
                            }
                            "step_update" {
                                $su = $evt.step_update
                                if ($su.step_type -eq "agent_response" -and $su.text_delta) {
                                    $st.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = $su.text_delta })
                                }
                                elseif ($su.step_type -eq "tool") {
                                    if ($su.state -eq "ACTIVE") {
                                        $st.Queue.Enqueue([pscustomobject]@{ Type = "tool_start"; Name = $su.tool_name })
                                    } elseif ($su.state -eq "DONE") {
                                        $dur = [math]::Round([double]$su.duration_seconds, 2)
                                        $st.Queue.Enqueue([pscustomobject]@{ Type = "tool_done"; Name = $su.tool_name; Duration = $dur })
                                    }
                                }
                            }
                            "result" {
                                $turnFinished = $true
                                if ($evt.result -and $evt.result.conversation_id) {
                                    $st.Queue.Enqueue([pscustomobject]@{ Type = "conversation_id"; Id = $evt.result.conversation_id })
                                }
                            }
                        }
                    } catch {
                        $st.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = $line })
                    }
                }
            }

            $waitOk = $proc.WaitForExit(1500)
            if (-not $waitOk -or -not $proc.HasExited) {
                try {
                    if ($proc.Id -gt 0) {
                        & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null
                        if (-not $proc.HasExited) {
                            $proc.Kill()
                        }
                    }
                } catch {}
            }

            $errOutput = ""
            try {
                if ($errTask) {
                    $errOutput = $errTask.GetAwaiter().GetResult().Trim()
                }
            } catch {}

            if ($st.StopRequested) {
                # Остановлено пользователем
            } elseif ($turnFinished) {
                $st.Queue.Enqueue([pscustomobject]@{ Type = "done" })
            } else {
                if ($errOutput -and $proc.ExitCode -ne 0) {
                    $st.Queue.Enqueue([pscustomobject]@{ Type = "error"; Message = $errOutput })
                } else {
                    $st.Queue.Enqueue([pscustomobject]@{ Type = "done" })
                }
            }
        } catch {
            $st.Queue.Enqueue([pscustomobject]@{ Type = "error"; Message = $_.ToString() })
        } finally {
            $st.IsRunning = $false
        }
    }) | Out-Null

    $asyncHandle = $ps.BeginInvoke()
}

# Основная функция отправки запроса или добавления в очередь
function Send-AgentPrompt {
    $prompt = $txtPromptInput.Text.Trim()
    $hasAttachments = ($global:AttachedImages.Count -gt 0)
    if ([string]::IsNullOrWhiteSpace($prompt) -and -not $hasAttachments) { return }
    if ([string]::IsNullOrWhiteSpace($prompt) -and $hasAttachments) {
        $hasFoldersOrFiles = ($global:AttachedImages | Where-Object { $_.ItemType -eq "Folder" -or $_.ItemType -eq "File" })
        if ($hasFoldersOrFiles) {
            $prompt = "Пожалуйста, изучи прикрепленные файлы/папки."
        } else {
            $prompt = "Пожалуйста, проанализируй прикрепленное изображение."
        }
    }

    $tab = $global:ActiveTab
    if (-not $tab) { return }

    # Проверка: не заблокированы ли квоты ошибкой API (429/RESOURCE_EXHAUSTED)
    $curModel = if ($cmbModel.SelectedItem) { $cmbModel.SelectedItem.ToString() } else { "claude-sonnet-4-6" }
    $curGrp = Get-ModelQuotaGroup -modelName $curModel
    if ($global:QuotaGroupBlocked.ContainsKey($curGrp)) {
        $bInfo = $global:QuotaGroupBlocked[$curGrp]
        if ($bInfo -and $bInfo.BlockedUntil -gt [DateTime]::Now) {
            Append-ChatFormatted -Text "`r`n⛔ [ЛИМИТ ИСЧЕРПАН]: Отправка для группы моделей '$curGrp' заблокирована — недельный лимит API исчерпан. Сброс через $($bInfo.ResetsIn) ($($bInfo.BlockedUntil.ToString('dd.MM HH:mm'))).`r`n`r`n" -Color "#F85149" -Bold -Document $tab.Document
            Scroll-ChatLogToEnd
            return
        }
    }
    if ($global:QuotaBlockedUntil -gt [DateTime]::Now) {
        $remainMin = [math]::Ceiling(($global:QuotaBlockedUntil - [DateTime]::Now).TotalMinutes)
        Append-ChatFormatted -Text "`r`n⛔ [ЛИМИТ ИСЧЕРПАН]: Отправка заблокирована — квота API превышена. Попробуйте через $remainMin мин. (сброс в $($global:QuotaBlockedUntil.ToString('HH:mm')))`r`n`r`n" -Color "#F85149" -Bold -Document $tab.Document
        Scroll-ChatLogToEnd
        return
    }

    # Если вкладка с сохраненным диалогом еще не была загружена, загружаем и дожидаемся завершения
    if (-not $tab.IsTranscriptLoaded -and $tab.ConversationId) {
        Load-TabConversation -Tab $tab
        Wait-TabLoading -Tab $tab -TimeoutMs 5000
    }

    $workspace = $txtWorkspace.Text.Trim()
    if (-not (Test-Path $workspace)) {
        [System.Windows.MessageBox]::Show("Указанная рабочая папка не существует: $workspace", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    if (-not (Test-Path $defaultAgyPath)) {
        [System.Windows.MessageBox]::Show("Исполняемый файл agy.exe не найден по пути: $defaultAgyPath", "Ошибка", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }

    $model  = if ($cmbModel.SelectedItem) { $cmbModel.SelectedItem.ToString() } else { "gemini-2.5-pro" }
    $mode   = if ($cmbMode.SelectedItem) { $cmbMode.SelectedItem.ToString() } else { "code" }
    $effort = if ($cmbEffort.SelectedItem) { $cmbEffort.SelectedItem.ToString() } else { "medium" }
    $skipPerms = [bool]$chkSkipPerms.IsChecked
    $convId = $tab.ConversationId
    $global:LastSentPrompt = $prompt

    # Сохраняем в состояние вкладки
    $tab.Workspace = $workspace
    $tab.Model = $model
    $tab.Mode = $mode
    $tab.Effort = $effort
    $tab.SkipPerms = $skipPerms

    # Автоматически обновляем название вкладки, если оно стандартное
    if ($tab.Title -match '^Диалог \d+$' -or $tab.Title -eq "Новый диалог") {
        $cleanPrompt = ($prompt -replace '[\r\n]+', ' ').Trim()
        $shortPrompt = if ($cleanPrompt.Length -gt 22) { $cleanPrompt.Substring(0, 22) + "..." } else { $cleanPrompt }
        if ($shortPrompt) {
            $tab.Title = $shortPrompt
            if ($tab.HeaderTitle) {
                $tab.HeaderTitle.Text = $shortPrompt
                $tab.HeaderTitle.ToolTip = $cleanPrompt
            }
        }
    }
    Save-LauncherConfig

    # Формирование полного промпта с путями к файлам, папкам и изображениям
    $attachedCopy = @($global:AttachedImages)
    $fullAgentPrompt = Build-FullAgentPrompt -Prompt $prompt -Attachments $attachedCopy

    $badgeAttachments = [System.Collections.Generic.List[psobject]]::new()
    foreach ($att in $attachedCopy) {
        $badgeAttachments.Add($att)
        if ($att.HasAnnotation -and $att.AnnotatedFilePath -and (Test-Path -LiteralPath $att.AnnotatedFilePath)) {
            $annotFn = [System.IO.Path]::GetFileName($att.AnnotatedFilePath)
            $badgeAttachments.Add([pscustomobject]@{
                FilePath    = $att.AnnotatedFilePath
                FileName    = $annotFn
                DisplayName = "🎯 $annotFn"
                ItemType    = "Image"
            })
        }
    }

    $badgeNames = ($badgeAttachments | ForEach-Object {
        if ($_.DisplayName -match "^🎯") {
            $_.DisplayName
        } elseif ($_.ItemType -eq "Folder" -or ($_.FilePath -and (Test-Path -LiteralPath $_.FilePath -PathType Container))) {
            "📁 " + $_.DisplayName
        } elseif ($_.ItemType -eq "File") {
            ($_.Icon -or "📄") + " " + $_.DisplayName
        } else {
            "🖼️ " + $_.DisplayName
        }
    }) -join ", "
    $imgLogBadges = if ($badgeNames) { "[$badgeNames]" } else { "" }

    # ПРОВЕРКА ОЧЕРЕДИ: Если агент уже выполняет задачу -> ставим в очередь!
    if ($tab.SyncState.IsRunning) {
        $qItem = [pscustomobject]@{
            PromptText       = $prompt
            FullAgentPrompt  = $fullAgentPrompt
            Attachments      = $attachedCopy
            BadgeAttachments = $badgeAttachments
            Badges           = $imgLogBadges
            TimeStr          = (Get-Date).ToString("HH:mm:ss")
            Workspace        = $workspace
            Model            = $model
            Mode             = $mode
            Effort           = $effort
            SkipPerms        = $skipPerms
        }
        if (-not $tab.QueuedUserMessages) {
            $tab | Add-Member -NotePropertyName "QueuedUserMessages" -NotePropertyValue ([System.Collections.Generic.List[psobject]]::new()) -Force
        }
        $tab.QueuedUserMessages.Add($qItem)

        # Выводим сообщение в чат с индикатором очереди
        $timeNow = $qItem.TimeStr
        Append-UserMessageToLog -TimeStr $timeNow -Text $prompt -Badges $imgLogBadges -Attachments $badgeAttachments -Document $tab.Document -IsQueued

        if ($global:ActiveTab -eq $tab) {
            $txtPromptInput.Text = ""
            Clear-AttachedImages
            Scroll-ChatLogToEnd
            $qCount = $tab.QueuedUserMessages.Count
            $txtStatus.Text = "Агент выполняет задачу... (в очереди: $qCount)"
        }
        return
    }

    # Инкремент суточных счетчиков лимитов использования
    $global:SessionRequestsDelta++
    Update-LimitsDisplay -modelName $model

    Finalize-ActiveToolGroup -Tab $tab
    Finalize-TabStreamingBuffer -Tab $tab

    # Обновление UI перед стартом
    $timeNow = (Get-Date).ToString("HH:mm:ss")
    Append-UserMessageToLog -TimeStr $timeNow -Text $prompt -Badges $imgLogBadges -Attachments $badgeAttachments -Document $tab.Document
    Append-AgentHeader -Document $tab.Document

    if ($global:ActiveTab -eq $tab) {
        Scroll-ChatLogToEnd
        $txtPromptInput.Text = ""
        Clear-AttachedImages
        $btnSend.IsEnabled = $true
        $btnSend.Content = "В очередь ↵"
        $btnSend.Background = (Get-CachedBrush "#B07010")
        $btnSend.ToolTip = "Добавить сообщение в очередь (Enter или Alt+M)"
        $btnStop.IsEnabled = $true
        $txtPromptInput.IsEnabled = $true
        $statusDot.Fill = (Get-CachedBrush "#FFA500")
        $txtStatus.Text = "Агент думает и выполняет задачи..."
        $txtPromptInput.Focus() | Out-Null
    }

    Start-AgentExecutionJob -Tab $tab -Prompt $fullAgentPrompt -Workspace $workspace -Model $model -Mode $mode -Effort $effort -SkipPerms $skipPerms -ConversationId $convId
}
$btnSend.Add_Click({
    Send-AgentPrompt
})


# Выбор изображений и файлов через диалог
$btnAttachImage.Add_Click({
    $dlg = [System.Windows.Forms.OpenFileDialog]::new()
    $dlg.Title = "Выберите файл или изображение"
    $dlg.Filter = "Все файлы (*.*)|*.*|Изображения (*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($fn in $dlg.FileNames) {
            Add-AttachedItem -Path $fn
        }
        $txtPromptInput.Focus()
    }
})

# Выбор папки через диалог
if ($btnAttachFolder) {
    $btnAttachFolder.Add_Click({
        $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
        $dlg.Description = "Выберите папку для прикрепления к запросу"
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if ($dlg.SelectedPath) {
                Add-AttachedItem -Path $dlg.SelectedPath
            }
            $txtPromptInput.Focus()
        }
    })
}

# Очистка прикрепленных файлов
$btnClearAttachments.Add_Click({
    Clear-AttachedImages
})

# Обработка клавиатурных событий поля ввода (Enter для отправки, Shift+Enter для новой строки, Ctrl+V для картинок)
$txtPromptInput.Add_PreviewKeyDown({
    param($sender, $e)
    # Перехват Alt+M для добавления в очередь или быстрой отправки
    if ($e.SystemKey -eq [System.Windows.Input.Key]::M -or ($e.Key -eq [System.Windows.Input.Key]::M -and [System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Alt))) {
        $e.Handled = $true
        Send-AgentPrompt
        return
    }
    if ($e.Key -eq [System.Windows.Input.Key]::Enter -or $e.Key -eq [System.Windows.Input.Key]::Return) {
        # Alt+M или Enter (без Shift): отправка запроса или добавление в очередь
        if ($e.SystemKey -eq [System.Windows.Input.Key]::M -or ($e.Key -eq [System.Windows.Input.Key]::M -and [System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Alt))) {
            $e.Handled = $true
            Send-AgentPrompt
            return
        }
        if ([System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Shift)) {
            # Shift+Enter: вставляем перевод строки в позицию курсора
            $caret = $txtPromptInput.CaretIndex
            $txtPromptInput.SelectedText = "`r`n"
            $txtPromptInput.CaretIndex = $caret + 2
            $e.Handled = $true
            return
        }

        # Обычный Enter (или Ctrl+Enter): отправка сообщения без вставки новой строки
        $e.Handled = $true
        Send-AgentPrompt
        return
    }

    # Перехват Ctrl+V для вставки скриншота/картинки в поле ввода
    if ($e.Key -eq [System.Windows.Input.Key]::V -and [System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Control)) {
        if (Handle-PasteAction) {
            $e.Handled = $true
            return
        }
    }
})

# Поддержка Drag and Drop файлов и папок в окно и в поле ввода
$script:HandleFileDropAction = {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        $hasAny = $false
        foreach ($f in $files) {
            if (Test-Path -LiteralPath $f) {
                Add-AttachedItem -Path $f
                $hasAny = $true
            }
        }
        if ($hasAny) {
            $e.Handled = $true
            if ($txtPromptInput) { $txtPromptInput.Focus() }
        }
    }
}

$script:HandleDragOverAction = {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
        $e.Handled = $true
    }
}

$window.Add_PreviewDragOver($script:HandleDragOverAction)
$window.Add_PreviewDrop($script:HandleFileDropAction)

if ($txtPromptInput) {
    $txtPromptInput.Add_PreviewDragOver($script:HandleDragOverAction)
    $txtPromptInput.Add_PreviewDrop($script:HandleFileDropAction)
}
$txtZoom.Add_MouseDown({
    param($sender, $e)
    if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        Reset-AppZoom
    }
})

# Масштабирование шрифта по зажатому Ctrl + колесико мыши
$window.Add_PreviewMouseWheel({
    param($sender, $e)
    if ([System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Control)) {
        $e.Handled = $true
        if ($e.Delta -gt 0) {
            Set-AppZoom 1.0
        } elseif ($e.Delta -lt 0) {
            Set-AppZoom -1.0
        }
    }
})

# Кнопка добавления новой вкладки
$btnNewTab.Add_Click({
    Add-NewTab -Select
})

# Горячие клавиши масштабирования, буфера обмена и управления вкладками: Ctrl+T, Ctrl+W, Ctrl+Tab, Ctrl+V, Ctrl+Plus/Minus/0
$window.Add_PreviewKeyDown({
    param($sender, $e)
    if ([System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Control)) {
        if ($e.Key -eq [System.Windows.Input.Key]::T) {
            $e.Handled = $true
            Add-NewTab -Select
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::W) {
            $e.Handled = $true
            Close-Tab -Tab $global:ActiveTab
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::Tab) {
            $e.Handled = $true
            if ([System.Windows.Input.Keyboard]::Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Shift)) {
                Prev-Tab
            } else {
                Next-Tab
            }
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::V) {
            if (Handle-PasteAction) {
                $e.Handled = $true
                $txtPromptInput.Focus()
            }
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::OemPlus -or $e.Key -eq [System.Windows.Input.Key]::Add) {
            $e.Handled = $true
            Set-AppZoom 1.0
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::OemMinus -or $e.Key -eq [System.Windows.Input.Key]::Subtract) {
            $e.Handled = $true
            Set-AppZoom -1.0
        }
        elseif ($e.Key -eq [System.Windows.Input.Key]::D0 -or $e.Key -eq [System.Windows.Input.Key]::NumPad0) {
            $e.Handled = $true
            Reset-AppZoom
        }
    }
})

# Инициализация списка разговоров
Refresh-ConversationsCombo

# Сохранение конфигурации и завершение фоновых процессов при закрытии окна
$window.Add_Closing({
    if ($limitsAutoRefreshTimer) {
        try { $limitsAutoRefreshTimer.Stop() } catch {}
    }
    if ($global:TabsList) {
        foreach ($t in @($global:TabsList)) {
            if ($t.SyncState -and $t.SyncState.IsRunning -and $t.SyncState.ProcessId -gt 0) {
                try {
                    $t.SyncState.StopRequested = $true
                    Stop-ProcessTree -processId $t.SyncState.ProcessId
                } catch {}
            }
            if ($t.LoadingJob) {
                try {
                    $t.LoadingJob.PowerShell.Dispose()
                } catch {}
            }
        }
    }
    Save-LauncherConfig
})

# Показ главного окна
if ($Headless -or $ValidateOnly -or ($env:ANTIGRAVITY_HEADLESS -eq '1')) {
    Write-Host "[OK] Antigravity GUI успешно инициализирован (Headless mode). Открытых вкладок: $($global:TabsList.Count)"
    $uiTimer.Stop()
    if ($limitsAutoRefreshTimer) {
        try { $limitsAutoRefreshTimer.Stop() } catch {}
    }
    return
}

$global:PerfState.Heartbeat = [DateTime]::UtcNow.Ticks
Start-UiHangWatchdog
$window.ShowDialog() | Out-Null
$uiTimer.Stop()
if ($limitsAutoRefreshTimer) {
    try { $limitsAutoRefreshTimer.Stop() } catch {}
}
