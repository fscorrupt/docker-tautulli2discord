FROM mcr.microsoft.com/powershell:preview-alpine-3.15
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord
RUN apk update
RUN apk add libc6-dev --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/
RUN apk add libgdiplus --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/
RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

COPY *.ps1 .

CMD [ "pwsh","./welcome.ps1" ]
