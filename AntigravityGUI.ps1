<#
.SYNOPSIS
    Графическая настольная оболочка (Desktop GUI) для запуска и взаимодействия с Antigravity CLI (agy.exe).
.DESCRIPTION
    Нативное приложение на базе Windows Presentation Foundation (WPF) и .NET.
    Не требует установки дополнительных интерпретаторов или библиотек.
    Поддерживает потоковый вывод (streaming) токенов, контекст сессий, выбор моделей и проектов.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# --- Определение расположения исполняемого файла agy.exe ---
$defaultAgyPath = "$env:LOCALAPPDATA\agy\bin\agy.exe"
if (-not (Test-Path $defaultAgyPath)) {
    $foundInPath = (Get-Command agy.exe -ErrorAction SilentlyContinue).Source
    if ($foundInPath) {
        $defaultAgyPath = $foundInPath
    }
}

# --- Корневая папка проектов ---
$defaultWorkspace = "C:\Users\Olden\Desktop\IGROSTROY"
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
                    <Button x:Name="BtnLaunchTui" Grid.Column="4" Content="🖥️ Открыть TUI" Background="#2A3245" BorderBrush="#3D4B66" ToolTip="Открыть интерактивную консоль agy с текущим диалогом"/>
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

                    <Button x:Name="BtnAttachImage"
                            Grid.Row="2"
                            Content="📎 Картинка"
                            Background="#23272E"
                            BorderBrush="#3E4451"
                            Padding="6,3"
                            FontSize="11"
                            ToolTip="Прикрепить изображение из файла (или нажмите Ctrl+V для вставки скриншота)"/>

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
                <!-- ГРАФИЧЕСКИЙ ВИДЖЕТ ЗАПОЛНЕННОСТИ КОНТЕКСТА -->
                <Border x:Name="BorderContextWidget" Grid.Column="2"
                        Background="#1C1F26" BorderBrush="#2D333B" BorderThickness="1"
                        CornerRadius="5" Padding="7,3" Cursor="Hand" VerticalAlignment="Center"
                        ToolTip="Заполненность контекстного окна модели. Нажмите для подробного анализа.">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="🧠" FontSize="11" Margin="0,0,5,0" VerticalAlignment="Center"/>
                        
                        <!-- Графическая полоса прогресса (Progress Bar) -->
                        <ProgressBar x:Name="PrgContext" Template="{StaticResource ContextProgressBarTemplate}"
                                     Width="80" Height="8" Minimum="0" Maximum="100" Value="0"
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

# --- Определение расположения папки лаунчера ---
$launcherDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    "C:\Users\Olden\Desktop\IGROSTROY\AntigravityLauncher"
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
$txtZoom                = $window.FindName("TxtZoom")
$txtConversationId      = $window.FindName("TxtConversationId")
$btnClearLog            = $window.FindName("BtnClearLog")
$borderAttachments      = $window.FindName("BorderAttachments")
$pnlAttachmentsList     = $window.FindName("PnlAttachmentsList")
$btnClearAttachments    = $window.FindName("BtnClearAttachments")
$btnAttachImage         = $window.FindName("BtnAttachImage")
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
    "C:\Users\Olden\Desktop\IGROSTROY\AntigravityLauncher"
}
$configFilePath = Join-Path $launcherDir "launcher_config.json"

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

function Render-AttachmentsUI {
    $pnlAttachmentsList.Children.Clear()
    if ($global:AttachedImages.Count -eq 0) {
        $borderAttachments.Visibility = [System.Windows.Visibility]::Collapsed
        return
    }

    $borderAttachments.Visibility = [System.Windows.Visibility]::Visible

    foreach ($item in $global:AttachedImages) {
        $capturedItem = $item

        # Карточка изображения
        $card = [System.Windows.Controls.Border]::new()
        $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#252A30")
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#383E4A")
        $card.BorderThickness = [System.Windows.Thickness]::new(1)
        $card.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $card.Padding = [System.Windows.Thickness]::new(4, 4, 6, 4)
        $card.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)

        $cardGrid = [System.Windows.Controls.StackPanel]::new()
        $cardGrid.Orientation = [System.Windows.Controls.Orientation]::Horizontal

        # Миниатюра
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
            [void]$cardGrid.Children.Add($imgBorder)
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

        [void]$cardGrid.Children.Add($txtBox)

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
        $btnRemove.ToolTip = "Удалить это изображение"
        $btnRemove.Add_Click({
            $global:AttachedImages.Remove($capturedItem) | Out-Null
            Render-AttachmentsUI
        })

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
        $fileSize = [math]::Round((Get-Item $filePath).Length / 1024)

        $item = [pscustomobject]@{
            FilePath    = $filePath
            FileName    = $filename
            DisplayName = "Скриншот (${w}x${h})"
            DimInfo     = "${w}x${h} • ${fileSize} KB"
            ImageSource = $bs
        }
        $global:AttachedImages.Add($item)
        Render-AttachmentsUI
    } catch {
        [System.Windows.MessageBox]::Show("Не удалось вставить изображение из буфера: $($_.ToString())", "Ошибка вставки", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    }
}

function Add-AttachedImageFile {
    param([string]$path)
    if (-not (Test-Path $path)) { return }
    try {
        $ext = [System.IO.Path]::GetExtension($path).ToLower()
        if ($ext -notin @(".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")) { return }

        $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit()
        $bi.UriSource = [System.Uri]::new($path)
        $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bi.EndInit()
        $bi.Freeze()

        $fn = [System.IO.Path]::GetFileName($path)
        $fileSize = [math]::Round((Get-Item $path).Length / 1024)
        $w = [math]::Round($bi.PixelWidth)
        $h = [math]::Round($bi.PixelHeight)

        $item = [pscustomobject]@{
            FilePath    = (Convert-Path $path)
            FileName    = $fn
            DisplayName = $fn
            DimInfo     = "${w}x${h} • ${fileSize} KB"
            ImageSource = $bi
        }
        $global:AttachedImages.Add($item)
        Render-AttachmentsUI
    } catch {}
}

function Handle-PasteAction {
    if ([System.Windows.Clipboard]::ContainsImage()) {
        Add-ClipboardImage
        return $true
    }
    if ([System.Windows.Clipboard]::ContainsFileDropList()) {
        $files = [System.Windows.Clipboard]::GetFileDropList()
        $hasImg = $false
        foreach ($f in $files) {
            $ext = [System.IO.Path]::GetExtension($f).ToLower()
            if ($ext -in @(".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")) {
                Add-AttachedImageFile $f
                $hasImg = $true
            }
        }
        if ($hasImg) { return $true }
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
        $doc.Blocks.Clear()
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
                $txtChatLog.UpdateLayout()
                $txtChatLog.ScrollToEnd()
                $txtChatLog.ScrollToVerticalOffset([double]::MaxValue)
                if ($txtChatLog.Document -and $txtChatLog.Document.ContentEnd) {
                    $txtChatLog.CaretPosition = $txtChatLog.Document.ContentEnd
                }
            } catch {}
        }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
    } catch {}
}

function Show-LoadingOverlay {
    param(
        [string]$Title = "Загрузка диалога...",
        [string]$Subtitle = "Считывание истории и форматирование..."
    )
    if (-not $loadingOverlay) { return }
    if ($txtLoadingTitle) { $txtLoadingTitle.Text = $Title }
    if ($txtLoadingSubtitle) { $txtLoadingSubtitle.Text = $Subtitle }
    $loadingOverlay.Visibility = [System.Windows.Visibility]::Visible
}

function Hide-LoadingOverlay {
    if (-not $loadingOverlay) { return }
    $loadingOverlay.Visibility = [System.Windows.Visibility]::Collapsed
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
        [string]$TimeStr = "",
        [Parameter(Mandatory=$true)][string]$Text,
        [string]$Badges = "",
        $Document = $null
    )
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }

    $effFontSize = if ($global:CurrentFontSize -and $global:CurrentFontSize -gt 0) { [double]$global:CurrentFontSize } else { 13.0 }
    $calcLineHeight = [math]::Round([math]::Max(20.0, $effFontSize * 1.55))

    $headerText = if ($TimeStr) { "[Вы ($TimeStr)]: " } else { "[Вы]: " }

    $lines = $Text -split "\r?\n"
    $firstLine = if ($lines.Length -gt 0) { $lines[0] } else { "" }

    $p = [System.Windows.Documents.Paragraph]::new()
    $p.Margin = [System.Windows.Thickness]::new(0, 8, 0, 4)
    $p.LineHeight = $calcLineHeight
    $p.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight

    # 1. Заголовок [Вы (HH:mm:ss)]:
    $headerRun = [System.Windows.Documents.Run]::new($headerText)
    $headerRun.Foreground = Get-CachedBrush "#4FC1FF"
    $headerRun.FontWeight = [System.Windows.FontWeights]::Bold
    $p.Inlines.Add($headerRun)

    # 2. Бейджи прикрепленных файлов (если есть)
    if (-not [string]::IsNullOrEmpty($Badges)) {
        $badgeRun = [System.Windows.Documents.Run]::new("$Badges ")
        $badgeRun.Foreground = Get-CachedBrush "#E2C08D"
        $badgeRun.FontWeight = [System.Windows.FontWeights]::SemiBold
        $p.Inlines.Add($badgeRun)
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
    }

    # Эффект наведения мыши на шапку и бейдж
    $headerBtn.Add_MouseEnter({
        $headerBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#333338")
    })
    $headerBtn.Add_MouseLeave({
        $headerBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2D2D30")
    })
    $toggleBadge.Add_MouseEnter({
        $toggleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4A4A52")
        $toggleBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#6E6E78")
    })
    $toggleBadge.Add_MouseLeave({
        $toggleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38383C")
        $toggleBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4E4E52")
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
    $matches = [regex]::Matches($text, $pattern)
    if ($matches.Count -gt 0) {
        foreach ($m in $matches) {
            $body = $m.Groups[1].Value.Trim()
            $summary = ""
            if ($body -match 'content=([^\r\n]+)') {
                $summary = $matches[1].Trim()
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
        [Parameter(Mandatory=$true)][string]$Summary,
        [Parameter(Mandatory=$true)][string]$Body,
        [switch]$StartCollapsed = $true,
        $Document = $null
    )

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

    # Эффекты при наведении
    $headerBtn.Add_MouseEnter({
        $headerBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#282E37")
    })
    $headerBtn.Add_MouseLeave({
        $headerBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#21262D")
    })
    $toggleBadge.Add_MouseEnter({
        $toggleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3C444D")
        $toggleBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#58A6FF")
    })
    $toggleBadge.Add_MouseLeave({
        $toggleBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#30363D")
        $toggleBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#484F58")
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
    foreach ($t in $toolsList) {
        $row = [System.Windows.Controls.TextBlock]::new()
        $tSummary = if ($t.Summary) { " — $($t.Summary)" } else { "" }
        $row.Text = "  ✔️ ⚙️ [$($t.Name)]$tSummary"
        $row.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4EC9B0")
        $row.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
        $card.BodyPanel.Children.Add($row) | Out-Null
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
$launcherDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    "C:\Users\Olden\Desktop\IGROSTROY\AntigravityLauncher"
}
$sessionMetaPath = Join-Path $launcherDir "sessions_meta.json"
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
            $sessionMetaPath = Join-Path $launcherDir "sessions_meta.json"
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

function Get-AntigravityConversations {
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
            }

            if (-not $workspace -and $histMap.ContainsKey($cid)) {
                $workspace = $histMap[$cid]
            }

            if (Test-Path $tPath) {
                try {
                    $sr = [System.IO.StreamReader]::new($tPath, [System.Text.Encoding]::UTF8)
                    $lineNum = 0
                    while (-not $sr.EndOfStream) {
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
                        if (-not $workspace -and $lineNum -lt 15) {
                            if ($l -match '(?i)(?<![A-Za-z0-9])([A-Za-z]:\\\\(?:[^"''\r\n\\]+\\\\)*?IGROSTROY(?:\\\\([^\r\n"''\\]+))?)') {
                                $workspace = $matches[1].Replace('\\', '\')
                            }
                        }
                    }
                    $sr.Close()
                    $msgCount = $lineNum
                } catch {}
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

    return $list | Sort-Object LastModified -Descending
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

        return [pscustomobject]@{
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
        if ($OwnerWindow) {
            $diag.Owner = $OwnerWindow
        } elseif ($window) {
            $diag.Owner = $window
        }
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

function Get-ConversationPreviewText {
    param([string]$conversationId)
    $tPath = "$env:USERPROFILE\.gemini\antigravity-cli\brain\$conversationId\.system_generated\logs\transcript.jsonl"
    if (-not (Test-Path $tPath)) { return "История диалога пуста или файл transcript.jsonl не найден." }

    $userPrompts = [System.Collections.Generic.List[string]]::new()
    $agentResponses = [System.Collections.Generic.List[string]]::new()

    try {
        $sr = [System.IO.StreamReader]::new($tPath, [System.Text.Encoding]::UTF8)
        while (-not $sr.EndOfStream) {
            $line = $sr.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $step = $line | ConvertFrom-Json
                if ($step.type -eq "USER_INPUT" -and $step.content) {
                    $c = $step.content
                    if ($c -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') { $c = $matches[1].Trim() }
                    $userPrompts.Add($c)
                }
                elseif ($step.type -eq "PLANNER_RESPONSE" -and $step.content) {
                    $agentResponses.Add($step.content.Trim())
                }
            } catch {}
        }
        $sr.Close()
    } catch {}

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("ID: $conversationId")
    [void]$sb.AppendLine("Всего запросов пользователя: $($userPrompts.Count)")
    [void]$sb.AppendLine("Всего ответов агента: $($agentResponses.Count)")

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

    if ($userPrompts.Count -gt 0) {
        [void]$sb.AppendLine("--- ПЕРВЫЙ ЗАПРОС ---")
        $firstP = $userPrompts[0]
        if ($firstP.Length -gt 350) { $firstP = $firstP.Substring(0, 347) + "..." }
        [void]$sb.AppendLine($firstP)
        [void]$sb.AppendLine("")
    }

    if ($userPrompts.Count -gt 1) {
        [void]$sb.AppendLine("--- ПОСЛЕДНИЙ ЗАПРОС ---")
        $lastP = $userPrompts[-1]
        if ($lastP.Length -gt 350) { $lastP = $lastP.Substring(0, 347) + "..." }
        [void]$sb.AppendLine($lastP)
        [void]$sb.AppendLine("")
    }

    if ($agentResponses.Count -ge 1) {
        [void]$sb.AppendLine("--- ПОСЛЕДНИЙ ОТВЕТ АГЕНТА ---")
        $lastA = $agentResponses[-1]
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
        while (-not $sr.EndOfStream) {
            $line = $sr.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $step = $line | ConvertFrom-Json
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
        $sr.Close()
    } catch {}

    [void]$sb.AppendLine("`r`n--- [Вы можете продолжить этот диалог, введя сообщение ниже] ---`r`n`r`n")
    return $sb.ToString()
}

# Скрипт-блок для фонового неблокирующего считывания и JSON-парсинга транскрипта
$global:ParseTranscriptScript = {
    param([string]$path)
    if (-not (Test-Path $path)) { return @() }

    $turns = [System.Collections.Generic.List[psobject]]::new()
    $currentTurn = $null
    $activeTools = [System.Collections.Generic.List[psobject]]::new()

    try {
        $sr = [System.IO.StreamReader]::new($path, [System.Text.Encoding]::UTF8)
        while (-not $sr.EndOfStream) {
            $line = $sr.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if (-not ($line.Contains('"USER_INPUT"') -or $line.Contains('"PLANNER_RESPONSE"') -or $line.Contains('"SYSTEM_MESSAGE"') -or $line.Contains('SYSTEM_MESSAGE'))) { continue }

            try {
                $step = $line | ConvertFrom-Json
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

                    # Разбор прикрепленных изображений: извлечение имени файлов в бейджи и очистка текста
                    if ($raw -match '(?s)\[Прикрепленные изображения:\s*(.*?)\s*\]') {
                        $imgSection = $matches[1]
                        $imgFiles = [System.Collections.Generic.List[string]]::new()
                        foreach ($m in [regex]::Matches($imgSection, '(?m)^\s*-\s*(?:file:///)?([^\r\n]+)')) {
                            $fn = [System.IO.Path]::GetFileName($m.Groups[1].Value.Trim().Replace('/', '\'))
                            if ($fn) { $imgFiles.Add("🖼️ $fn") }
                        }
                        if ($imgFiles.Count -gt 0) {
                            $badges = "[" + ($imgFiles -join ", ") + "]"
                        }
                        $cleanText = [regex]::Replace($raw, '(?s)\[Прикрепленные изображения:[\s\S]*?\]\s*(?:Внимание агенту:[^\r\n]*\r?\n*)?', '').Trim()
                    }

                    if ($cleanText -match '<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>') {
                        $cleanText = $matches[1].Trim()
                    }

                    $timeStr = if ($step.created_at) {
                        try { [DateTime]::Parse($step.created_at).ToLocalTime().ToString("HH:mm:ss") } catch { "" }
                    } else { "" }

                    $currentTurn = [pscustomobject]@{
                        UserTime   = $timeStr
                        UserText   = $cleanText
                        UserBadges = $badges
                        Items      = [System.Collections.Generic.List[psobject]]::new()
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
                elseif ($step.type -eq "PLANNER_RESPONSE" -and $currentTurn) {
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
        $sr.Close()
    } catch {}

    if ($currentTurn) {
        if ($activeTools.Count -gt 0) {
            $currentTurn.Items.Add([pscustomobject]@{ Type = "TOOLS"; Tools = $activeTools.ToArray() })
            $activeTools.Clear()
        }
        $turns.Add($currentTurn)
    }

    return $turns.ToArray()
}

function Populate-ConversationTranscriptToLog {
    param(
        $Turns,
        [string]$conversationId,
        $Document = $null
    )
    $doc = if ($Document) { $Document } elseif ($txtChatLog) { $txtChatLog.Document } else { $null }
    if (-not $doc) { return }

    $doc.Blocks.Clear()

    # Аккуратное системное уведомление в стиле живого чата ([ИНФО])
    $pInfo = [System.Windows.Documents.Paragraph]::new()
    $pInfo.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)
    $runInfo = [System.Windows.Documents.Run]::new("[ИНФО] Загружена история диалога ($conversationId)")
    $runInfo.Foreground = Get-CachedBrush "#6A9955"
    $pInfo.Inlines.Add($runInfo)
    $doc.Blocks.Add($pInfo)

    $hasMessages = $false
    if ($Turns -and $Turns.Count -gt 0) {
        $hasMessages = $true
        foreach ($turn in $Turns) {
            # 1. Запрос пользователя (только если не пустой): время [Вы (HH:mm:ss)], бейджи картинок [🖼️ ...], форматированный текст
            if (-not [string]::IsNullOrWhiteSpace($turn.UserText) -or -not [string]::IsNullOrWhiteSpace($turn.UserBadges)) {
                Append-UserMessageToLog -TimeStr $turn.UserTime -Text $turn.UserText -Badges $turn.UserBadges -Document $doc
            }

            # 2. Элементы ответа (инструменты, текст агента, системные карточки)
            if ($turn.Items -and $turn.Items.Count -gt 0) {
                $agentHeaderAdded = $false

                foreach ($item in $turn.Items) {
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
                        Append-MarkdownFormatted -Text $item.Text -Document $doc -BaseColor "#D4D4D4"
                    }
                    elseif ($item.Type -eq "SYSTEM_MESSAGE") {
                        [void](New-SystemMessageCard -Summary $item.Summary -Body $item.Body -StartCollapsed -Document $doc)
                    }
                }

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

    # Отменяем предыдущую задачу загрузки на этой вкладке, если она выполнялась
    if ($Tab.LoadingJob) {
        try {
            $Tab.LoadingJob.PowerShell.Stop()
            $Tab.LoadingJob.PowerShell.Dispose()
        } catch {}
        $Tab.LoadingJob = $null
    }

    if (-not (Test-Path $tPath)) {
        Populate-ConversationTranscriptToLog -Turns @() -conversationId $conversationId -Document $Tab.Document
        $Tab.StatusText = "Диалог загружен, готов к продолжению"
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

    # Показываем оверлей загрузки для активной вкладки
    if ($Tab -eq $global:ActiveTab) {
        $sub = if ($Tab.Title) { $Tab.Title } else { "Считывание истории..." }
        Show-LoadingOverlay -Title "Загрузка диалога..." -Subtitle $sub
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
    if (-not $global:TabsList) { return }
    foreach ($t in @($global:TabsList)) {
        if ($t.LoadingJob -and $t.LoadingJob.AsyncResult.IsCompleted) {
            $job = $t.LoadingJob
            $t.LoadingJob = $null
            $turns = @()
            try {
                $rawTurns = $job.PowerShell.EndInvoke($job.AsyncResult)
                $job.PowerShell.Dispose()
                if ($rawTurns) { $turns = $rawTurns }
            } catch {
                try { $job.PowerShell.Dispose() } catch {}
            }

            # Проверяем, что ID диалога на вкладке не сменился за время фоновой загрузки
            if ($job.ConvId -eq $t.ConversationId) {
                Populate-ConversationTranscriptToLog -Turns $turns -conversationId $job.ConvId -Document $t.Document

                $t.StatusText = "Диалог загружен, готов к продолжению"
                $t.StatusColor = "#4CAF50"
                if ($t.HeaderDot) {
                    $t.HeaderDot.Fill = (Get-CachedBrush "#4CAF50")
                }

                if ($t -eq $global:ActiveTab) {
                    Hide-LoadingOverlay
                    $txtStatus.Text = $t.StatusText
                    $statusDot.Fill = (Get-CachedBrush "#4CAF50")
                    Scroll-ChatLogToEnd
                    Update-ContextDisplay -conversationId $job.ConvId -modelName $t.Model
                }
            }
        }
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

    $turns = & $global:ParseTranscriptScript $tPath
    if (-not $turns -or $turns.Count -eq 0) {
        return $false
    }

    Populate-ConversationTranscriptToLog -Turns $turns -conversationId $conversationId -Document $Document
    return $true
}

function Select-ConversationItem {
    param($conv)
    if (-not $conv -or -not $conv.Id) { return }

    $targetTab = $global:ActiveTab
    if (-not $targetTab) {
        $targetTab = Add-NewTab -ConversationId $conv.Id -Select
    } else {
        $targetTab.ConversationId = $conv.Id
        $title = if ($conv.Title) { $conv.Title } else { "Диалог $($conv.Id.Substring(0,8))" }
        $cleanTitle = if ($title.Length -gt 20) { $title.Substring(0, 20) + "..." } else { $title }
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

    $global:SuppressConvComboEvent = $true
    try {
        for ($i = 0; $i -lt $cmbConversations.Items.Count; $i++) {
            $item = $cmbConversations.Items[$i]
            if ($item.Tag -eq $conv.Id) {
                $cmbConversations.SelectedIndex = $i
                break
            }
        }
    } finally {
        $global:SuppressConvComboEvent = $false
    }

    # Запуск плавной неблокирующей асинхронной загрузки с красивой анимацией
    Start-AsyncTranscriptLoad -conversationId $conv.Id -Tab $targetTab
    $targetTab.IsTranscriptLoaded = $true
    Update-ContextDisplay -conversationId $conv.Id
    Save-LauncherConfig
}

function Reset-ToNewChat {
    $tab = $global:ActiveTab
    if ($tab) {
        if ($tab.LoadingJob) {
            try {
                $tab.LoadingJob.PowerShell.Stop()
                $tab.LoadingJob.PowerShell.Dispose()
            } catch {}
            $tab.LoadingJob = $null
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

    $global:SuppressConvComboEvent = $true
    try {
        $cmbConversations.SelectedIndex = 0
    } finally {
        $global:SuppressConvComboEvent = $false
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
        try {
            Remove-Item -Path $targetDir -Recurse -Force -ErrorAction Stop
            $success = $true
        } catch {
            Write-Warning "Не удалось удалить директорию диалога $targetDir : $_"
            return $false
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
            $sessionMetaPath = Join-Path $launcherDir "sessions_meta.json"
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
        $OwnerWindow = $null
    )

    $dialogXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="✏️ Переименование разговора"
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
                $cmbConversations.SelectedIndex = $foundIdx
            } else {
                $cmbConversations.SelectedIndex = 0
            }
        } else {
            $cmbConversations.SelectedIndex = 0
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
        $allConvs.Clear()
        $items = Get-AntigravityConversations
        foreach ($it in $items) { $allConvs.Add($it) }
        $applyFilter.Invoke()
    }

    $txtSearch.Add_TextChanged({
        $applyFilter.Invoke()
    })

    $btnRefreshList.Add_Click({
        $loadList.Invoke()
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
        IsTranscriptLoaded  = $isLoaded
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
        $closeBtn.Background = (Get-CachedBrush "#C53030")
        $closeTxt.Foreground = [System.Windows.Media.Brushes]::White
    })
    $closeBtn.Add_MouseLeave({
        $closeBtn.Background = [System.Windows.Media.Brushes]::Transparent
        $closeTxt.Foreground = (Get-CachedBrush "#888888")
    })
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

    # Автозагрузка диалога при переключении на вкладку
    if (-not $NoAutoLoad -and -not $Tab.IsTranscriptLoaded -and $Tab.ConversationId) {
        Load-TabConversation -Tab $Tab
    }

    if (-not $SkipSave) {
        Save-LauncherConfig
    }
}

function Stop-ProcessTree([int]$processId) {
    if ($processId -le 0) { return }
    try {
        & taskkill.exe /PID $processId /T /F 2>$null | Out-Null
    } catch {}
    try {
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Close-Tab {
    param([Parameter(Mandatory=$true)]$Tab)
    
    # Если на вкладке выполнялась фоновая загрузка, освобождаем ресурсы ранспейса
    if ($Tab.LoadingJob) {
        try {
            $Tab.LoadingJob.PowerShell.Stop()
            $Tab.LoadingJob.PowerShell.Dispose()
        } catch {}
        $Tab.LoadingJob = $null
    }

    # Если на вкладке выполняется процесс, принудительно останавливаем его дерево
    if ($Tab.SyncState.IsRunning -and $Tab.SyncState.ProcessId -gt 0) {
        try {
            $pidToKill = $Tab.SyncState.ProcessId
            $Tab.SyncState.StopRequested = $true
            Stop-ProcessTree -processId $pidToKill
        } catch {}
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

    if ($Select -or $global:TabsList.Count -eq 1) {
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
            [void](Add-NewTab -Title $tTitle -ConversationId $tConvId -Workspace $tWs -Model $tModel -Mode $tMode -Effort $tEffort -SkipPerms $tSkipPerms -Lazy:([bool]$tConvId) -SkipSave)
        }

        # Активируем сохранённую вкладку без автоматической подгрузки до клика пользователя
        $targetIdx = if ($activeIdx -ge 0 -and $activeIdx -lt $global:TabsList.Count) { $activeIdx } else { 0 }
        Switch-ToTab -Tab $global:TabsList[$targetIdx] -NoAutoLoad -SkipSave
        Save-LauncherConfig
    } else {
        # Если сохраненных вкладок нет, создаем одну начальную чистую сессию
        $initialTab = Add-NewTab -Title "Диалог 1" -Select
    }
}

# Инициализация и восстановление сохраненных вкладок (с ленивой загрузкой)
Restore-SavedTabs
$syncState = if ($global:ActiveTab) { $global:ActiveTab.SyncState } else { $null }
Update-ContextDisplay

# --- Таймер обновления UI на основном потоке (параллельный опрос всех вкладок) ---
$uiTimer = [System.Windows.Threading.DispatcherTimer]::new()
$uiTimer.Interval = [TimeSpan]::FromMilliseconds(40)

$uiTimer.Add_Tick({
    Update-TabLoadingJobs
    foreach ($t in @($global:TabsList)) {
        $item = $null
        while ($t.SyncState.Queue.TryDequeue([ref]$item)) {
            switch ($item.Type) {
                "token" {
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
                    $t.SyncState.IsRunning = $false
                    $t.StatusText = "Готов к работе"
                    $t.StatusColor = "#4CAF50"
                    if ($t.HeaderDot) {
                        $t.HeaderDot.Fill = (Get-CachedBrush "#4CAF50")
                    }
                    Append-ChatFormatted -Text "`r`n" -Color "#D4D4D4" -Document $t.Document
                    if ($t.ConversationId) {
                        Update-ContextDisplay -conversationId $t.ConversationId -modelName $t.Model
                    }
                    if ($t -eq $global:ActiveTab) {
                        $btnSend.IsEnabled = $true
                        $btnStop.IsEnabled = $false
                        $txtPromptInput.IsEnabled = $true
                        $statusDot.Fill = (Get-CachedBrush "#4CAF50")
                        $txtStatus.Text = "Готов к работе"
                        Scroll-ChatLogToEnd
                        $txtPromptInput.Focus() | Out-Null
                    }
                }
                "error" {
                    Finalize-ActiveToolGroup -Tab $t
                    Finalize-TabStreamingBuffer -Tab $t
                    $t.SyncState.IsRunning = $false
                    $t.StatusText = "Ошибка выполнения"
                    $t.StatusColor = "#F85149"
                    if ($t.HeaderDot) {
                        $t.HeaderDot.Fill = (Get-CachedBrush "#F85149")
                    }
                    Append-ChatFormatted -Text "`r`n❌ [ОШИБКА]: $($item.Message)`r`n`r`n" -Color "#F85149" -Bold -Document $t.Document
                    if ($t -eq $global:ActiveTab) {
                        $btnSend.IsEnabled = $true
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
})
$uiTimer.Start()

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

# Выбор диалога из быстрого комбобокса
$cmbConversations.Add_SelectionChanged({
    if ($global:SuppressConvComboEvent) { return }
    $sel = $cmbConversations.SelectedItem
    if (-not $sel) { return }

    if (-not $sel.Tag) {
        Reset-ToNewChat
    } else {
        $convObj = $sel.ConvObj
        if (-not $convObj) {
            $convObj = (Get-AntigravityConversations) | Where-Object { $_.Id -eq $sel.Tag } | Select-Object -First 1
        }
        if ($convObj) {
            Select-ConversationItem $convObj
            Scroll-ChatLogToEnd
        }
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

# Остановка выполнения
$btnStop.Add_Click({
    $tab = $global:ActiveTab
    if ($tab -and $tab.SyncState.IsRunning -and $tab.SyncState.ProcessId -gt 0) {
        try {
            $pidToKill = $tab.SyncState.ProcessId
            $tab.SyncState.StopRequested = $true
            Stop-ProcessTree -processId $pidToKill
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "status"; Text = "Остановлено пользователем"; Color = "#E57373" })
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "system"; Text = "Процесс агента был принудительно остановлен." })
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "done" })
        } catch {
            $tab.SyncState.Queue.Enqueue([pscustomobject]@{ Type = "error"; Message = $_.ToString() })
        }
    }
})

# Основная функция отправки запроса
function Send-AgentPrompt {
    $prompt = $txtPromptInput.Text.Trim()
    $hasAttachments = ($global:AttachedImages.Count -gt 0)
    if ([string]::IsNullOrWhiteSpace($prompt) -and -not $hasAttachments) { return }
    if ([string]::IsNullOrWhiteSpace($prompt) -and $hasAttachments) {
        $prompt = "Пожалуйста, проанализируй прикрепленное изображение."
    }

    $tab = $global:ActiveTab
    if (-not $tab) { return }
    if ($tab.SyncState.IsRunning) { return }

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

    # Формирование полного промпта с путями к изображениям для агента
    $fullAgentPrompt = $prompt
    $attachedCopy = @($global:AttachedImages)
    $imgLogBadges = ""

    if ($hasAttachments) {
        $imgLines = @()
        $imgLines += "[Прикрепленные изображения:"
        foreach ($img in $attachedCopy) {
            $uriPath = "file:///" + $img.FilePath.Replace('\', '/')
            $imgLines += " - $uriPath"
        }
        $imgLines += "]"
        $imgLines += "Внимание агенту: обязательно изучи прикрепленные изображения по указанным путям с помощью инструмента read_file."
        $fullAgentPrompt = ($imgLines -join "`r`n") + "`r`n`r`n" + $prompt

        $badgeNames = ($attachedCopy | ForEach-Object { "🖼️ " + $_.DisplayName }) -join ", "
        $imgLogBadges = "[$badgeNames]"
    }

    Finalize-ActiveToolGroup -Tab $tab
    Finalize-TabStreamingBuffer -Tab $tab
    # Обновление UI перед стартом
    $timeNow = (Get-Date).ToString("HH:mm:ss")
    Append-UserMessageToLog -TimeStr $timeNow -Text $prompt -Badges $imgLogBadges -Document $tab.Document
    Append-AgentHeader -Document $tab.Document

    if ($global:ActiveTab -eq $tab) {
        Scroll-ChatLogToEnd
        $txtPromptInput.Text = ""
        Clear-AttachedImages
        $btnSend.IsEnabled = $false
        $btnStop.IsEnabled = $true
        $txtPromptInput.IsEnabled = $false
        $statusDot.Fill = (Get-CachedBrush "#FFA500")
        $txtStatus.Text = "Агент думает и выполняет задачи..."
    }

    $tab.StatusText = "Агент думает и выполняет задачи..."
    $tab.StatusColor = "#FFA500"
    if ($tab.HeaderDot) {
        $tab.HeaderDot.Fill = (Get-CachedBrush "#FFA500")
    }

    # Подготовка параметров для фонового ранспейса
    $tab.SyncState.IsRunning = $true
    $tab.SyncState.StopRequested = $false
    $tab.SyncState.ProcessId = 0
    $script:syncState = $tab.SyncState

    $jobData = [hashtable]::Synchronized(@{
        AgyPath         = $defaultAgyPath
        Workspace       = $workspace
        Prompt          = $fullAgentPrompt
        Model           = $model
        Mode            = $mode
        Effort          = $effort
        SkipPerms       = $skipPerms
        ConversationId  = $convId
        SyncState       = $tab.SyncState
    })

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("jobData", $jobData)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        $st = $jobData.SyncState
        try {
            # Экранирование промпта
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

            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi

            # Потокобезопасный сборщик stderr во избежание переполнения системного буфера pipe (Deadlock)
            $errSb = [System.Text.StringBuilder]::new()
            $proc.Add_ErrorDataReceived({
                param($s, $e)
                if ($e.Data) {
                    [void]$errSb.AppendLine($e.Data)
                }
            })

            $proc.Start() | Out-Null
            $proc.BeginErrorReadLine()
            $st.ProcessId = $proc.Id

            $turnFinished = $false

            while (-not $proc.HasExited) {
                $line = $proc.StandardOutput.ReadLine()
                if ($null -eq $line) {
                    # Конец потока (EOF)
                    break
                }
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
                                if ($evt.result.conversation_id) {
                                    $st.Queue.Enqueue([pscustomobject]@{ Type = "conversation_id"; Id = $evt.result.conversation_id })
                                }
                                # Получен финальный результат шага генерации - помечаем ход завершенным
                                $turnFinished = $true
                            }
                        }
                    } catch {
                        # Если строка не является JSON (например raw лог ошибки)
                        $st.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = $line })
                    }
                }
                if ($turnFinished) {
                    break
                }
            }

            if (-not $turnFinished) {
                $rem = $proc.StandardOutput.ReadToEnd()
                if ($rem) {
                    foreach ($l in ($rem -split "`r?`n")) {
                        if ($l) {
                            try {
                                $evt = $l | ConvertFrom-Json
                                if ($evt.event -eq "step_update" -and $evt.step_update.text_delta) {
                                    $st.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = $evt.step_update.text_delta })
                                } elseif ($evt.event -eq "result") {
                                    if ($evt.result.conversation_id) {
                                        $st.Queue.Enqueue([pscustomobject]@{ Type = "conversation_id"; Id = $evt.result.conversation_id })
                                    }
                                    $turnFinished = $true
                                }
                            } catch {
                                $st.Queue.Enqueue([pscustomobject]@{ Type = "token"; Text = $l })
                            }
                        }
                    }
                }
            }

            # Даем процессу agy.exe до 1500 мс на штатное завершение и освобождение дескрипторов
            if (-not $proc.WaitForExit(1500)) {
                try {
                    if (-not $proc.HasExited) {
                        & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null
                        if (-not $proc.HasExited) {
                            $proc.Kill()
                        }
                    }
                } catch {}
            }

            $errOutput = $errSb.ToString().Trim()

            if ($st.StopRequested) {
                # Остановлено пользователем через кнопку "Стоп"
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

$btnSend.Add_Click({
    Send-AgentPrompt
})

# Выбор изображений через диалог
$btnAttachImage.Add_Click({
    $dlg = [System.Windows.Forms.OpenFileDialog]::new()
    $dlg.Title = "Выберите изображение или скриншот"
    $dlg.Filter = "Изображения (*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif|Все файлы (*.*)|*.*"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($fn in $dlg.FileNames) {
            Add-AttachedImageFile $fn
        }
        $txtPromptInput.Focus()
    }
})

# Очистка прикрепленных файлов
$btnClearAttachments.Add_Click({
    Clear-AttachedImages
})

# Обработка клавиатурных событий поля ввода (Enter для отправки, Shift+Enter для новой строки, Ctrl+V для картинок)
$txtPromptInput.Add_PreviewKeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter -or $e.Key -eq [System.Windows.Input.Key]::Return) {
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

# Поддержка Drag and Drop изображений
$window.Add_PreviewDragOver({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
        $e.Handled = $true
    }
})

$window.Add_PreviewDrop({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        $hasImg = $false
        foreach ($f in $files) {
            $ext = [System.IO.Path]::GetExtension($f).ToLower()
            if ($ext -in @(".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")) {
                Add-AttachedImageFile $f
                $hasImg = $true
            }
        }
        if ($hasImg) {
            $e.Handled = $true
            $txtPromptInput.Focus()
        }
    }
})

# Клик по индикатору масштаба сбрасывает его к 100%
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

# Сохранение конфигурации при закрытии окна
$window.Add_Closing({
    Save-LauncherConfig
})

# Показ главного окна
$window.ShowDialog() | Out-Null
$uiTimer.Stop()
