<#
.SCRIPT       Generate-FakeOS-Structure.ps1
.DESCRIPTION  Generates a simulated OS or data partition structure with realistic directories and files.
.INITIALDATE  2025-06-25
.LASTREVISION 2025-06-25
.VERSION      1.16.2 - Added Data mode Create Applications prompt and file generation
.GITHUB       https://github.com/VA3KWJ
#>

param()

#----------------------------------------
# Utility Functions
#----------------------------------------
function Get-RandomName {
    $length = Get-Random -Minimum 4 -Maximum 11
    $chars  = 'abcdefghijklmnopqrstuvwxyz'
    $arr    = for ($i=0; $i -lt $length; $i++) { $chars.ToCharArray() | Get-Random }
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
    # 1 exe
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
[DateTime]$dateStart = Read-Host 'Enter the start date (yyyy-MM-dd)'|%{[DateTime]$_}
[DateTime]$dateEnd   = Read-Host 'Enter the end date (yyyy-MM-dd)'  |%{[DateTime]$_}

# Ensure root exists and set dates
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
    # Core OS
    $coreDirs = @('Program Files','Program Files (x86)','ProgramData','Windows','Windows\System32','temp','Users')
    foreach ($d in $coreDirs) {
        $p = Join-Path $rootPath $d
        if (-Not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    }
    # Applications in Program Files
    foreach ($pf in @('Program Files','Program Files (x86)')) {
        $base = Join-Path $rootPath $pf
        1..3 | ForEach-Object {
            $app = Join-Path $base ('App-' + (Get-RandomName))
            New-Item -Path $app -ItemType Directory -Force | Out-Null
            New-AppFiles -Folder $app
            $appFolders += $app
        }
    }
    # ProgramData mixed files
    $pdBase = Join-Path $rootPath 'ProgramData'; $pdExts=@('.exe','.dll','.log','.msi','.dat','.txt')
    1..3|ForEach-Object{ $sub=Join-Path $pdBase (Get-RandomName); New-Item -Path $sub -ItemType Directory -Force|Out-Null; 1..(Get-Random -Min 5 -Max 10)|ForEach-Object{ $f=Join-Path $sub ((Get-RandomName)+($pdExts|Get-Random)); [IO.File]::WriteAllBytes($f,(New-Object Byte[] (Get-Random -Min 65536 -Max 1048576))) } }
    # Windows & System32
    $we=@('.exe','.dll','.log','.bin','.ini','.dat','.sys')
    foreach ($sub in @('Windows','Windows\System32')) { $b=Join-Path $rootPath $sub; 1..(Get-Random -Min 10 -Max 20)|ForEach-Object{ $f=Join-Path $b ((Get-RandomName)+($we|Get-Random)); [IO.File]::WriteAllBytes($f,(New-Object Byte[] (Get-Random -Min 65536 -Max 1048576))) } }
    # Temp
    $tmp=Join-Path $rootPath 'temp'; $te=@('.tmp','.temp','.log','.txt')
    1..(Get-Random -Min 5 -Max 15)|ForEach-Object{ $f=Join-Path $tmp ((Get-RandomName)+($te|Get-Random)); [IO.File]::WriteAllBytes($f,(New-Object Byte[] (Get-Random -Min 1024 -Max 65536))) }

    # User account directories under Users
    $ub = Join-Path $rootPath 'Users'
    if (-Not (Test-Path $ub)) { New-Item -Path $ub -ItemType Directory -Force | Out-Null }
    # Create random user accounts
    $std = @('Documents','Downloads','Pictures','Music','Videos')
    $userFolders = 1..$folderCount | ForEach-Object {
        $u = Join-Path $ub (Get-RandomName)
        New-Item -Path $u -ItemType Directory -Force | Out-Null
        # Create standard subfolders for each user
        foreach ($s in $std) {
            $sub = Join-Path $u $s
            New-Item -Path $sub -ItemType Directory -Force | Out-Null
        }
        $u
    }
} else {
    # Data Mode: Create Applications prompt
    $createApps = Read-Host "Create Applications? (Y/N) [N]" | %{ if ([string]::IsNullOrWhiteSpace($_)) {'N'} else {$_.Trim().ToUpper()} }
    if ($createApps -eq 'Y') {
        [int]$num = Read-Host "Number of Application Directories?"
        1..$num|ForEach-Object{ $app=Join-Path $rootPath ('APP-' + (Get-RandomName)); New-Item -Path $app -ItemType Directory|Out-Null; New-AppFiles -Folder $app; $appFolders+=$app }
    }
    # Split folders 50/50
    $halfRoot=[math]::Ceiling($folderCount/2); $halfUser=$folderCount-$halfRoot
    # Root random folders
    1..$halfRoot|ForEach-Object{ $d=Join-Path $rootPath (Get-RandomName); New-Item -Path $d -ItemType Directory|Out-Null; 1..(Get-Random -Min 2 -Max 5)|ForEach-Object{New-Item -Path (Join-Path $d (Get-RandomName)) -ItemType Directory|Out-Null} }
    # Users
    $ub=Join-Path $rootPath 'Users'; if(-Not(Test-Path $ub)){New-Item -Path $ub -ItemType Directory|Out-Null}
    1..$halfUser|ForEach-Object{ $u=Join-Path $ub (Get-RandomName); New-Item -Path $u -ItemType Directory|Out-Null; 1..(Get-Random -Min 2 -Max 5)|ForEach-Object{New-Item -Path (Join-Path $u (Get-RandomName)) -ItemType Directory|Out-Null} }

    # Standard user subs
    $std=@('Documents','Downloads','Pictures','Music','Videos')
    $allUser=@()
    Get-ChildItem -Path $ub -Directory | ForEach-Object { foreach($s in $std){ $d=Join-Path $_.FullName $s; New-Item -Path $d -ItemType Directory|Out-Null; $allUser+=$d } }
}

#----------------------------------------
# File Generation
#----------------------------------------
# Collect all dirs
$allDirs=Get-ChildItem -Path $rootPath -Directory -Recurse | Select-Object -ExpandProperty FullName
# Distribute specified number of files
$exts=@('.txt','.docx','.pdf','.log','.csv','.jpg','.png','.md')
1..$fileCount|ForEach-Object{ $d=Get-Random -InputObject $allDirs; $f=Join-Path $d ((Get-RandomName)+($exts|Get-Random)); [IO.File]::WriteAllBytes($f,(New-Object Byte[] (Get-Random -Minimum 1024 -Maximum 1048576))) }
# Ensure no empty
$allDirs|ForEach-Object{ if((Get-ChildItem -Path $_ -File).Count -eq 0){ $f=Join-Path $_ ((Get-RandomName)+'.txt'); [IO.File]::WriteAllBytes($f,(New-Object Byte[] 1024)) }}

#----------------------------------------
# Randomize Dates on all items
#----------------------------------------
Get-ChildItem -Path $rootPath -Recurse | ForEach-Object {
    $dt=Get-RandomDate -Start $dateStart -End $dateEnd
    try { Set-ItemProperty -Path $_.FullName -Name CreationTime -Value $dt; Set-ItemProperty -Path $_.FullName -Name LastWriteTime -Value $dt } catch {}
}

Write-Host 'Done: Structure created with files in all folders.'
