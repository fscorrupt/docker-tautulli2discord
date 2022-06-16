FROM mcr.microsoft.com/powershell:preview-alpine-3.15
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord
RUN apt update
RUN apt install dotnet-sdk-2.1 -y
RUN apt install -y libc6-dev -y
RUN apt install -y libgdiplus -y

RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

COPY *.ps1 .

CMD [ "pwsh","./welcome.ps1" ]
