Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string]$PKG,

    [Parameter(Mandatory = $True, Position = 2)]
    [string]$UnpackTo,

    [Parameter(Mandatory = $True, Position = 3)]
    [string]$Login,

    [Parameter(Mandatory = $True, Position = 4)]
    [string]$Key
)

$ErrorActionPreference = 'Stop'
Write-Host "##teamcity[blockOpened name='Download']"

# Generate URL to artifactory
Write-Host "Aisa package version is $PKG"
Write-Host "Aisa package is $PKG"

$ARTIFACTORY_URL = "https://repo.artifactory.com:443"
$ARTIFACTORY_REPO = "your_repo"
$URL = $ARTIFACTORY_URL + '/' + $ARTIFACTORY_REPO + '/' + $PKG
Write-Host $URL

$tmp = $env:TEMP

$url_extension = $URL.Split('.')[-1]

Write-Host "URL Extension is $url_extension"

if ($url_extension -eq "zip")
{
    Write-Host "URL Extension is $url_extension"
    # Prepare
    $zip_name = $URL.Split('/')[-1]
    $zip_fullname = "$tmp\$zip_name"

    # Download
    Write-Host "Download $URL to $zip_fullname"
    $wc = New-Object net.webclient # System.Net.WebClient
    $wc.Credentials = new-object System.Net.NetworkCredential($Login, $Key)
    $wc.Downloadfile($URL, $zip_fullname)

    # Unpack
    Write-Host "Unpack $zip_fullname to $UnpackTo"
    Expand-Archive $zip_fullname $UnpackTo
}

Write-Host "##teamcity[blockOpened name='Clean']"
Remove-Item $env:temp\* -Force -Verbose -Recurse
Write-Host "##teamcity[blockClosed name='Clean']"

Write-Host "##teamcity[blockClosed name='Download']"
