param()

function Get-RandomName {
    $length = Get-Random -Minimum 4 -Maximum 11
    $chars = 'abcdefghijklmnopqrstuvwxyz'
    $arr = for ($i = 0; $i -lt $length; $i++) { $chars.ToCharArray() | Get-Random }
    $name = -join $arr
    return $name.Substring(0,1).ToUpper() + $name.Substring(1)
}

function Get-RandomDate {
    param(
        [DateTime]$Start,
        [DateTime]$End
    )
    $range = $End - $Start
    return $Start.AddTicks((Get-Random -Minimum 0 -Maximum $range.Ticks))
}

Write-Host "=== Fake OS/Data File Generator ==="
[string]$rootPath    = Read-Host "Enter the root directory path for creation"
[string]$mode        = Read-Host "Create Full OS structure? (Y/N). Enter 'Y' for Full OS or 'N' for Data" | ForEach-Object { $_.Trim().ToUpper() }
[int]$fileCount      = Read-Host "Enter the number of files to create"
[int]$folderCount    = Read-Host "Enter the number of folders to create"
[DateTime]$dateStart = Read-Host "Enter the start date (yyyy-MM-dd)" | ForEach-Object { [DateTime]$_ }
[DateTime]$dateEnd   = Read-Host "Enter the end date (yyyy-MM-dd)"   | ForEach-Object { [DateTime]$_ }

# Ensure root
if (-Not (Test-Path $rootPath)) { New-Item -Path $rootPath -ItemType Directory -Force | Out-Null }

# Define extensions
$specialExts     = @('.exe', '.dll')
$accompanyExts   = @('.log', '.jpg', '.txt', '.pdf')

# Prepare application folders list
$appFolders = @()

if ($mode -eq 'Y') {
    # Full OS mode
    # Ensure Program Files folders
    $prog1 = Join-Path $rootPath 'Program Files'
    $prog2 = Join-Path $rootPath 'Program Files (x86)'
    foreach ($p in @($prog1, $prog2)) {
        if (-Not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    }
    # Single parent application folder
    $rootApp = Join-Path $rootPath ('App-' + (Get-RandomName))
    New-Item -Path $rootApp -ItemType Directory -Force | Out-Null
    $appFolders = @($prog1, $prog2, $rootApp)
} else {
    # Data mode
    $incApps = Read-Host "Include applications? (Y/N)" | ForEach-Object { $_.Trim().ToUpper() }
    if ($incApps -eq 'Y') {
        [int]$numAppDirs = Read-Host "Number of Application Directories?"
        for ($i = 1; $i -le $numAppDirs; $i++) {
            $dir = 'App-' + (Get-RandomName)
            $path = Join-Path $rootPath $dir
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            $appFolders += $path
        }
    }
}

# Function to generate application files in a folder
function New-AppFiles {
    param([string]$Folder)
    # 1 exe
    $exeName = (Get-RandomName) + '.exe'
    $exePath = Join-Path $Folder $exeName
    [IO.File]::WriteAllBytes($exePath, (New-Object Byte[] (Get-Random -Minimum 131072 -Maximum 10485760)))
    Set-ItemProperty -Path $exePath -Name CreationTime  -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
    Set-ItemProperty -Path $exePath -Name LastWriteTime -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
    # 2-5 dll
    for ($j = 1; $j -le (Get-Random -Minimum 2 -Maximum 6); $j++) {
        $dll = (Get-RandomName) + '.dll'
        $p = Join-Path $Folder $dll
        [IO.File]::WriteAllBytes($p, (New-Object Byte[] (Get-Random -Minimum 131072 -Maximum 10485760)))
        Set-ItemProperty -Path $p -Name CreationTime  -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
        Set-ItemProperty -Path $p -Name LastWriteTime -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
    }
    # 2-10 accompanying
    for ($k = 1; $k -le (Get-Random -Minimum 2 -Maximum 11); $k++) {
        $ext = $accompanyExts | Get-Random
        $fn = (Get-RandomName) + $ext
        $p2 = Join-Path $Folder $fn
        [IO.File]::WriteAllBytes($p2, (New-Object Byte[] (Get-Random -Minimum 131072 -Maximum 10485760)))
        Set-ItemProperty -Path $p2 -Name CreationTime  -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
        Set-ItemProperty -Path $p2 -Name LastWriteTime -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
    }
}

# Generate application files
foreach ($af in $appFolders) { New-AppFiles -Folder $af }

# Create random folders up to 3 levels
function Create-RandomFolders {
    param([string]$Base, [int]$Count)
    $list = New-Object System.Collections.ArrayList
    [void]$list.Add($Base)
    $created = 0
    while ($created -lt $Count) {
        $parent = Get-Random -InputObject $list
        $rel = $parent.Substring($rootPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
        $parts = if ($rel) { $rel.Split([IO.Path]::DirectorySeparatorChar) } else { @() }
        if ($parts.Length -lt 3) {
            $nf = Join-Path $parent (Get-RandomName)
            if (-Not (Test-Path $nf)) {
                New-Item -Path $nf -ItemType Directory -Force | Out-Null
                [void]$list.Add($nf)
                $created++
            }
        }
    }
    return $list
}

Write-Host "Creating $folderCount random folders..."
$allFolders = Create-RandomFolders -Base $rootPath -Count $folderCount
# Exclude application folders
$nonApp = $allFolders | Where-Object { $appFolders -notcontains $_ }

# Random files in non-app folders
Write-Host "Creating $fileCount random files..."
for ($i = 1; $i -le $fileCount; $i++) {
    $f = Get-Random -InputObject $nonApp
    $extsNonApp = @('.txt','.docx','.pdf','.log','.csv','.jpg','.png','.md')
    $e = $extsNonApp | Get-Random
    $fn = (Get-RandomName) + $e
    $fp = Join-Path $f $fn
    [IO.File]::WriteAllBytes($fp, (New-Object Byte[] (Get-Random -Minimum 1024 -Maximum 1048576)))
    Set-ItemProperty -Path $fp -Name CreationTime  -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
    Set-ItemProperty -Path $fp -Name LastWriteTime -Value (Get-RandomDate -Start $dateStart -End $dateEnd)
}

Write-Host "Done: Created application files in $($appFolders.Count) app folders, $folderCount random folders, and $fileCount random files under $rootPath."
