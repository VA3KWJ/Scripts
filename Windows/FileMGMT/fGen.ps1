# Requires PowerShell 5.1+
# ---------------------------------------
# 1) Prompt for inputs
[string]$targetFolder = Read-Host "Enter target folder path"
if (-not (Test-Path -Path $targetFolder)) {
    Write-Host "Folder not found, creating: $targetFolder"
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

[int]$fileCount = 0
while ($fileCount -le 0) {
    $fileCount = Read-Host "Enter number of random files to generate"
    if (-not [int]::TryParse($fileCount, [ref]$null) -or $fileCount -le 0) {
        Write-Warning "Please enter a positive integer."
        $fileCount = 0
    }
}

[string]$startDateInput = Read-Host "Enter start creation date (yyyy-MM-dd)"
[string]$endDateInput   = Read-Host "Enter end   creation date (yyyy-MM-dd)"
try {
    [DateTime]$startDate = [DateTime]::ParseExact($startDateInput, 'yyyy-MM-dd', $null)
    [DateTime]$endDate   = [DateTime]::ParseExact($endDateInput,   'yyyy-MM-dd', $null)
} catch {
    Write-Error "Invalid date format. Use yyyy-MM-dd."
    exit
}
if ($endDate -lt $startDate) {
    Write-Error "End date must be on or after start date."
    exit
}

# 2) Precompute the total-seconds range as an integer
[int]$maxSeconds = [int](($endDate - $startDate).TotalSeconds)
if ($maxSeconds -lt 1) {
    Write-Error "Date range too small to generate random timestamps."
    exit
}

# 3) Size bounds
$minSize = 1MB
$maxSize = 50MB

# 4) Character set for extensions
$extChars = 'abcdefghijklmnopqrstuvwxyz0123456789'

# 5) Generate files
for ($i = 1; $i -le $fileCount; $i++) {
    # a) Random size
    $size = Get-Random -Minimum $minSize -Maximum $maxSize

    # b) Random extension (3–5 chars)
    $extLength = Get-Random -Minimum 3 -Maximum 6
    $extension = -join (1..$extLength | ForEach-Object {
        $extChars[(Get-Random -Minimum 0 -Maximum $extChars.Length)]
    })

    # c) Filename & path
    $filename = "{0}.{1}" -f ([guid]::NewGuid()), $extension
    $filePath = Join-Path $targetFolder $filename

    # d) Fill with random data
    $bytes = New-Object byte[] $size
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [System.IO.File]::WriteAllBytes($filePath, $bytes)

    # e) Choose a random second offset and compute timestamp
    $randSeconds = Get-Random -Minimum 0 -Maximum $maxSeconds
    $randomDate  = $startDate.AddSeconds($randSeconds)

    # f) Apply file times
    $item = Get-Item $filePath
    $item.CreationTime   = $randomDate
    $item.LastWriteTime  = $randomDate

    Write-Verbose "[$i/$fileCount] '$filename' – $([math]::Round($size/1MB,2)) MB – $randomDate"
}

Write-Host "Done! Created $fileCount files in '$targetFolder'."
