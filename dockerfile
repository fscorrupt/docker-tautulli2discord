FROM mcr.microsoft.com/dotnet/core/sdk:latest
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN apt-get update && apt-get install git -y
RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"
RUN mkdir /config

COPY *.ps1 .
COPY config /config

CMD [ "pwsh","./welcome.ps1" ]
