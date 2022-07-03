function Set-CliSwitch {
    param(
        [Switch] $MalwareDev,
        [Switch] $CloudDev,
        [Switch] $Win10Ent
    )
    $image = $MalwareDev ? "Malware" : $CloudDev ? "Cloud" : $Win10Ent ? "Win10Ent" : "Win10"
    Write-Output "Image selected is $image"
}