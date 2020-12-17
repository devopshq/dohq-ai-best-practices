#Requires -RunAsAdministrator

# Инсталлятор AI Enterprise и его окружения
# версия 1.5 от 17.12.2020
# (c) DevOpsHQ, 2020
# (c) alexkhudyshkin, 2020

Param (
[string]$aiepath, # путь к каталогу с дистрибутивом AIE
[string]$toolspath, # путь к каталогу, куда будут помещены артефакты инсталляции (логи, пароли) (по умолчанию - C:\AI-TOOLS)
[switch]$skipagent, # пропустить этап установки агента сканирования
[bool]$noad = 0, # установка с подключением к домену (0) или без (1)
[string]$addadmin, # добавить администратора AI вручную по SID
[switch]$uninstall, # полностью удалить AI Server и AI Agent вместе с зависимыми компонентами
# параметры ниже могут быть не заданы - тогда будут сгенерированы самоподписанные сертификаты
[string]$rootcertpath, # путь к корневому сертификату (pfx/crt)
[string]$rootcertpass, # пароль от корневого сертификата (pfx)
[string]$intcertpath, # путь к промежуточному сертификату (pfx/crt)
[string]$intcertpass, # пароль от промежуточного сертификата (pfx)
[string]$servercertpath, # путь к сертификату сервера AI (pfx)
[string]$servercertpass # пароль от сертификата сервера AI (pfx)
)


# проверяем версию NetFramework
function Check-NetFramework-Version {
	$nfver = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version,Release -EA 0 | Where { $_.PSChildName -match '^(?!S)\p{L}'} | Select Release
	for ($i=0; $i -lt $nfver.Length; $i++) {
		# 4.7.2 или выше
		if ($nfver[$i].Release -ge 461808) {
			[bool] $passed = 1
		}
	}
	if ($passed -eq $null) {
		Write-Host 'Ошибка: пожалуйста, обновите версию Net Framework до 4.7.2 или выше, а затем перезапустите скрипт.' -ForegroundColor Red
		Write-Host 'https://dotnet.microsoft.com/download/dotnet-framework/thank-you/net48-offline-installer'
		Stop-Transcript
		Exit 1
	}
}

# выясняем название текущей версии дистрибутива из каталога
function Get-Current-Version-Path([string]$path, [string]$mask) {
	$filename = $path+'\'+(Get-ChildItem "$($path)\$($mask)").Name
	if (-Not (Test-Path $filename)) {
		Write-Host "Ошибка: файл $($mask) не найден в каталоге $($path). Возможно, вы некорректно указали параметр aiepath." -ForegroundColor Red
		Stop-Transcript
		Exit 1
	}
	# разблокируем исполняемый файл для запуска
	Get-Item $filename | Unblock-File
	return $filename
}

# Обработка результата установки дистрибутива
function Handle-Install-Result($name, $proc, $mode="установке") {
	Wait-Process $proc.Id
	if ($proc.ExitCode -ne 0) {
		Write-Host "Ошибка: что-то пошло не так при $($mode) $($name), код выхода $($proc.ExitCode). " -ForegroundColor Red	
		Stop-Transcript
		Exit 1
	}
}

# генерация сложных паролей
function Generate-Password {
	function Get-RandomCharacters($length, $characters) {
		$random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
		$private:ofs=""
		return [String]$characters[$random]
	}
	
	function Scramble-String([string]$inputString){     
		$characterArray = $inputString.ToCharArray()   
		$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
		$outputString = -join $scrambledStringArray
		return $outputString 
	}
	
	$password = Get-RandomCharacters -length 15 -characters 'abcdefghiklmnoprstuvwxyzABCDEFGHKLMNOPRSTUVWXYZ1234567890!*()[]_+'
	return Scramble-String $password
}

# скопировать логи AIE
function Copy-AIE-Logs($ServiceDownList) {
	for ($i=0; $i -lt $ServiceDownList.Count; $i++) {
		switch ($ServiceDownList[$i]) {
			"AI.DescriptionsService" 				{ xcopy "C:\ProgramData\Application Inspector\Logs\descriptionsService" $toolspath\logs\descriptionsService\ /E /Y }
			"AI.Enterprise.AuthService" 			{ xcopy "C:\ProgramData\Application Inspector\Logs\authService" $toolspath\logs\authService\ /E /Y }
			"AI.Enterprise.ChangeHistory" 			{ xcopy "C:\ProgramData\Application Inspector\Logs\changeHistoryService" $toolspath\logs\changeHistoryService\ /E /Y }
			"AI.Enterprise.FileContent.API" 		{ xcopy "C:\ProgramData\Application Inspector\Logs\filesStore" $toolspath\logs\filesStore\ /E /Y }
			"AI.Enterprise.Gateway" 				{ xcopy "C:\ProgramData\Application Inspector\Logs\gateway" $toolspath\logs\gateway\ /E /Y }
			"AI.Enterprise.IssueTracker" 			{ xcopy "C:\ProgramData\Application Inspector\Logs\issueTracker" $toolspath\logs\issueTracker\ /E /Y }
			"AI.Enterprise.NotificationsService" 	{ xcopy "C:\ProgramData\Application Inspector\Logs\notificationsService" $toolspath\logs\notificationsService\ /E /Y }
			"AI.Enterprise.Projects.API" 			{ xcopy "C:\ProgramData\Application Inspector\Logs\projectManagement" $toolspath\logs\projectManagement\ /E /Y }
			"AI.Enterprise.SettingsProvider.API" 	{ xcopy "C:\ProgramData\Application Inspector\Logs\settingsProvider" $toolspath\logs\settingsProvider\ /E /Y }
			"AI.Enterprise.SystemManagement" 		{ xcopy "C:\ProgramData\Application Inspector\Logs\systemManagement" $toolspath\logs\systemManagement\ /E /Y }
			"AI.Enterprise.UI" 						{ xcopy "C:\ProgramData\Application Inspector\Logs\uiApi" $toolspath\logs\uiApi\ /E /Y }
			"AI.Enterprise.UpdateServer" 			{ xcopy "C:\ProgramData\Application Inspector\Logs\updateServer" $toolspath\logs\updateServer\ /E /Y }
			"Consul" 								{ Write-Host "ERROR: Consul is down" -ForegroundColor Red }
			"RabbitMQ" 								{ Write-Host "ERROR: RabbitMQ is down" -ForegroundColor Red }
			"PostgreSQL" 							{ Write-Host "ERROR: PostgreSQL is down" -ForegroundColor Red }
		}
	}
	xcopy "C:\ProgramData\Application Inspector\Logs\consul" $toolspath\logs\consul\ /E /Y
	xcopy "C:\ProgramData\Application Inspector\Logs\consulTool" $toolspath\logs\consulTool\ /E /Y 
}

# добавить текущего пользователя в качестве администратора AI через запрос в базу данных
function AI-Add-Admin($sid) {
	$env:PGPASSWORD = $passwords['postgres']
	."C:\Program Files\PostgreSQL\10\bin\psql.exe" -h 127.0.0.1 -p 5432 -U postgres -d ai_csi -c "INSERT INTO \`"GlobalMemberEntity\`" (\`"Sid\`", \`"RoleId\`") VALUES ('$sid', '1');"
	# рестарт службы аутентификации
	net stop AI.Enterprise.AuthService
	net start AI.Enterprise.AuthService
	Start-Sleep 10
}

# генерация самоподписанных сертификатов
function Generate-SelfsignedCerts($noad, $toolspath) {
	# root_ca.conf
	$root_conf = @"
# Net173 Root CA

[ default ]
ca                      = RootCA                    # CA name
dir                     = %toolspath%/certs/ROOT # Top dir
name_opt                = multiline,-esc_msb,utf8   # Display UTF-8 characters

# CA certificate request

[ req ]
default_bits            = 4096                  # RSA key size
encrypt_key             = yes                   # Protect private key
default_md              = sha1                  # MD to use
utf8                    = yes                   # Input is UTF-8
string_mask             = utf8only              # Emit UTF-8 strings
prompt                  = no                    # Don't prompt for DN
distinguished_name      = ca_dn                 # DN section
req_extensions          = ca_reqext             # Desired extensions

[ ca_dn ]
organizationName        = "test.com"
commonName              = "test.com Root CA"

[ ca_reqext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true
subjectKeyIdentifier    = hash

# CA operational settings

[ ca ]
default_ca              = CA                    # The default CA section

[ CA ]
certificate             = `$dir/certs/`$ca.pem.crt    # The CA cert
private_key             = `$dir/private/`$ca.pem.key  # CA private key
new_certs_dir           = `$dir/newcerts             # Certificate archive
serial                  = `$dir/db/`$ca.crt.srl       # Serial number file
crlnumber               = `$dir/db/`$ca.crl.srl       # CRL number file
database                = `$dir/db/`$ca.db            # Index file
unique_subject          = no                        # Require unique subject
default_days            = 7305                      # How long to certify for
default_md              = sha256                    # MD to use
policy                  = match_pol                 # Default naming policy
email_in_dn             = no                        # Add email to cert DN
preserve                = no                        # Keep passed DN ordering
name_opt                = `$name_opt                 # Subject DN display options
cert_opt                = ca_default                # Certificate display options
copy_extensions         = none                      # Copy extensions from CSR
x509_extensions         = signing_ca_ext            # Default cert extensions
default_crl_days        = 7305                      # How long before next CRL
crl_extensions          = crl_ext                   # CRL extensions

[ match_pol ]
organizationName        = match
commonName              = match

[ extern_pol ]
organizationName        = match
commonName              = supplied              # Must be present

# Extensions

# Used to generate self-signed Root CA certificate 
[ root_ca_ext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

# Used to sign Intermediate CA certificate 
[ signing_ca_ext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true,pathlen:0
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
"@

	# int_ca.conf
	$int_conf = @"
# Net173 Intermediate CA

[ default ]
ca                      = IntermediateCA             # CA name
dir                     = %toolspath%/certs/INT # Top dir
name_opt                = multiline,-esc_msb,utf8 # Display UTF-8 characters

# CA certificate request

[ req ]
default_bits            = 4096                  # RSA key size
encrypt_key             = yes                   # Protect private key
default_md              = sha1                  # MD to use
utf8                    = yes                   # Input is UTF-8
string_mask             = utf8only              # Emit UTF-8 strings
prompt                  = no                    # Don't prompt for DN
distinguished_name      = ca_dn                 # DN section
req_extensions          = ca_reqext             # Desired extensions

[ ca_dn ]
organizationName        = "test.com"
commonName              = "test.com Intermediate CA"

[ ca_reqext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true,pathlen:0
subjectKeyIdentifier    = hash

# CA operational settings

[ ca ]
default_ca              = CA                    # The default CA section

[ CA ]
certificate             = `$dir/certs/`$ca.pem.crt    # The CA cert
private_key             = `$dir/private/`$ca.pem.key  # CA private key
new_certs_dir           = `$dir/newcerts             # Certificate archive
serial                  = `$dir/db/`$ca.crt.srl   # Serial number file
crlnumber               = `$dir/db/`$ca.crl.srl   # CRL number file
database                = `$dir/db/`$ca.db        # Index file
unique_subject          = no                    # Require unique subject
default_days            = 3652                  # How long to certify for
default_md              = sha256                # MD to use
policy                  = match_pol             # Default naming policy
email_in_dn             = no                    # Add email to cert DN
preserve                = no                    # Keep passed DN ordering
name_opt                = `$name_opt             # Subject DN display options
cert_opt                = ca_default            # Certificate display options
copy_extensions         = copy                  # Copy extensions from CSR
x509_extensions         = server_ext            # Default cert extensions
default_crl_days        = 730                   # How long before next CRL
crl_extensions          = crl_ext               # CRL extensions

[ match_pol ]
organizationName        = match
commonName              = match

[ extern_pol ]
organizationName        = supplied
commonName              = supplied              # Must be present

[ server_ext ]
keyUsage                = critical,digitalSignature,keyEncipherment
basicConstraints        = CA:false
extendedKeyUsage        = serverAuth,clientAuth
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

[ vpn_server_ext ]
keyUsage                = critical,digitalSignature,keyEncipherment
basicConstraints        = CA:false
extendedKeyUsage        = serverAuth
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always

[ rdp_server_ext ]
keyUsage                = critical,keyEncipherment,dataEncipherment
basicConstraints        = CA:false
extendedKeyUsage        = serverAuth
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

[ dc_ext ]
keyUsage                = critical,nonRepudiation,digitalSignature,keyEncipherment
basicConstraints        = CA:false
extendedKeyUsage        = serverAuth,clientAuth,1.3.6.1.5.2.3.5
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

[ client_ext ]
keyUsage                = critical,digitalSignature
basicConstraints        = CA:false
extendedKeyUsage        = clientAuth
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
"@
	
	# ssl.server.conf
	$int_server = @"
[ req ]
default_bits            = 4096                  # RSA key size
encrypt_key             = no                    # Protect private key
default_md              = sha256                # MD to use
utf8                    = yes                   # Input is UTF-8
string_mask             = utf8only              # Emit UTF-8 strings
prompt                  = no                    # Do not prompt for DN
distinguished_name      = req_dn                # DN template
req_extensions          = v3_req                # Desired extensions

[ req_dn ]
organizationName        = "test.com"
commonName              = test.com CI server #01

[ v3_req ]
keyUsage                = critical,digitalSignature,keyEncipherment
extendedKeyUsage        = serverAuth,clientAuth
subjectKeyIdentifier    = hash
subjectAltName          = DNS:localhost
nsCertType              = server
basicConstraints        = CA:FALSE
"@
	
	# задаём основные переменные
	$hostname = (Get-WmiObject win32_computersystem).DNSHostName
	if ($noad) {
		$current_domain = $hostname
		$IP = Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected"} | Select -ExpandProperty IPv4Address | Select -ExpandProperty IPAddress
	}
	else {
		$current_domain = (Get-WmiObject win32_computersystem).Domain
	}
	$tmppath = $toolspath -ireplace '\\',"/"
	# патчим конфиги
	if (-Not (Test-Path $toolspath\certs\conf)) {mkdir -p $toolspath\certs\conf >$null}
	$root_conf = $root_conf -ireplace 'test.com',"$current_domain"
	$root_conf = $root_conf -ireplace '%toolspath%',"$tmppath" | Set-Content -Path "$toolspath\certs\conf\root_ca.conf"

	$int_conf = $int_conf -ireplace 'test.com',"$current_domain"
	$int_conf = $int_conf -ireplace '%toolspath%',"$tmppath" | Set-Content -Path "$toolspath\certs\conf\int_ca.conf"
	
	$int_server = $int_server -ireplace 'test.com',"$current_domain"
	if ($noad) {
		$int_server -ireplace '(subjectAltName\s{1,}=\s{1,}DNS:)(.*)',"`$1$hostname,DNS:localhost,IP:$IP" | Set-Content -Path "$toolspath\certs\conf\ssl.server.conf"
	}
	else {
		$int_server -ireplace '(subjectAltName\s{1,}=\s{1,}DNS:)(.*)',"`$1$hostname.$current_domain,DNS:localhost" | Set-Content -Path "$toolspath\certs\conf\ssl.server.conf"
	}
	
	# ROOT
	$ROOT_CA_HOME = "$toolspath\certs\ROOT"
	$ROOT_CA_NAME = "RootCA"
	$ca_keylen = 4096
	$CA_CONF_DIR = "$toolspath\certs\conf"
	New-Item -Path "$ROOT_CA_HOME\private" -ItemType Directory | Out-Null
	New-Item -Path "$ROOT_CA_HOME\certs" -ItemType Directory | Out-Null
	New-Item -Path "$ROOT_CA_HOME\newcerts" -ItemType Directory | Out-Null
	New-Item -Path "$ROOT_CA_HOME\db" -ItemType Directory | Out-Null
	$uuid = '0000'
	New-Item "$ROOT_CA_HOME\db\$ROOT_CA_NAME.crt.srl" | Out-Null
	Set-Content "$ROOT_CA_HOME\db\$ROOT_CA_NAME.crt.srl" $uuid
	$uuid1 = '00'
	New-Item "$ROOT_CA_HOME\db\$ROOT_CA_NAME.crl.srl" | Out-Null
	Set-Content "$ROOT_CA_HOME\db\$ROOT_CA_NAME.crl.srl" $uuid1
	New-Item "$ROOT_CA_HOME\db\$ROOT_CA_NAME.db" | Out-Null
	New-Item "$ROOT_CA_HOME\db\$ROOT_CA_NAME.db.attr" | Out-Null
	
	# генерируем корневой сертификат
	openssl genrsa -out $ROOT_CA_HOME\private\$ROOT_CA_NAME.pem.key $ca_keylen 2>&1>$null
	openssl req -new -config $CA_CONF_DIR\root_ca.conf -out $ROOT_CA_HOME\$ROOT_CA_NAME.pem.csr -key $ROOT_CA_HOME\private\$ROOT_CA_NAME.pem.key 2>&1>$null
	openssl ca -selfsign -batch -config $CA_CONF_DIR\root_ca.conf -in $ROOT_CA_HOME\$ROOT_CA_NAME.pem.csr -out $ROOT_CA_HOME\certs\$ROOT_CA_NAME.pem.crt -extensions root_ca_ext -notext 2>&1>$null
	openssl x509 -outform DER -in $ROOT_CA_HOME\certs\$ROOT_CA_NAME.pem.crt -out $ROOT_CA_HOME\certs\$ROOT_CA_NAME.der.crt 2>&1>$null
	openssl ca -gencrl -batch -config $CA_CONF_DIR\root_ca.conf -out $ROOT_CA_HOME\$ROOT_CA_NAME.pem.crl 2>&1>$null
	openssl crl -in $ROOT_CA_HOME\$ROOT_CA_NAME.pem.crl -outform DER -out $ROOT_CA_HOME\$ROOT_CA_NAME.der.crl 2>&1>$null
	
	# INTER
	$INT_CA_HOME = "$toolspath\certs\INT"
	$INT_CA_NAME = "IntermediateCA"
	New-Item -Path "$INT_CA_HOME\private" -ItemType Directory | Out-Null
	New-Item -Path "$INT_CA_HOME\certs" -ItemType Directory | Out-Null
	New-Item -Path "$INT_CA_HOME\newcerts" -ItemType Directory | Out-Null
	New-Item -Path "$INT_CA_HOME\db" -ItemType Directory | Out-Null
	New-Item -Path "$INT_CA_HOME\out" -ItemType Directory | Out-Null
	$uuid = '0000'
	New-Item "$INT_CA_HOME\db\$INT_CA_NAME.crt.srl" | Out-Null
	Set-Content "$INT_CA_HOME\db\$INT_CA_NAME.crt.srl" $uuid
	$uuid1 = '00'
	New-Item "$INT_CA_HOME\db\$INT_CA_NAME.crl.srl" | Out-Null
	Set-Content "$INT_CA_HOME\db\$INT_CA_NAME.crl.srl" $uuid1
	New-Item "$INT_CA_HOME\db\$INT_CA_NAME.db" | Out-Null
	New-Item "$INT_CA_HOME\db\$INT_CA_NAME.db.attr" | Out-Null
	
	# генерируем промежуточный сертификат
	openssl genrsa -out $INT_CA_HOME\private\$INT_CA_NAME.pem.key $ca_keylen 2>&1>$null
	openssl req -new -config $CA_CONF_DIR\int_ca.conf -out $INT_CA_HOME\$INT_CA_NAME.pem.csr -key $INT_CA_HOME\private\$INT_CA_NAME.pem.key 2>&1>$null
	openssl ca -batch -config $CA_CONF_DIR\root_ca.conf -in $INT_CA_HOME\$INT_CA_NAME.pem.csr -out $INT_CA_HOME\certs\$INT_CA_NAME.pem.crt -extensions signing_ca_ext -policy extern_pol -notext 2>&1>$null
	openssl x509 -outform DER -in $INT_CA_HOME\certs\$INT_CA_NAME.pem.crt -out $INT_CA_HOME\certs\$INT_CA_NAME.der.crt 2>&1>$null
	openssl ca -gencrl -batch  -config $CA_CONF_DIR\int_ca.conf -out $INT_CA_HOME\$INT_CA_NAME.pem.crl 2>&1>$null
	openssl crl -in $INT_CA_HOME\$INT_CA_NAME.pem.crl -outform DER -out $INT_CA_HOME\$INT_CA_NAME.der.crl 2>&1>$null
	
	# ssl.server
	Remove-Item -path "$INT_CA_HOME\temp" -recurse -ErrorAction Ignore | Out-Null
	New-Item -Path "$INT_CA_HOME\temp" -ItemType Directory | Out-Null
	
	# генерируем серверный сертификат
	openssl req -new -config $CA_CONF_DIR\ssl.server.conf -out $INT_CA_HOME\temp\ssl.server.pem.csr -keyout $INT_CA_HOME\temp\ssl.server.pem.key 2>&1>$null
	openssl ca -batch -config $CA_CONF_DIR\int_ca.conf -in $INT_CA_HOME\temp\ssl.server.pem.csr -out $INT_CA_HOME\temp\ssl.server.pem.crt -policy extern_pol -extensions server_ext -notext 2>&1>$null
	$out = openssl x509 -in $INT_CA_HOME\temp\ssl.server.pem.crt -serial -noout
	$path = ([regex]"serial=([\d]{1,})").Matches($out)[0].Groups[1].Value
	$OUT_FOLDER_SRV = "$toolspath\certs\INT\out\$path"
	New-Item -Path "$OUT_FOLDER_SRV" -ItemType Directory | Out-Null
	Move-Item -Path "$INT_CA_HOME\temp\*" -Destination "$OUT_FOLDER_SRV" | Out-Null
	openssl x509 -outform DER -in $OUT_FOLDER_SRV\ssl.server.pem.crt -out $OUT_FOLDER_SRV\ssl.server.der.crt 2>&1>$null
	openssl pkcs12 -export -name "SSL server certificate" -inkey $OUT_FOLDER_SRV\ssl.server.pem.key -in $OUT_FOLDER_SRV\ssl.server.pem.crt -out $OUT_FOLDER_SRV\ssl.server.brief.pfx -password pass:"$($passwords['serverCertificate'])" 2>&1>$null
	openssl pkcs12 -in $OUT_FOLDER_SRV\ssl.server.brief.pfx -out $OUT_FOLDER_SRV\ssl.server.brief.pem -passin pass:"$($passwords['serverCertificate'])" -passout pass:"$($passwords['serverCertificate'])" 2>&1>$null
	
	Copy-Item $OUT_FOLDER_SRV\ssl.server.brief.pfx $toolspath\certs\aiserver.pfx | Out-Null
}

# ADTOOL - утилита проверки доступности домен контроллера (base64 -> exe)
$hex = "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LgBjAPIBLgBrABwCLgBzACkCGgCSAP8AFQFDAMQABIAAAAEAAAAAAAAAAAAAAAAA4gIAAAQAAAAAAAAAAAAAAEYBHwAAAAAABAAAAAAAAAAAAAAATwFoBAAAAAAEAAAAAAAAAAAAAABGAQ8BAAAAAAQAAAAAAAAAAAAAAEYB/wIAAAAAKwBdADEAXQAAAAAAAElFbnVtZXJhYmxlYDEATGlzdGAxADxNb2R1bGU+AG1zY29ybGliAFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljAGdldF9Qcm9wZXJ0aWVzVG9Mb2FkAEFkZABTeXN0ZW0uQ29sbGVjdGlvbnMuU3BlY2lhbGl6ZWQAZ2V0X01lc3NhZ2UAQWRkUmFuZ2UARW51bWVyYWJsZQBJRGlzcG9zYWJsZQBDb25zb2xlAGdldF9OYW1lAEdldFNhbUFjY291bnROYW1lAFByb3BlcnR5U2FtQWNjb3VudE5hbWUAc2FtQWNjb3VudE5hbWUAV3JpdGVMaW5lAERpcmVjdG9yeUNvbnRleHRUeXBlAFN5c3RlbS5Db3JlAFJlYWRPbmx5Q29sbGVjdGlvbkJhc2UARGlzcG9zZQBHdWlkQXR0cmlidXRlAERlYnVnZ2FibGVBdHRyaWJ1dGUAQ29tVmlzaWJsZUF0dHJpYnV0ZQBBc3NlbWJseVRpdGxlQXR0cmlidXRlAEFzc2VtYmx5VHJhZGVtYXJrQXR0cmlidXRlAFRhcmdldEZyYW1ld29ya0F0dHJpYnV0ZQBBc3NlbWJseUZpbGVWZXJzaW9uQXR0cmlidXRlAEFzc2VtYmx5Q29uZmlndXJhdGlvbkF0dHJpYnV0ZQBBc3NlbWJseURlc2NyaXB0aW9uQXR0cmlidXRlAENvbXBpbGF0aW9uUmVsYXhhdGlvbnNBdHRyaWJ1dGUAQXNzZW1ibHlQcm9kdWN0QXR0cmlidXRlAEFzc2VtYmx5Q29weXJpZ2h0QXR0cmlidXRlAEFzc2VtYmx5Q29tcGFueUF0dHJpYnV0ZQBSdW50aW1lQ29tcGF0aWJpbGl0eUF0dHJpYnV0ZQBBRFRvb2wuZXhlAHNldF9QYWdlU2l6ZQBTeXN0ZW0uUnVudGltZS5WZXJzaW9uaW5nAFRvU3RyaW5nAEZpbmRBbGwAQURUb29sAFByb2dyYW0AZ2V0X0l0ZW0AaXRlbQBTeXN0ZW0ATWFpbgByb290RG9tYWluAEpvaW4AU3lzdGVtLlJlZmxlY3Rpb24AUmVzdWx0UHJvcGVydHlWYWx1ZUNvbGxlY3Rpb24AU3RyaW5nQ29sbGVjdGlvbgBEb21haW5Db2xsZWN0aW9uAFNlYXJjaFJlc3VsdENvbGxlY3Rpb24AUmVzdWx0UHJvcGVydHlDb2xsZWN0aW9uAEFjdGl2ZURpcmVjdG9yeVBhcnRpdGlvbgBFeGNlcHRpb24AU3lzdGVtLkxpbnEAQ2hhcgBEaXJlY3RvcnlTZWFyY2hlcgBzZXRfRmlsdGVyAFRvTG93ZXIASUVudW1lcmF0b3IAR2V0RW51bWVyYXRvcgAuY3RvcgBTeXN0ZW0uRGlhZ25vc3RpY3MAU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzAFN5c3RlbS5SdW50aW1lLkNvbXBpbGVyU2VydmljZXMAU3lzdGVtLkRpcmVjdG9yeVNlcnZpY2VzAERlYnVnZ2luZ01vZGVzAGdldF9Qcm9wZXJ0aWVzAGFyZ3MAZ2V0X0RvbWFpbnMAU3lzdGVtLkNvbGxlY3Rpb25zAFNlYXJjaFVzZXJzAENvbmNhdABPYmplY3QAU3BsaXQARXhpdABTZWFyY2hSZXN1bHQARW52aXJvbm1lbnQAZ2V0X0N1cnJlbnQAZ2V0X0NvdW50AEV4Y2VwdABHZXRGb3Jlc3QAR2V0RG9tYWluTGlzdABob3N0AE1vdmVOZXh0AERpcmVjdG9yeUNvbnRleHQAVG9BcnJheQBTeXN0ZW0uRGlyZWN0b3J5U2VydmljZXMuQWN0aXZlRGlyZWN0b3J5AERpcmVjdG9yeUVudHJ5AElzTnVsbE9yRW1wdHkAAAAzQQByAGcAcwAgAHcAYQBzACAAaQBuAGMAbwByAHIAZQBjAHQAIABzAHQAcgBpAG4AZwAAXUgAbwBzAHQAIABvAHIAIABzAGEAbQBhAGMAYwBvAHUAbgB0ACAAbgBhAG0AZQBzACAAdwBlAHIAZQAgAGkAbgBjAG8AcgByAGUAYwB0ACAAcwB0AHIAaQBuAGcAACdOAG8AIAB1AHMAZQByAHMAIAB3AGUAcgBlACAAZgBvAHUAbgBkAABJVABoAGUAIABmAG8AbABsAG8AdwBpAG4A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"

# конфиг сервера
$config = @"
{
"ActiveDirectoryHost":"%ActiveDirectoryHost%",
"DbPort":5432,
"DbUser":"postgres",
"DbPwd":"%DbPwd%",
"DbName":"ai_csi",
"QueuePort":5672,
"QueueUser":"ai_user",
"QueuePwd":"%QueuePwd%",
"Host":"%Host%",
"ProjectsPort":5001,
"AuthPort":7001,
"FileContentPort":5002,
"SettingsProviderPort":5004,
"GatewayHttpsPort":443,
"GatewayHttpPort":80,
"AgentAuthPort":4444,
"SystemManagementPort":5005,
"ScanSchedulerPort":5007,
"VaultPort":8200,
"NotificationsPort":5003,
"IssueTrackerPort":5006,
"ConsulPort":8500,
"UpdateServerPort":5010,
"UIApiPort":5011,
"ChangeHistoryPort":5012,
"DescriptionsServicePort":5008,
"CertPath":"%CertPath%",
"CertPwd":"%CertPwd%",
"CheckClientCertificateRevocation":"false",
"FileSourcesFolder":"C:\\ProgramData\\Application Inspector\\Sources",
"UpdateWorkingFolder":"C:\\ProgramData\\Application Inspector\\Update",
"FusServerHost":"https://update.ptsecurity.com",
"LicenseServerHost":"%LicenseServerHost%",
"AdminsSamAccountNames":"%AdminsSamAccountNames%"
}
"@

$readme = @"
---ПОЛУЧЕНИЕ ЛИЦЕНЗИИ---
1. Откройте в браузере https://%myFQDN%/ui/admin/settings#license
	Ваш логин: %username%
	Ваш пароль: тот же что для входа в Windows
2. Нажмите Сгенерировать фингерпринт
3. Отправьте файл специалисту Positive Technologies для получения лицензии

---ВСТРАИВАНИЕ В JENKINS---
0. Скачайте плагин по ссылке https://storage.ptsecurity.com/f/d882168dcdb54a6a81cc/?dl=1
1. Установите плагин ptai-jenkins-plugin.hpi через веб-интерфейс Jenkins
2. Перейдите в меню Настройки системы
3. Найдите раздел Анализ уязвимостей PT AI
4. Добавьте глобальную конфигурацию PT AI
5. Укажите следующие данные:
	Наименование конфигурации: ptai-scan
	URL сервера PT AI: https://%myFQDN%
	Учётная запись: 
		Добавить -> Jenkins -> тип Аутентификация на сервере PT AI
		API-токен клиента PT AI: создать в веб-интерфейсе https://%myFQDN%/ui/admin/settings#tokens
		CA-сертификаты PT AI: скопируйте текстом из файла %toolspath%\certs\ai-chain.crt
		Нажмите Проверить CA-сертификаты
		Нажмите Добавить
6. Нажмите Проверить соединение
7. Откройте настройки сборки вашего проекта и добавьте шаг сборки "Анализ уязвимостей PT AI"
8. Укажите Наименование проекта, созданного в программе AI Viewer
9. При необходимости добавьте отчёт в интересующем вас формате
	Список шаблонов отчётов можно посмотреть на странице https://%myFQDN%/ui/admin/settings#reports
10. Сохраните и запустите сборку

---ВСТРАИВАНИЕ В TEAMCITY---
0. Скачайте плагин по ссылке https://storage.ptsecurity.com/f/529a6c675d504a899721/?dl=1
1. Установите плагин ptai-teamcity-plugin.zip через веб-интерфейс Teamcity
2. В Teamcity перейдите в меню Administration -> Integrations -> PT AI
3. Укажите следующие данные:
	PT AI server URL: https://%myFQDN%
	PT AI API token: создать в веб-интерфейсе https://%myFQDN%/ui/admin/settings#tokens
	PT AI server trusted certificates: скопируйте из %toolspath%\certs\ai-chain.crt
4. Нажмите Test PT AI server connection
5. Нажмите Save
6. Откройте настройки сборки вашего проекта и добавьте шаг сборки "PT AI"
7. Укажите имя проекта, созданного в программе AI Viewer, в параметре Project name
8. При необходимости добавьте отчёт в интересующем вас формате
	Список шаблонов отчётов можно посмотреть на странице https://%myFQDN%/ui/admin/settings#reports
9. Сохраните и запустите сборку

---ВСТРАИВАНИЕ В GITLAB ИЛИ ИНЫЕ СИСТЕМЫ ПОСРЕДСТВОМ ВЫЗОВА КОМАНДНОЙ СТРОКИ---
0. Скачайте плагин по ссылке https://storage.ptsecurity.com/f/34f49ff09ed248568930/?dl=1
1. Скопируйте плагин ptai-cli-plugin.jar на хост агента сборки Gitlab и запомните полный путь к нему
2. Скопируйте сертификат сервера на хост агента сборки: 
	%toolspath%\certs\ai-chain.crt
3. Установите Java JDK 1.8 на хост агента сборки
4. Импортируйте сертификат сервера в хранилище сертификатов Java агента сборки, выполнив на нём следующую команду (пример):
	keytool -importcert -keystore $JAVA_HOME/jre/lib/security/cacerts -storepass "changeit" -alias AIRootCA -file ai-chain.crt -noprompt
	, где -keystore - путь к хранилищу сертификатов
		  -storepass - пароль от хранилища сертификатов
		  -file - путь к файлу сертификата для импорта
5. Создайте токен доступа для легкого агента и плагинов CI/CD в веб-интерфейсе https://%myFQDN%/ui/admin/settings#tokens
6. Подготовьте строку запуска AI по примеру:
	java -jar /путь/к/плагину/ptai-cli-plugin.jar ui-ast --input="$PWD" --project="ИмяПроектаИзAIViewer" --report-json="ai-reports.json" --token="ваш_токен" --url=https://%myFQDN%
	Примечание: при запуске в Windows системах параметр input заменить на "%cd%"
				для Gitlab в параметр input можно подставить переменную $CI_PROJECT_DIR
7. Укажите список требуемых отчётов в файле ai-reports.json и путь к нему в строке запуска, пример файла см. в %toolspath%\ai-reports.json
	Можно сохранить этот файл на операционной системе агента сборки, либо поместить его в репозиторий сканируемого проекта
	Список шаблонов отчётов можно посмотреть на странице https://%myFQDN%/ui/admin/settings#reports
	Настройки фильтров см. в схеме метода /api/Reports/generate: https://%myFQDN%/swagger/index.html?urls.primaryName=projectManagement
8. Вставьте строку запуска в конфигурацию сборки .gitlab-ci.yml, пример см. в %toolspath%\gitlab-ci-example.yml
9. Сохраните изменения и запустите сборку
10. Полный список доступных опций плагина можно получить, если обратиться к нему без параметров:
	> java -jar ptai-cli-plugin.jar

---ПРОДВИНУТЫЕ МЕТОДИКИ ВСТРАИВАНИЯ В CI/CD---
См. пример интеграции внутри компании Positive Technologies тут: https://github.com/devopshq/dohq-ai-best-practices

---ПАРОЛИ---
Пароли, заданные в процессе установки, сохранены в файле %toolspath%\passwords.txt. Пожалуйста, сохраните их в безопасном месте и удалите файлы passwords.txt и passwords.xml.

---БЕЗОПАСНОСТЬ---
Для обеспечения безопасности сервера закройте на межсетевом экране все порты, кроме 443.
При наличии антивируса рекомендуется добавить каталог "C:\Program Files\Positive Technologies\Application Inspector Agent" в исключения, т.к. некоторые антивирусы могут блокировать подозрительную активность, когда AI взаимодействует с файламами во время сканирования.
"@

$gitlabci = @"
test:
  script:
    - java -jar ptai-cli-plugin.jar ui-ast --project="Gitlab" --input="$CI_PROJECT_DIR" --report-json="ai-reports.json" -t="k0K4nVTr2OmroxH/Zzc2Bnwbv+3LDhV3" --url="https://ptaisrv.domain.org" --excludes=**/*.lck
  only:
    variables:
      - $CI_COMMIT_MESSAGE =~ /AIEE/
  tags: 
    - aiee
  artifacts:
    expire_in: 7 day
	when: always
    paths:
      - .ptai/ 
"@

$aireports = @"
{
  "report" : [ {
    "fileName" : "report.ru.html",
    "locale" : "RU",
    "format" : "HTML",
    "template" : "Отчет по результатам сканирования",
	"filters": {
		"issueLevel": "HIGH",
		"exploitationCondition": "ALL",
		"scanMode": "FROMENTRYPOINT",
		"suppressStatus": "ALL",
		"confirmationStatus": "ALL",
		"sourceType": "ALL"
	}
  } ],
  "data" : [ {
    "fileName" : "data.en.json",
    "locale" : "EN",
    "format" : "JSON",
    "filters": {
      "issueLevel": "HIGH"
    }
  }, {
    "fileName" : "data.ru.xml",
    "locale" : "RU",
    "format" : "XML"
  } ],
  "raw" : [ {
    "fileName" : "raw.json"
  } ]
}
"@

# инициализация логирования
Set-Location -Path $PSScriptRoot
if ($toolspath -eq '') {$toolspath = "C:\AI-TOOLS"}
if (-Not (Test-Path $toolspath\logs)) {mkdir $toolspath\logs >$null}
Start-Transcript -path "$toolspath\logs\install-$((Get-Date).Ticks).log" -append
date

# добавление администратора в базу данных
if ($addadmin -ne '') {
	if (Test-Path "$toolspath\passwords.xml") {
		$passwords = Import-Clixml -Path "$toolspath\passwords.xml"
		AI-Add-Admin $addadmin
		Stop-Transcript
		Exit		
	}
	else {
		Write-Host "Ошибка: файл с паролем от базы данных не найден по пути $toolspath\passwords.xml" -ForegroundColor Red
		Stop-Transcript
		Exit 1
	}
}

# полное удаление серверных компонентов AI с компьютера
if ($uninstall) {
	if (Test-Path "C:\Program Files\Positive Technologies\Application Inspector Agent\unins000.exe") {
		Write-Host "Удаляю AI Agent..." -ForegroundColor Yellow
		$proc = Start-Process "C:\Program Files\Positive Technologies\Application Inspector Agent\unins000.exe" -ArgumentList "/verysilent /norestart" -passthru
		Handle-Install-Result "AI Agent" $proc "удалении"
	}
	if (Test-Path "C:\Program Files\Positive Technologies\Application Inspector Server\unins000.exe") {
		Write-Host "Удаляю AI Server, RabbitMQ, PostgreSQL..." -ForegroundColor Yellow
		$proc = Start-Process "C:\Program Files\Positive Technologies\Application Inspector Server\unins000.exe" -ArgumentList "/verysilent /norestart" -passthru
		Handle-Install-Result "AI Server" $proc "удалении"
	}
	if (Test-Path $env:appdata\RabbitMQ) {Remove-Item -Recurse -Force $env:appdata\RabbitMQ}
	if (Test-Path "C:\Program Files\PostgreSQL") {Remove-Item -Recurse -Force "C:\Program Files\PostgreSQL"}
	if (Test-Path $toolspath\certs) {Remove-Item -Recurse -Force $toolspath\certs}
	if (Test-Path $toolspath\passwords.txt) {Remove-Item $toolspath\passwords.txt}
	if (Test-Path $toolspath\passwords.xml) {Remove-Item $toolspath\passwords.xml}
	Remove-Item $toolspath\readme.txt -ErrorAction SilentlyContinue
	Remove-Item $toolspath\gitlab-ci-example.yml -ErrorAction SilentlyContinue
	Remove-Item $toolspath\ai-reports.json -ErrorAction SilentlyContinue
	Remove-Item $toolspath\server-config.json -ErrorAction SilentlyContinue
	Write-Host "Удаление завершено." -ForegroundColor Yellow
	Write-Host "При наличии ошибок убедитесь, пожалуйста, что все файлы из текста ошибки были удалены." -ForegroundColor Yellow
	Write-Host "Рекомендуется провести перезагрузку компьютера, перезагрузить? (y/n) " -NoNewline -ForegroundColor Yellow
	$answer = Read-Host
	if ($answer -eq 'y') {Restart-Computer -Force}
	Stop-Transcript
	Exit
}

Write-Host '---ШАГ 1---' -ForegroundColor Green
Write-Host 'Проверяю зависимости...' -ForegroundColor Yellow
# проверяем зависимости
$psver = Get-Host | Select-Object Version
if ($psver.version.Major -lt 5) {
	Write-Host 'Ошибка: пожалуйста, обновите версию Powershell до 5-ой или выше, а затем перезапустите скрипт.' -ForegroundColor Red
	Write-Host 'http://www.catalog.update.microsoft.com/Search.aspx?q=3191564'
	Check-NetFramework-Version
	Stop-Transcript
	Exit 1
}
Check-NetFramework-Version
# проверка openssl
if ($servercertpath -eq '') {
	try {
		# обновляем знания текущей сессии Powershell о Path
		$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
		if (-Not ($env:Path.ToLower().contains('openssl')) -And (Test-Path "C:\Program Files\OpenSSL-Win64\bin\openssl.exe")) {
			# обновляем глобальную переменную Path
			[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\OpenSSL-Win64\bin", "Machine")
			$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
		}
		openssl genrsa -out 1.key 1024 2>&1>$null
		Remove-Item 1.key -ErrorAction Stop
		}
	catch {
		Write-Host 'Ошибка: пожалуйста, установите OpenSSL, пропишите его в переменную окружения PATH и перезапустите Powershell.' -ForegroundColor Red
		Write-Host 'https://slproweb.com/products/Win32OpenSSL.html'
		Stop-Transcript
		Exit 1
	}
}
# подготавливаем каталоги для утилит
if (-Not (Test-Path $toolspath\certs)) {mkdir -p $toolspath\certs >$null}
# добавляем локальную переменную окружения с локацией ERLANG
[Environment]::SetEnvironmentVariable("ERLANG_HOME","C:\Program Files\erl9.3","User")
$env:ERLANG_HOME = "C:\Program Files\erl9.3"
# импортируем пароли либо генерируем их
if (Test-Path "$toolspath\passwords.xml") {
	$passwords = Import-Clixml -Path "$toolspath\passwords.xml"
}
else {
	Write-Host 'Генерирую безопасные пароли...' -ForegroundColor Yellow
	$passwords = @{
			'serverCertificate'=Generate-Password;
			'postgres'=Generate-Password;
			'rabbitMQ'=Generate-Password;
	}
	Export-Clixml -Path "$toolspath\passwords.xml" -InputObject $passwords
	$passwords | ConvertTo-JSON | Set-Content -Path "$toolspath\passwords.txt"
}

# устанавливаем AI Viewer
Write-Host '---ШАГ 2---' -ForegroundColor Green
# проверяем если AI Viewer уже установлен
if (Test-Path "C:\Program Files\Positive Technologies\Application Inspector Viewer\ApplicationInspector.exe") {
	Write-Host 'Этот шаг уже был выполнен, переходим к следующему.' -ForegroundColor Yellow
}
else {
	Write-Host 'Устанавливаю AI Viewer...' -ForegroundColor Yellow
	$proc = Start-Process (Get-Current-Version-Path "$aiepath\aiv" "AIE.Viewer*.exe") -ArgumentList "/eulaagree /verysilent /norestart" -passthru
	Handle-Install-Result "AI Viewer" $proc
	# после установки программа запускается - закрываем её
	$AIViewer = Get-Process ApplicationInspector -ErrorAction SilentlyContinue
	if ($AIViewer -ne $null) {Stop-Process $AIViewer}
}
# проверка домена
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -and (-Not $noad)) {
	if ($env:UserName -eq "Administrator") {
		Write-Host "Ошибка: установка под доменной учётной записью Administrator не поддерживается. Пожалуйста, запустите установку под другим пользователем." -ForegroundColor Red
		Stop-Transcript
		Exit 1
	}
	# преобразуем утилиту ADTOOL hex -> exe
	if (-Not (Test-Path "$toolspath\ADTool.exe")) {
		[IO.File]::WriteAllBytes("$toolspath\ADTool.exe", [Convert]::FromBase64String($hex))
	}
	# проверяем наличие пользователя в домене
	Write-Host "Проверяю связь с домен контроллером..." -ForegroundColor Yellow
	$domain = ((Get-WmiObject win32_computersystem).Domain).ToLower()
	$myFQDN = ((Get-WmiObject win32_computersystem).DNSHostName+"."+$domain)
	[bool]$noad = 1
	$newdomain = $domain
	do {
		if ($matches -ne $null) {
			$newdomain = $matches[0]
		}
		Write-Host "Ищу пользователя" $env:UserName "в домене" $newdomain -ForegroundColor Yellow
		if ((."$toolspath\ADTool.exe" $newdomain $env:UserName) -like "Success, all users were found") {
			Write-Host "Нашёл!" -ForegroundColor Yellow
			[bool] $noad = 0
			$domain = $newdomain
			break
		}
	}
	# если не нашли в текущем домене, сокращаем название домена до следующей точки и пробуем снова
	# это связано с тем, что иногда для ADTool нужно указывать корневой домен
	while ($newdomain -match '(?<=\.).*')
	Remove-Item "$toolspath\ADTool.exe"
	if ($noad) {
		$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName
		$domain = "localhost"
	}
}
else {
	[bool]$noad = 1
	$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName
	$domain = "localhost"
}

# обрабатываем сертификаты
Write-Host '---ШАГ 3---' -ForegroundColor Green
# проверяем что этот шаг не выполнялся
if (Test-Path "$toolspath\certs\aiserver.pfx") {
	Write-Host 'Этот шаг уже был выполнен, переходим к следующему.' -ForegroundColor Yellow
	if ($servercertpass -eq '') {$servercertpass = $passwords['serverCertificate']}
}
else {
	if ($servercertpath -eq '') {
		# очищаем файлы предыдущей попытки генерации сертификата
		if (Test-Path "$toolspath\certs\ROOT") {
			Remove-Item -Recurse -Force "$toolspath\certs"
			New-Item -Path "$toolspath\certs" -ItemType Directory | Out-Null
		}
		Write-Host 'Генерирую самоподписанные сертификаты...' -ForegroundColor Yellow
		Generate-SelfsignedCerts $noad $toolspath
		$rootcertpath = "$toolspath\certs\ROOT\certs\RootCA.pem.crt"
		$intcertpath = "$toolspath\certs\INT\certs\IntermediateCA.pem.crt"
		$servercertpath = "$toolspath\certs\aiserver.pfx"
		$servercertpass = $passwords['serverCertificate']
		if (-Not ((Test-Path $rootcertpath) -and (Test-Path $intcertpath) -and (Test-Path $servercertpath))) {
			Write-Host 'Ошибка: Сертификаты не сгенерированы.' -ForegroundColor Red
			Stop-Transcript
			Exit 1
		}
	}
	else {
		Copy-Item $servercertpath "$toolspath\certs\aiserver.pfx"
	}
	# добавляем сертификаты в хранилище Windows
	if ($intcertpath -ne '' -and (Test-Path $intcertpath)) {
		Write-Host 'Импортирую промежуточный сертификат в хранилище сертификатов Windows...' -ForegroundColor Yellow
		if ($intcertpath -like '*.pfx') {
			$int = Import-PfxCertificate -FilePath $intcertpath -Password (ConvertTo-SecureString -String $intcertpass -AsPlainText -Force) -CertStoreLocation Cert:\LocalMachine\CA
		}
		else {
			$int = Import-Certificate -FilePath $intcertpath -CertStoreLocation Cert:\LocalMachine\CA
		}
		# формируем цепочку сертификатов: промежуточный
		@(
		'-----BEGIN CERTIFICATE-----'
		[System.Convert]::ToBase64String($int.RawData, 'InsertLineBreaks')
		'-----END CERTIFICATE-----'
		) | Out-File -FilePath "$toolspath\certs\ai-chain.crt" -Encoding ascii
	}
	if ($rootcertpath -ne '' -and (Test-Path $rootcertpath)) {
		Write-Host 'Импортирую корневой сертификат в хранилище сертификатов Windows...' -ForegroundColor Yellow
		if ($rootcertpath -like '*.pfx') {
			$root = Import-PfxCertificate -FilePath $rootcertpath -Password (ConvertTo-SecureString -String $rootcertpass -AsPlainText -Force) -CertStoreLocation Cert:\LocalMachine\Root
		}
		else {
			$root = Import-Certificate -FilePath $rootcertpath -CertStoreLocation Cert:\LocalMachine\Root
		}
		# формируем цепочку сертификатов: корневой+промежуточный
		@(
		'-----BEGIN CERTIFICATE-----'
		[System.Convert]::ToBase64String($root.RawData, 'InsertLineBreaks')
		'-----END CERTIFICATE-----'
		) | Out-File -FilePath "$toolspath\certs\ai-chain.crt" -Encoding ascii -Append
	}
	Write-Host "Импортирую серверный сертификат и проверяю его..." -ForegroundColor Yellow	
	$servpfx = Import-PfxCertificate -FilePath "$toolspath\certs\aiserver.pfx" -Password (ConvertTo-SecureString -String $servercertpass -AsPlainText -Force) -CertStoreLocation Cert:\LocalMachine\My
	Test-Certificate $servpfx -ea SilentlyContinue | Out-Null
	# при проверке сертификата нас интересует только ошибка с цепочкой. try catch тут не ловит ошибку, поэтому достаём её из системной переменной
	if ($Error[0].exception -like '*CERT_E_CHAINING*') {
		Write-Host "Ошибка: цепочка доверия серверного сертификата нарушена. Пожалуйста, исправьте ошибку и запустите установку повторно." -ForegroundColor Red
		Stop-Transcript
		Exit 1
	}
}

# устанавливаем AI Server
Write-Host '---ШАГ 4---' -ForegroundColor Green
# проверяем если AI Server уже установлен
if (Test-Path "C:\Program Files\Positive Technologies\Application Inspector Server\Services\gateway\AIE.Gateway.exe") {
	Write-Host 'Этот шаг уже был выполнен, переходим к следующему.' -ForegroundColor Yellow
}
else {
	if (Test-Path $env:appdata\RabbitMQ\db) {
		Write-Host "Ошибка: обнаружены следы предыдущей установки Application Inspector, что может привести к ошибкам при повторной установке. Пожалуйста, выполните скрипт с параметром -uninstall, после чего запустите установку повторно." -ForegroundColor Red
		Stop-Transcript
		Exit 1
	}
	# проверка доступности портов
	[int32[]]$ports = 80,443,5432,5672,5001,7001,5002,5004,4444,5005,5006,5007,8200,5003,8500,5010,5011,5012,5008
	$errcnt = 0
	for ($i=0;$i -lt $ports.Length;$i++) {
		$available = netstat -na | findstr /r /c:":$($ports[$i]) *[^ ]*:[^ ]*"
		if ($available -ne $null) {
			Write-Host "Ошибка: порт $($ports[$i]) занят." -ForegroundColor Red
			$errcnt++
		}
	}
	if ($errcnt -gt 0) {
		Write-Host 'Пожалуйста, освободите занятые порты, либо исправьте порт в переменной config данного скрипта и перезапустите его.' -ForegroundColor Red
		Write-Host 'Если у вас занят 80-ый порт и вы не знаете почему, возможно, вам поможет эта статья: https://myhelpit.ru/index.php?id=163'
		Stop-Transcript
		Exit 1
	}
	Write-Host 'Устанавливаю AI Server...' -ForegroundColor Yellow
	# патчим файл конфигурации инсталлятора
	$config = $config -ireplace '%DbPwd%',"$($passwords['postgres'])"
	$config = $config -ireplace '%QueuePwd%',"$($passwords['rabbitMQ'])"
	$tmppath = $toolspath -ireplace '\\',"\\"
	$config = $config -ireplace '%CertPath%',"$tmppath\\certs\\aiserver.pfx"
	$config = $config -ireplace '%CertPwd%',"$servercertpass"
	$config = $config -ireplace '%AdminsSamAccountNames%',"$($env:UserName)"
	$config = $config -ireplace '%ActiveDirectoryHost%',"$domain"
	$config = $config -ireplace '%LicenseServerHost%',"$myFQDN"
	$config -ireplace '%Host%',"$myFQDN" | Set-Content -Path $toolspath\server-config.json
	# Добавляем правила на межсетевом экране для RabbitMQ (виртуальной машины erlang)
	New-NetFirewallRule -DisplayName "erl" -Direction Inbound -Program "C:\Program Files\erl9.3\bin\erl.exe" -Action allow -Protocol TCP | Out-Null
	New-NetFirewallRule -DisplayName "erl" -Direction Inbound -Program "C:\Program Files\erl9.3\bin\erl.exe" -Action allow -Protocol UDP | Out-Null
	New-NetFirewallRule -DisplayName "epmd" -Direction Inbound -Program "C:\Program Files\erl9.3\erts-9.3\bin\epmd.exe" -Action allow -Protocol TCP | Out-Null
	New-NetFirewallRule -DisplayName "epmd" -Direction Inbound -Program "C:\Program Files\erl9.3\erts-9.3\bin\epmd.exe" -Action allow -Protocol UDP | Out-Null
	Set-NetFirewallRule -DisplayName "erl" -Profile Any | Out-Null
	Set-NetFirewallRule -DisplayName "epmd" -Profile Any | Out-Null
	# производим установку сервера
	# с флагом /noad если не смогли найти домен
	if ($noad) {
		Write-Host "Предупреждение: домен не найден, провожу установку с флагом /noad." -ForegroundColor Cyan
		$proc = Start-Process (Get-Current-Version-Path "$aiepath\aie" "AIE.Server*.exe") -ArgumentList "/eulaagree /verysilent /norestart /SUPPRESSMSGBOXES /configFilePath=`"$toolspath\server-config.json`" /LOG=`"$toolspath\logs\server-install.log`" /noad" -passthru
	}
	else {
		$proc = Start-Process (Get-Current-Version-Path "$aiepath\aie" "AIE.Server*.exe") -ArgumentList "/eulaagree /verysilent /norestart /SUPPRESSMSGBOXES /configFilePath=`"$toolspath\server-config.json`" /LOG=`"$toolspath\logs\server-install.log`"" -passthru
	}
	Handle-Install-Result "AI Server" $proc
	Start-Sleep 10
	xcopy "C:\ProgramData\Application Inspector\Logs\deploy" $toolspath\logs\deploy\ /E /Y >$null
	# дополнительные манипуляции для установок без домена
	if ($noad) {
		# выключаем окно первого запуска IE чтобы работали запросы через функцию Invoke-WebRequest
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 2
        # получаем мастер-токен консула
		$conf_consul = Get-Content -path 'C:\Program Files\Positive Technologies\Application Inspector Server\Services\consul\serverConfig.json' | ConvertFrom-Json
        $consul_token = $conf_consul.acl.tokens.master
		# временное решение: затираем имя домена
        $i = Invoke-WebRequest -Uri "http://localhost:8500/v1/kv/services/ADSettings?dc=dc1" -Headers @{"X-Consul-Token"="$consul_token"}
        $body = $i.Content | ConvertFrom-Json
        $json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($body.Value)) | ConvertFrom-Json
        $json.Host = ""
        $res = $json | ConvertTo-json
        Invoke-WebRequest -Uri "http://localhost:8500/v1/kv/services/ADSettings?dc=dc1" -Method "PUT" -Headers @{"X-Consul-Token"="$consul_token"} -ContentType "application/json; charset=UTF-8" -Body "$res" | Out-Null
		# добавляем текущего пользователя в качестве админа через базу данных
		AI-Add-Admin ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
	}
}
# проверяем наличие служб
try {
	$AIServices = Get-Service AI.*,Consul,RabbitMQ,PostgreSQL -ErrorAction Stop
}
catch {
	Write-Host 'Ошибка проверки служб: '$_ -ForegroundColor Red
	Stop-Transcript
	Exit 1
}
# проверяем статус служб
$ServiceDownList = New-Object System.Collections.Generic.List[System.Object]
for ($i=0; $i -lt $AIServices.Length; $i++) {
	if ($AIServices[$i].Status -ne 'Running') {
		$ServiceDownList.Add($AIServices[$i].DisplayName)
	}
}
# если есть не запустившиеся службы, пробуем исправить ситуацию
if ($ServiceDownList.Count -gt 0) {
	# проверяем пользователей в rabbitMQ
	$rusers = (& "C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" list_users).split()
	Write-Host "Пользователи rabbitMQ: " $rusers
	for ($i=0; $i -lt $rusers.Count; $i++) {
		if ($rusers[$i] -eq 'ai_user') {
			$exists = $true
			# даже если пользователь создан, может произойти ситуация, что ему не выданы права, поэтому выдаём их повторно
			&"C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" list_user_permissions ai_user
			&"C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" set_permissions -p / ai_user ".*" ".*" ".*"
			&"C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" set_user_tags ai_user administrator
		}
	}
	# если нет такого юзера, добавляем его и перезапускаем службы
	if (-Not $exists) {
		&"C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" add_user ai_user $passwords['rabbitMQ']
		&"C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" set_permissions -p / ai_user ".*" ".*" ".*"
		&"C:\Program Files\RabbitMQ Server\rabbitmq_server-3.7.8\sbin\rabbitmqctl.bat" set_user_tags ai_user administrator
		$AIServices = Get-Service AI.*
		for ($i=0; $i -lt $AIServices.Length; $i++) {
			Start-Sleep 2
			net stop $AIServices[$i]
			net start $AIServices[$i]
		}
		Start-Sleep 10
		# проверяем статус служб
		$AIServices = Get-Service AI.*
		$ServiceDownList = New-Object System.Collections.Generic.List[System.Object]
		for ($i=0; $i -lt $AIServices.Length; $i++) {
			if ($AIServices[$i].Status -ne 'Running') {
				$ServiceDownList.Add($AIServices[$i].DisplayName)
			}
		}
	}
	if ($ServiceDownList.Count -gt 0) {
		Copy-AIE-Logs $ServiceDownList
		xcopy $env:APPDATA\RabbitMQ\log $toolspath\logs\RabbitMQ\ /E /Y >$null
		Write-Host "Ошибка: AI Server установлен, но некоторые службы не смогли запуститься. Пожалуйста, отправьте каталог с логами $toolspath\logs специалисту из Positive Technologies для анализа." -ForegroundColor Red
	}
}

# устанавливаем AI Agent
Write-Host '---ШАГ 5---' -ForegroundColor Green
# проверяем что AI Agent уже установлен
if (Test-Path "C:\Program Files\Positive Technologies\Application Inspector Agent\aic.exe") {
	Write-Host 'Этот шаг уже был выполнен, переходим к следующему.' -ForegroundColor Yellow
}
elseif ($skipagent) {
	Write-Host 'Пропускаю этап установки агента.' -ForegroundColor Yellow
}
else {
	# проверяем состояние ключевых служб для выдачи токена
	if (((Get-Service AI.Enterprise.AuthService).Status -eq "Running") -and ((Get-Service AI.Enterprise.Gateway).Status -eq "Running")) {
		# назначаем версию TLS
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
		# получить bearer token
		try {
			$bearer = Invoke-RestMethod -Uri "https://$($myFQDN)/api/auth/signin?scopeType=Viewer" -Method GET -Headers @{"Accept"="text/plain"} -UseDefaultCredentials
		}
		catch {
			# если сохранились проблемы с защищёнными соединениями, выключаем проверку сертификата
			add-type @"
				using System.Net;
				using System.Security.Cryptography.X509Certificates;
				public class TrustAllCertsPolicy : ICertificatePolicy {
					public bool CheckValidationResult(
						ServicePoint srvPoint, X509Certificate certificate,
						WebRequest request, int certificateProblem) {
						return true;
					}
				}
"@
			[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy	
			$bearer = Invoke-RestMethod -Uri "https://$($myFQDN)/api/auth/signin?scopeType=Viewer" -Method GET -Headers @{"Accept"="text/plain"} -UseDefaultCredentials
		}
		# готовим и отсылаем запрос на получение токена
		$headers = @{
			"Authorization" = "Bearer $($bearer)";
			"Content-Type" = "application/json";
		}
		$body = "{
		`n  `"name`": `"agent$((Get-Date).Ticks)`",
		`n  `"expiresDateTime`": `"$((Get-Date).AddMonths(36).ToString(`"yyyy-MM-dd`"))T00:00:00.000Z`",
		`n  `"scopes`": `"ScanAgent`"
		`n}
		`n"
		$response = Invoke-RestMethod "https://$($myFQDN)/api/auth/accessToken/create" -Method POST -Headers $headers -Body $body
		# если получили токен, ставим агент
		if ($response.token -ne $null) {
			Write-Host 'Провожу установку AI Agent...' -ForegroundColor Yellow
			$proc = Start-Process (Get-Current-Version-Path "$aiepath\aic" "AIE.Agent*.exe") -ArgumentList "/eulaagree /verysilent /SUPPRESSMSGBOXES /workScheduler /norestart /serverUri=`"https://$($myFQDN)`" /accessToken=`"$($response.token)`" /LOG=`"$toolspath\logs\agent-install.log`"" -passthru
			Handle-Install-Result "AI Agent" $proc
		}
		else {
			Write-Host "Ошибка: не удалось сгенерировать токен агента." -ForegroundColor Red
			Stop-Transcript
			Exit 1
		}
	}
	else {
		Write-Host "Ошибка: службы AI.Enterprise.AuthService и AI.Enterprise.Gateway не работают, не могу получить токен доступа для установки агента." -ForegroundColor Red
		Stop-Transcript
		Exit 1
	}
}

# заменяем ключевые значения в readme
if ($noad) {
	$username = ".\"+$env:UserName
}
else {
	$username = $env:UserName
}
$readme = $readme -ireplace '%myFQDN%',"$myFQDN"
$readme = $readme -ireplace '%username%',"$username"
$readme -ireplace '%toolspath%',"$toolspath" | Set-Content -Path $toolspath\readme.txt -Encoding UTF8
$gitlabci | Set-Content -Path $toolspath\gitlab-ci-example.yml -Encoding UTF8
$aireports | Set-Content -Path $toolspath\ai-reports.json -Encoding UTF8
try {
	Get-Service hasplms | Out-Null
	Write-Host "Установка завершена." -ForegroundColor Yellow
	Write-Host "Дальнейшие инструкции см. в файле $toolspath\readme.txt." -ForegroundColor Yellow
	Start-Process $toolspath\readme.txt
	date
	Stop-Transcript
}
catch {
	Write-Host "Ошибка: компонент Sentinel не установлен. Пожалуйста, обратитесь к специалисту из Positive Technologies для решения проблемы." -ForegroundColor Red
	Stop-Transcript
	Exit 1
}
