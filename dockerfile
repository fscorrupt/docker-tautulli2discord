FROM mcr.microsoft.com/powershell:ubuntu-22.04
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN dpkg --purge packages-microsoft-prod && dpkg -i packages-microsoft-prod.deb && apt-get update && apt-get install -y apt-transport-https && apt-get update && apt-get install -y dotnet-sdk-6.0
RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"
RUN mkdir /config

COPY *.ps1 .
COPY config /config

CMD [ "pwsh","./welcome.ps1" ]
