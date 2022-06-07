FROM mcr.microsoft.com/powershell:ubuntu-22.04
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN apt-get update && apt-get install git -y

COPY *.ps1 .

RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

CMD [ "pwsh", "ls" ]
