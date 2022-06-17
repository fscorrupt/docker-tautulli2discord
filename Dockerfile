FROM mcr.microsoft.com/powershell:7.0.1-alpine-3.10
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord
RUN apk update
RUN apk add libgdiplus --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/
RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

COPY *.ps1 .

CMD [ "pwsh","./welcome.ps1" ]
