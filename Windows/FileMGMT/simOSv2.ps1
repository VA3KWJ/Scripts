<#
.SCRIPT       simOSv2.ps1
.DESCRIPTION  Generates a simulated OS or data partition structure with realistic directories and valid file headers.
.INITIALDATE  2025-06-25
.LASTREVISION 2026-01-13
.VERSION      2.1 - Added Default Values for User Prompts
.GITHUB       https://github.com/VA3KWJ
#>

param()

# Load required assembly for Image generation
Add-Type -AssemblyName System.Drawing

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

function New-SimulatedFile {
    param(
        [string]$Path,
        [string]$Extension
    )

    $Extension = $Extension.ToLower().Trim('.')

    switch ($Extension) {
        # --- DOCUMENT FILES ---
        { $_ -in 'txt','log','md' } {
            $lines = 1..(Get-Random -Min 5 -Max 50) | ForEach-Object {
                "[{0:yyyy-MM-dd HH:mm:ss}] [INFO] Process {1} executed operation {2}." -f (Get-Date), (Get-Random -Min 100 -Max 999), (Get-RandomName)
            }
            if ($Extension -eq 'md') { $lines = "# Simulation Log`n`n" + ($lines -join "`n* ") }
            $lines | Set-Content -Path $Path -Force
        }

        'csv' {
            $headers = "ID,Name,Date,Value,Status"
            $rows = 1..(Get-Random -Min 10 -Max 50) | ForEach-Object {
                "{0},{1},{2},{3},{4}" -f $_, (Get-RandomName), (Get-Date -Format 'yyyy-MM-dd'), (Get-Random -Min 100 -Max 9000), "Active"
            }
            ($headers + "`n" + ($rows -join "`n")) | Set-Content -Path $Path -Force
        }

        # --- OFFICE FILES (Spoofed using RTF and HTML-Table) ---
        { $_ -in 'doc','docx' } {
            # valid RTF header
            $content = "{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\f0\fs24\b Generated Document \b0\par This is a valid simulated document created on $(Get-Date).\par \par ID: $(Get-Random)}"
            Set-Content -Path $Path -Value $content -Force
        }

        { $_ -in 'xls','xlsx' } {
            # valid HTML Table (Excel opens this)
            $content = "<html><body><table border='1'><tr><th>ID</th><th>Data</th></tr><tr><td>101</td><td>$(Get-RandomName)</td></tr><tr><td>102</td><td>$(Get-RandomName)</td></tr></table></body></html>"
            Set-Content -Path $Path -Value $content -Force
        }

        # --- IMAGES ---
        { $_ -in 'jpg','jpeg','png','bmp' } {
            try {
                $width  = Get-Random -Min 100 -Max 800
                $height = Get-Random -Min 100 -Max 600
                $bmp = New-Object System.Drawing.Bitmap $width, $height
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb((Get-Random -Max 255),(Get-Random -Max 255),(Get-Random -Max 255)))
                $g.FillRectangle($brush, 0, 0, $width, $height)

                $format = if ($_ -eq 'png') { [System.Drawing.Imaging.ImageFormat]::Png } else { [System.Drawing.Imaging.ImageFormat]::Jpeg }
                $bmp.Save($Path, $format)

                $g.Dispose(); $bmp.Dispose(); $brush.Dispose()
            } catch {
                # Fallback if GDI fails
                Set-Content -Path $Path -Value "Image Placeholder"
            }
        }

        # --- PDF ---
        'pdf' {
            # Minimal PDF 1.4 Header
            $content = "%PDF-1.4`n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj`n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj`n3 0 obj<</Type/Page/MediaBox[0 0 595 842]/Parent 2 0 R/Resources<<>>/Contents 4 0 R>>endobj`n4 0 obj<</Length 24>>stream`nBT /F1 24 Tf 100 700 Td (Simulated PDF Content) Tj ET`nendstream`nendobj`nxref`n0 5`n0000000000 65535 f `n0000000010 00000 n `n0000000060 00000 n `n0000000117 00000 n `n0000000234 00000 n `ntrailer<</Size 5/Root 1 0 R>>`nstartxref`n307`n%%EOF"
            [IO.File]::WriteAllText($Path, $content)
        }

        # --- BINARIES / DEFAULTS ---
        Default {
            # Write random bytes for EXE, DLL, SYS, etc.
            [IO.File]::WriteAllBytes($Path, (New-Object Byte[] (Get-Random -Minimum 1024 -Maximum 10240)))
        }
    }
}

function New-AppFiles {
    param([string]$Folder)
    if (-Not (Test-Path $Folder)) { return }
    # 1 exe (Random bytes)
    $exe = Join-Path $Folder ((Get-RandomName)+'.exe')
    New-SimulatedFile -Path $exe -Extension 'exe'

    # 2-5 DLL files (Random bytes)
    for ($i=1; $i -le (Get-Random -Minimum 2 -Maximum 5); $i++) {
        $dll = Join-Path $Folder ((Get-RandomName)+'.dll')
        New-SimulatedFile -Path $dll -Extension 'dll'
    }

    # 2-10 accompanying files (Valid Formats)
    $exts = @('.log','.jpg','.txt','.pdf','.csv')
    for ($i=1; $i -le (Get-Random -Minimum 2 -Maximum 10); $i++) {
        $ext = $exts | Get-Random
        $file = Join-Path $Folder ((Get-RandomName)+$ext)
        New-SimulatedFile -Path $file -Extension $ext
    }

    # 1-3 subfolders
    for ($i=1; $i -le (Get-Random -Minimum 1 -Maximum 3); $i++) {
        $sub = Join-Path $Folder (Get-RandomName)
        New-Item -Path $sub -ItemType Directory -Force | Out-Null
    }
}

#----------------------------------------
# User Prompts (With Defaults)
#----------------------------------------
Write-Host '=== Fake OS/Data File Generator (Valid Headers) ===' -ForegroundColor Cyan

# 1. Root Path (Default: C:\SimulatedData)
$defRoot = 'C:\SimulatedData'
$inRoot = Read-Host "Enter the root directory path [$defRoot]"
if ([string]::IsNullOrWhiteSpace($inRoot)) { $rootPath = $defRoot } else { $rootPath = $inRoot }

# 2. Mode (Default: N)
$defMode = 'N'
$inMode = Read-Host "Create Full OS structure? (Y/N) [$defMode]"
if ([string]::IsNullOrWhiteSpace($inMode)) { $mode = $defMode } else { $mode = $inMode.Trim().ToUpper() }

# 3. File Count (Default: 100)
$defFile = 100
$inFile = Read-Host "Enter the number of general files to create [$defFile]"
if ([string]::IsNullOrWhiteSpace($inFile)) { $fileCount = $defFile } else { $fileCount = [int]$inFile }

# 4. Folder Count (Default: 5)
$defFolder = 5
$inFolder = Read-Host "Enter the number of user folders to create [$defFolder]"
if ([string]::IsNullOrWhiteSpace($inFolder)) { $folderCount = $defFolder } else { $folderCount = [int]$inFolder }

# 5. Start Date (Default: 5 years ago)
$defStart = (Get-Date).AddYears(-5).ToString('yyyy-MM-dd')
$inStart = Read-Host "Enter the start date (yyyy-MM-dd) [$defStart]"
if ([string]::IsNullOrWhiteSpace($inStart)) { $dateStart = [DateTime]$defStart } else { $dateStart = [DateTime]$inStart }

# 6. End Date (Default: Today)
$defEnd = (Get-Date).ToString('yyyy-MM-dd')
$inEnd = Read-Host "Enter the end date (yyyy-MM-dd) [$defEnd]"
if ([string]::IsNullOrWhiteSpace($inEnd)) { $dateEnd = [DateTime]$defEnd } else { $dateEnd = [DateTime]$inEnd }


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
    $pdBase = Join-Path $rootPath 'ProgramData'; $pdExts=@('.exe','.dll','.log','.dat','.txt')
    1..3|ForEach-Object{
        $sub=Join-Path $pdBase (Get-RandomName);
        New-Item -Path $sub -ItemType Directory -Force|Out-Null;
        1..(Get-Random -Min 5 -Max 10)|ForEach-Object{
            $ext = $pdExts|Get-Random
            $f=Join-Path $sub ((Get-RandomName)+$ext)
            New-SimulatedFile -Path $f -Extension $ext
        }
    }
    # Windows & System32 (Keep these mostly random binary/sys)
    $we=@('.exe','.dll','.log','.bin','.ini','.dat','.sys')
    foreach ($sub in @('Windows','Windows\System32')) {
        $b=Join-Path $rootPath $sub;
        1..(Get-Random -Min 10 -Max 20)|ForEach-Object{
            $ext = $we|Get-Random
            $f=Join-Path $b ((Get-RandomName)+$ext);
            New-SimulatedFile -Path $f -Extension $ext
        }
    }
    # Temp
    $tmp=Join-Path $rootPath 'temp'; $te=@('.tmp','.log','.txt')
    1..(Get-Random -Min 5 -Max 15)|ForEach-Object{
        $ext = $te|Get-Random
        $f=Join-Path $tmp ((Get-RandomName)+$ext);
        New-SimulatedFile -Path $f -Extension $ext
    }

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
    # Data Mode: Create Applications prompt (Default N)
    $defApps = 'N'
    $inApps = Read-Host "Create Applications? (Y/N) [$defApps]"
    if ([string]::IsNullOrWhiteSpace($inApps)) { $createApps = $defApps } else { $createApps = $inApps.Trim().ToUpper() }

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
Write-Host "Generating $fileCount files (this may take a moment)..." -ForegroundColor Yellow

# Collect all dirs
$allDirs=Get-ChildItem -Path $rootPath -Directory -Recurse | Select-Object -ExpandProperty FullName
# Distribute specified number of files
$exts=@('.txt','.doc','.xls','.pdf','.log','.csv','.jpg','.md')

1..$fileCount|ForEach-Object{
    $d=Get-Random -InputObject $allDirs;
    $ext = $exts|Get-Random
    $f=Join-Path $d ((Get-RandomName)+$ext);
    New-SimulatedFile -Path $f -Extension $ext
}

# Ensure no empty folders (add a readme txt)
$allDirs|ForEach-Object{
    if((Get-ChildItem -Path $_ -File).Count -eq 0){
        $f=Join-Path $_ 'ReadMe.txt';
        New-SimulatedFile -Path $f -Extension 'txt'
    }
}

#----------------------------------------
# Randomize Dates on all items
#----------------------------------------
Write-Host "Randomizing Timestamps..." -ForegroundColor Yellow
Get-ChildItem -Path $rootPath -Recurse | ForEach-Object {
    $dt=Get-RandomDate -Start $dateStart -End $dateEnd
    try { Set-ItemProperty -Path $_.FullName -Name CreationTime -Value $dt; Set-ItemProperty -Path $_.FullName -Name LastWriteTime -Value $dt } catch {}
}

Write-Host 'Done: Structure created with VALID file headers in all folders.' -ForegroundColor Green
