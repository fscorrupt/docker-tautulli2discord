FROM microsoft/powershell:latest
LABEL maintainer=fscorrupt
LABEL org.opencontainers.image.source https://github.com/fscorrupt/Tautulli2Discord

RUN apt-get update && apt-get install git -y

COPY . .

RUN pwsh -c "Install-Module PSReadLine -Force -SkipPublisherCheck -AllowPrerelease"

CMD [ "pwsh" ]