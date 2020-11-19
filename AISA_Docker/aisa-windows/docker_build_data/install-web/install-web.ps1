Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$URL,
	
    [Parameter(Mandatory=$True,Position=2)]
    [string]$Filename,

    [Parameter(Mandatory=$True,Position=3)]
    [string]$InstallArgs
)

$ErrorActionPreference = 'Stop' 
Write-Host "##teamcity[blockOpened name='Install']"

$tmp = $env:TEMP

$url_extension = $URL.Split('.')[-1]
if ($url_extension -eq "zip"){
    # Prepare
    $zip_name = $URL.Split('/')[-1]
    $zip_fullname = "$tmp\$zip_name"
    $folder = $zip_fullname -replace '.zip'

    # Download
    Write-Host "Download $URL to $zip_fullname"
    $wc = New-Object net.webclient
    $wc.Downloadfile($URL, $zip_fullname)

    # Unpack
    Write-Host "Unpack $zip_fullname to $folder"
    Expand-Archive $zip_fullname $tmp
    Get-ChildItem $folder

    # Set variables
    $fullpath = "$folder\$Filename"
}
else{
    # Prepare
    $fullpath = "$env:TEMP\$filename"

    # Download
    Write-Host "Download $URL to $fullpath"
    $wc = New-Object net.webclient
    $wc.Downloadfile($URL, $fullpath)
}

$extension = $fullpath.Split('.')[-1]
if ($extension -eq "exe"){ 
	Write-Host "Run: $fullpath  $InstallArgs"
    Start-Process $fullpath -ArgumentList $InstallArgs -Wait 
}

if ($extension -eq "msi"){ 
    Write-Host "Run: msiexec.exe /I $fullpath  $InstallArgs"
	Start-Process msiexec.exe -ArgumentList "/I $fullpath $InstallArgs" -Wait 
}

Write-Host "##teamcity[blockOpened name='Clean']"
Remove-Item $fullpath -Force -Verbose
Remove-Item $env:temp\* -Force -Verbose -Recurse
Write-Host "##teamcity[blockClosed name='Clean']"

Write-Host "##teamcity[blockClosed name='Install']"
