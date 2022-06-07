FROM mcr.microsoft.com/windows/servercore:ltsc2019
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

COPY *.ps1 .
COPY config /config

CMD [ "pwsh","./welcome.ps1" ]
