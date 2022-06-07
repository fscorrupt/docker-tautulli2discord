FROM mcr.microsoft.com/powershell:ubuntu-22.04
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/docker-tautulli2discord

RUN \
  echo "**** update packages ****" && \
    apk --quiet --no-cache --no-progress update && \
  echo "**** install build packages ****" && \
    apk add -U --update --no-cache git -yqq && \
    mkdir -p /config && \
    pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease" && \
  echo "*** cleanup system ****" && \
    apk del --quiet --clean-protected --no-progress && \
    rm -f /var/cache/apk/*
    
COPY *.ps1 .

CMD [ "pwsh","-command","get-childitem -Filter *.ps1" ]
