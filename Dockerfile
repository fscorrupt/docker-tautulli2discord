FROM mcr.microsoft.com/powershell:preview-alpine-3.15 AS base
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord
RUN apt-get update \
  && apt-get install -y libgdiplus \
  libc6-dev 
RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

COPY *.ps1 .

CMD [ "pwsh","./welcome.ps1" ]
