<#
.SCRIPT       Generate-FakeOS-Structure.ps1
.DESCRIPTION  Generates a simulated OS or data partition structure with realistic directories and files.
.INITIALDATE  2025-06-25
.LASTREVISION 2025-06-25
.VERSION      1.16.1 - Ensure folder dates, user subfolders, and data in all folders
.GITHUB       https://github.com/VA3KWJ
#>

param()

#----------------------------------------
# Utility Functions
#----------------------------------------
function Get-RandomName {
    $length = Get-Random -Minimum 4 -Maximum 11
    $chars  = 'abcdefghijklmnopqrstuvwxyz'
    $arr    = for ($i = 0; $i -lt $length; $i++) { $chars.ToCharArray() | Get-Random }
    return (-join $arr).Substring(0,1).ToUpper() + (-join $arr).Substring(1)
}

function Get-RandomDate {
    param([DateTime]$Start,[DateTime]$End)
    $range = $End - $Start
    return $Start.AddTicks((Get-Random -Minimum 0 -Maximum $range.Ticks))
}

function New-AppFiles {
    param([string]$Folder)
    if (-Not (Test-Path $Folder)) { return }
    # Create primary application files
    $exe = Join-Path $Folder ((Get-RandomName)+'.exe')
    [IO.File]::WriteAllBytes($exe,(New-Object Byte[] (Get-Random -Minimum 131072 -Maximum 10485760)))
    # 2-5 DLL files
    for ($i=1; $i -le (Get-Random -Minimum 2 -Maximum 5); $i++) {
        $dll = Join-Path $Folder ((Get-RandomName)+'.dll')
        [IO.File]::WriteAllBytes($dll,(New-Object Byte[] (Get-Random -Minimum 131072 -Maximum 10485760)))
    }
    # 2-10 accompanying files
    $exts = @('.log','.jpg','.txt','.pdf')
    for ($i=1; $i -le (Get-Random -Minimum 2 -Maximum 10); $i++) {
        $file = Join-Path $Folder ((Get-RandomName)+($exts | Get-Random))
        [IO.File]::WriteAllBytes($file,(New-Object Byte[] (Get-Random -Minimum 131072 -Maximum 1048576)))
    }
    # 1-3 subfolders
    for ($i=1; $i -le (Get-Random -Minimum 1 -Maximum 3); $i++) {
        $sub = Join-Path $Folder (Get-RandomName)
        New-Item -Path $sub -ItemType Directory -Force | Out-Null
    }
}

#----------------------------------------
# User Prompts
#----------------------------------------
Write-Host '=== Fake OS/Data File Generator ==='
[string]$rootPath    = Read-Host 'Enter the root directory path'
[string]$mode        = Read-Host 'Create Full OS structure? (Y/N)' | %{ $_.Trim().ToUpper() }
[int]$fileCount      = Read-Host 'Enter the number of files to create'
[int]$folderCount    = Read-Host 'Enter the number of folders to create'
[DateTime]$dateStart = Read-Host 'Enter the start date (yyyy-MM-dd)' | %{ [DateTime]$_ }
[DateTime]$dateEnd   = Read-Host 'Enter the end date (yyyy-MM-dd)'   | %{ [DateTime]$_ }

# Ensure root path exists and set its dates
if (-Not (Test-Path $rootPath)) {
    New-Item -Path $rootPath -ItemType Directory -Force | Out-Null
    $dt = Get-RandomDate -Start $dateStart -End $dateEnd
    Set-ItemProperty -Path $rootPath -Name CreationTime -Value $dt
    Set-ItemProperty -Path $rootPath -Name LastWriteTime  -Value $dt
}

#----------------------------------------
# OS Mode Processing
#----------------------------------------
$appFolders = @()
if ($mode -eq 'Y') {
    # Create core OS directories
    $coreDirs = @('Program Files','Program Files (x86)','ProgramData','Windows','Windows\System32','temp','Users')
    foreach ($d in $coreDirs) {
        $path = Join-Path $rootPath $d
        if (-Not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            New-Item -Path $path | Out-Null # ensure directory creation
        }
    }
    # Populate Program Files with application folders
    foreach ($dir in @('Program Files','Program Files (x86)')) {
        $base = Join-Path $rootPath $dir
        1..3 | ForEach-Object {
            $appDir = Join-Path $base ('App-' + (Get-RandomName))
            New-Item -Path $appDir -ItemType Directory -Force | Out-Null
            New-AppFiles -Folder $appDir
            $appFolders += $appDir
        }
    }
    # Populate ProgramData
    $pdBase = Join-Path $rootPath 'ProgramData'
    $pdExts = @('.exe','.dll','.log','.msi','.dat','.txt')
    1..3 | ForEach-Object {
        $sub = Join-Path $pdBase (Get-RandomName)
        New-Item -Path $sub -ItemType Directory -Force | Out-Null
        1..(Get-Random -Minimum 5 -Maximum 10) | ForEach-Object {
            $file = Join-Path $sub ((Get-RandomName)+($pdExts | Get-Random))
            [IO.File]::WriteAllBytes($file,(New-Object Byte[] (Get-Random -Minimum 65536 -Maximum 1048576)))
        }
    }
    # Populate Windows and System32
    $winExts = @('.exe','.dll','.log','.bin','.ini','.dat','.sys')
    foreach ($sub in @('Windows','Windows\System32')) {
        $base = Join-Path $rootPath $sub
        1..(Get-Random -Minimum 10 -Maximum 20) | ForEach-Object {
            $file = Join-Path $base ((Get-RandomName)+($winExts | Get-Random))
            [IO.File]::WriteAllBytes($file,(New-Object Byte[] (Get-Random -Minimum 65536 -Maximum 1048576)))
        }
    }
    # Populate temp
    $tmpBase = Join-Path $rootPath 'temp'
    $tmpExts = @('.tmp','.temp','.log','.txt')
    1..(Get-Random -Minimum 5 -Maximum 15) | ForEach-Object {
        $file = Join-Path $tmpBase ((Get-RandomName)+($tmpExts | Get-Random))
        [IO.File]::WriteAllBytes($file,(New-Object Byte[] (Get-Random -Minimum 1024 -Maximum 65536)))
    }
}

#----------------------------------------
# Data Mode Processing
#----------------------------------------
else {
    # Split folderCount 50/50 between root and Users
    $halfRoot = [math]::Ceiling($folderCount/2)
    $halfUser = $folderCount - $halfRoot
    # Create root folders with subfolders
    1..$halfRoot | ForEach-Object {
        $f = Join-Path $rootPath (Get-RandomName)
        New-Item -Path $f -ItemType Directory -Force | Out-Null
        1..(Get-Random -Minimum 2 -Maximum 5) | ForEach-Object {
            $sf = Join-Path $f (Get-RandomName)
            New-Item -Path $sf -ItemType Directory -Force | Out-Null
        }
    }
    # Create Users folders
    $usersBase = Join-Path $rootPath 'Users'
    if (-Not (Test-Path $usersBase)) { New-Item -Path $usersBase -ItemType Directory -Force | Out-Null }
    $userDirs = 1..$halfUser | ForEach-Object {
        $u = Join-Path $usersBase (Get-RandomName)
        New-Item -Path $u -ItemType Directory -Force | Out-Null
        1..(Get-Random -Minimum 2 -Maximum 5) | ForEach-Object {
            $sf = Join-Path $u (Get-RandomName)
            New-Item -Path $sf -ItemType Directory -Force | Out-Null
        }
        $u
    }

    # Standard Windows user subfolders in each user directory
    $std = @('Documents','Downloads','Pictures','Music','Videos')
    $allUser = @()
    foreach ($u in $userDirs) {
        foreach ($sub in $std) {
            $path = Join-Path $u $sub
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            $allUser += $path
        }
    }

    # Distribute files into every folder (no empty)
    $allFolders = Get-ChildItem -Path $rootPath -Directory -Recurse | Select-Object -ExpandProperty FullName
    $exts = @('.txt','.docx','.pdf','.log','.csv','.jpg','.png','.md')
    foreach ($folder in $allFolders) {
        $num = 1 # at least one file
        1..$num | ForEach-Object {
            $file = Join-Path $folder ((Get-RandomName)+($exts | Get-Random))
            [IO.File]::WriteAllBytes($file,(New-Object Byte[] (Get-Random -Minimum 1024 -Maximum 1048576)))
        }
    }
}

#----------------------------------------
# Finalize: Randomize folder dates and file dates
#----------------------------------------
Get-ChildItem -Path $rootPath -Recurse | ForEach-Object {
    if ($_.PSIsContainer) {
        $dt = Get-RandomDate -Start $dateStart -End $dateEnd
        Set-ItemProperty -Path $_.FullName -Name CreationTime -Value $dt
        Set-ItemProperty -Path $_.FullName -Name LastWriteTime  -Value $dt
    } else {
        $dt = Get-RandomDate -Start $dateStart -End $dateEnd
        Set-ItemProperty -Path $_.FullName -Name CreationTime -Value $dt
        Set-ItemProperty -Path $_.FullName -Name LastWriteTime  -Value $dt
    }
}

Write-Host 'Done: Structure created with no empty folders and randomized dates.'
