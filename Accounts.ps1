# Профили аккаунтов agy.
# agy хранит вход в Диспетчере учётных данных Windows одной записью "gemini:antigravity"
# (общие учётные данные). Профиль аккаунта = сохранённая копия этой записи.
# Копии лежат в %APPDATA%\AntigravityLauncher\accounts\*.dat, зашифрованные DPAPI (только для текущего
# пользователя Windows). Содержимое записи нигде не выводится и не пишется в лог.

Add-Type -AssemblyName System.Security

$script:AgyCredTarget = "gemini:antigravity"

if (-not ('CredNative' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class CredNative
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL
    {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWrite(ref CREDENTIAL credential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);

    private const int ERROR_NOT_FOUND = 1168;
    private const uint CRED_TYPE_GENERIC = 1;

    public class Item
    {
        public string Target;
        public string UserName;
        public string Comment;
        public uint Persist;
        public byte[] Blob;
    }

    // Возвращает null, если записи нет.
    public static Item Read(string target)
    {
        IntPtr ptr;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr))
        {
            int err = Marshal.GetLastWin32Error();
            if (err == ERROR_NOT_FOUND) return null;
            throw new Win32Exception(err);
        }
        try
        {
            CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            Item item = new Item();
            item.Target = c.TargetName;
            item.UserName = c.UserName;
            item.Comment = c.Comment;
            item.Persist = c.Persist;
            item.Blob = new byte[c.CredentialBlobSize];
            if (c.CredentialBlobSize > 0) Marshal.Copy(c.CredentialBlob, item.Blob, 0, (int)c.CredentialBlobSize);
            return item;
        }
        finally
        {
            CredFree(ptr);
        }
    }

    public static void Write(Item item)
    {
        CREDENTIAL c = new CREDENTIAL();
        c.Type = CRED_TYPE_GENERIC;
        c.TargetName = item.Target;
        c.UserName = item.UserName;
        c.Comment = item.Comment;
        c.Persist = item.Persist;
        c.CredentialBlobSize = (uint)item.Blob.Length;
        IntPtr blob = Marshal.AllocHGlobal(item.Blob.Length);
        try
        {
            Marshal.Copy(item.Blob, 0, blob, item.Blob.Length);
            c.CredentialBlob = blob;
            if (!CredWrite(ref c, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        finally
        {
            Marshal.FreeHGlobal(blob);
        }
    }

    // Возвращает false, если записи уже нет.
    public static bool Delete(string target)
    {
        if (CredDelete(target, CRED_TYPE_GENERIC, 0)) return true;
        int err = Marshal.GetLastWin32Error();
        if (err == ERROR_NOT_FOUND) return false;
        throw new Win32Exception(err);
    }
}
"@
}

function Get-AccountsDirectory {
    $dir = Join-Path $userDataDir "accounts"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Get-AccountIndex {
    # Индекс профилей (без секретов): { active: "имя" | null, profiles: [ { name, file, saved } ] }
    $path = Join-Path (Get-AccountsDirectory) "accounts.json"
    if (-not (Test-Path $path)) {
        return [pscustomobject]@{ active = $null; profiles = @() }
    }
    $obj = Get-Content -Path $path -Raw -Encoding utf8 | ConvertFrom-Json
    return [pscustomobject]@{ active = $obj.active; profiles = @($obj.profiles) }
}

function Save-AccountIndex($Index) {
    $path = Join-Path (Get-AccountsDirectory) "accounts.json"
    $json = [pscustomobject]@{ active = $Index.active; profiles = @($Index.profiles) } | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Test-AgyLoggedIn {
    return ($null -ne [CredNative]::Read($script:AgyCredTarget))
}

function Write-AccountFile([string]$FilePath, $Item) {
    $payload = [pscustomobject]@{
        Target   = $Item.Target
        UserName = $Item.UserName
        Comment  = $Item.Comment
        Persist  = $Item.Persist
        BlobB64  = [Convert]::ToBase64String($Item.Blob)
    } | ConvertTo-Json -Compress
    $plain = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $enc = [System.Security.Cryptography.ProtectedData]::Protect($plain, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    [System.IO.File]::WriteAllBytes($FilePath, $enc)
}

function Read-AccountFile([string]$FilePath) {
    $enc = [System.IO.File]::ReadAllBytes($FilePath)
    $plain = [System.Security.Cryptography.ProtectedData]::Unprotect($enc, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $p = [System.Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json
    $item = New-Object CredNative+Item
    $item.Target   = [string]$p.Target
    $item.UserName = [string]$p.UserName
    $item.Comment  = [string]$p.Comment
    $item.Persist  = [uint32]$p.Persist
    $item.Blob     = [Convert]::FromBase64String([string]$p.BlobB64)
    return $item
}

function Save-CurrentAccountAsProfile {
    # Сохраняет текущий вход agy как профиль с именем $Name (существующий профиль перезаписывается).
    param([Parameter(Mandatory=$true)][string]$Name)
    $Name = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($Name)) { throw "Пустое имя профиля." }
    $item = [CredNative]::Read($script:AgyCredTarget)
    if ($null -eq $item) { throw "agy сейчас не авторизован: запись '$($script:AgyCredTarget)' не найдена. Сначала войдите в аккаунт." }

    $idx = Get-AccountIndex
    $existing = @($idx.profiles | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
    $file = if ($existing) { $existing.file } else { "$([guid]::NewGuid().ToString('N')).dat" }
    Write-AccountFile -FilePath (Join-Path (Get-AccountsDirectory) $file) -Item $item

    $others = @($idx.profiles | Where-Object { $_.name -ne $Name })
    $entry = [pscustomobject]@{ name = $Name; file = $file; saved = (Get-Date).ToString("s") }
    $idx.profiles = @($others) + @($entry)
    $idx.active = $Name
    Save-AccountIndex $idx
}

function Switch-ToAccountProfile {
    # Подставляет сохранённый вход профиля $Name. Перед этим текущий вход обновляется в активном профиле
    # (agy обновляет токены сам, и в профиле не должна оставаться устаревшая копия).
    param([Parameter(Mandatory=$true)][string]$Name)
    $idx = Get-AccountIndex
    $target = @($idx.profiles | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
    if (-not $target) { throw "Профиль '$Name' не найден." }
    $item = Read-AccountFile -FilePath (Join-Path (Get-AccountsDirectory) $target.file)

    if ($idx.active -and $idx.active -ne $Name -and (Test-AgyLoggedIn)) {
        Save-CurrentAccountAsProfile -Name $idx.active
        $idx = Get-AccountIndex
    }
    [CredNative]::Write($item)
    $idx.active = $Name
    Save-AccountIndex $idx
}

function Remove-AccountProfile {
    param([Parameter(Mandatory=$true)][string]$Name)
    $idx = Get-AccountIndex
    $target = @($idx.profiles | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
    if (-not $target) { throw "Профиль '$Name' не найден." }
    $filePath = Join-Path (Get-AccountsDirectory) $target.file
    if (Test-Path $filePath) { Remove-Item -Path $filePath -Force }
    $idx.profiles = @($idx.profiles | Where-Object { $_.name -ne $Name })
    if ($idx.active -eq $Name) { $idx.active = $null }
    Save-AccountIndex $idx
}

function Set-ActiveAccountNone {
    $idx = Get-AccountIndex
    $idx.active = $null
    Save-AccountIndex $idx
}
