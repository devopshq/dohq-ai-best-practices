Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string]$KEY
)

Write-Host "##teamcity[blockOpened name='Import certificates']"

certutil -f -v -p $KEY -importpfx "<path/to/your/certs.pfx>"
certutil -f -v -p $KEY -importpfx root "<path/to/your/certs.pfx>"

Write-Host "##teamcity[blockOpened name='Import certificates to local machine']"
# ---------- Import to local machine ----------
Import-Certificate -FilePath <path/to/your/certs.pem.crt> -CertStoreLocation Cert:\LocalMachine\Root
Import-Certificate -FilePath <you-cert>.crt -CertStoreLocation Cert:\LocalMachine\Trust
Import-Certificate -FilePath <you-cert>.crt -CertStoreLocation Cert:\LocalMachine\CA
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\LocalMachine\Root
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\LocalMachine\Trust
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\LocalMachine\CA
Write-Host "##teamcity[blockClosed name='Import certificates to local machine']"


Write-Host "##teamcity[blockOpened name='Import certificates to Current User']"
# ---------- Import to Current User ----------
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\CurrentUser\Root
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\CurrentUser\Trust
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\CurrentUser\CA
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\CurrentUser\Root
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\CurrentUser\Trust
Import-Certificate -FilePath <you-cert>.pem.crt -CertStoreLocation Cert:\CurrentUser\CA
Write-Host "##teamcity[blockClosed name='Import certificates to Current User']"

Write-Host "##teamcity[blockClosed name='Import certificates']"
