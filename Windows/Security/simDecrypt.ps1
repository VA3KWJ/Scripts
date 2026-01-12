$TargetDirectory = "C:\SimulatedData"
$EncryptedExtension = ".LOCKED"

Get-ChildItem -Path $TargetDirectory -Recurse | Where-Object { $_.Name -like "*$EncryptedExtension" } | ForEach-Object {
    $OriginalName = $_.Name.Replace($EncryptedExtension, "")
    Rename-Item -Path $_.FullName -NewName $OriginalName
}
