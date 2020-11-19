# (c) DevOpsHQ, 2020

FROM mcr.microsoft.com/windows/servercore:10.0.17763.379

ARG AISA_PACKAGE
ARG ARTIFACTORY_LOGIN
ARG ARTIFACTORY_PASSWORD
ARG CERT_PASSWORD

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ADD "docker_build_data\download-and-unpack" "c:\scripts\download-and-unpack"
ADD "docker_build_data\install-web" "c:\scripts\install-web"
ADD "docker_build_data\create-json" "c:\scripts\create-json"
ADD "docker_build_data\certs" "c:\scripts\certs"

# -------------------- Установка ПО --------------------

# --- Install dotnet runtime ----------
RUN "C:\scripts\install-web\install-web.ps1"\
    -URL https://download.visualstudio.microsoft.com/download/pr/93d4ac87-6db0-4ddd-9bef-8050067b5e5d/605b178040bdd75b63d021d9387219ea/dotnet-runtime-3.1.4-win-x64.exe \
    -Filename dotnet-runtime-3.1.4-win-x64.exe \
    -InstallArgs '/install /passive'

# --- Install aisa --------------------
RUN "c:\scripts\download-and-unpack\download-and-unpack-auth.ps1" \
    -PKG $(${env:AISA_PACKAGE}) \
    -UnpackTo 'C:\Program Files (x86)\Positive Technologies\Application Inspector Agent Shell' \
    -Login $(${env:ARTIFACTORY_LOGIN}) \
    -Key $(${env:ARTIFACTORY_PASSWORD})

ENV AISA_PATH C:\\Program Files (x86)\\Positive Technologies\\Application Inspector Agent Shell

# --- Ai.Shell setting ----------------
ARG AISA_TOKEN
ARG AISA_URI

RUN "C:\scripts\create-json\create-json.ps1"

# --- Import Certs --------------------

#RUN "c:\scripts\certs\import-certs.ps1" \
#    -KEY $(${env:CERT_PASSWORD})

# --- Fast changes --------------------

# SAVE PATHS IN REGISTRY:
RUN $path = [environment]::GetEnvironmentVariable('Path', 'Machine'); \
    Get-ChildItem ENV: | Where-Object -Property Name -match '.+_PATH' | ForEach-Object { \
    if (($path -notlike '*;'+$_.Value) -And ($path -notlike '*'+$_.Value+';*')) { $path+=';'+$_.Value } }; \
    [Environment]::SetEnvironmentVariable('Path', $path, 'Machine'); \
    # Enable Long paths fix. Windows default limit of 255 chars may cause problems with builds.
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /f /v LongPathsEnabled /t REG_DWORD /d 1

CMD ["cmd"]
