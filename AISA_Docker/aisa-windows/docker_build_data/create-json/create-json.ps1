Write-Host "##teamcity[blockOpened name='Create-json']"

Write-Host "[DEBUG]: Aisa URI:    $( ${env:AISA_URI} )"
Write-Host "[DEBUG]: Aisa Token:  $( ${env:AISA_TOKEN} )"

Write-Host "##teamcity[blockOpened name='Generate-json']"
Remove-Item 'C:\Program Files (x86)\Positive Technologies\Application Inspector Agent Shell\appSettings.user.json'
Write-Output "{`"ServerConnectSettings`":{`"EnterpriseApiUri`":`"$( ${env:AISA_URI} )`",`"AccessToken`":`"$( ${env:AISA_TOKEN} )`"}}" >> 'C:\Program Files (x86)\Positive Technologies\Application Inspector Agent Shell\appSettings.user.json'

Write-Host "##teamcity[blockOpened name='Verify appSettings.user.json']"
cat 'C:\Program Files (x86)\Positive Technologies\Application Inspector Agent Shell\appSettings.user.json'
Write-Host "##teamcity[blockClosed name='Verify appSettings.user.json']"

Write-Host "##teamcity[blockClosed name='Generate-json']"
