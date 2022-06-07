FROM mcr.microsoft.com/powershell:ubuntu-22.04
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN apt-get update && apt-get install git -y
RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"
RUN mkdir /config
COPY *.ps1 .
COPY config.json.template ./config

CMD [ "pwsh","./welcome.ps1" ]
