FROM mcr.microsoft.com/powershell:7.2.2-alpine-3.14-20220318
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

COPY *.ps1 .

CMD [ "pwsh","./welcome.ps1" ]
