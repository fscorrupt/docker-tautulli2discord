# Tautulli2Discord
This is a collection of PowerShell scripts that collect information from Tautulli's API and sends it off to Discord via webhooks.

# Configuration
I tried to make the scripts as easy to use as possible. The scripts rely on the config.json file.

Information on how to set up a Discord webhook can be found be [here.](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)

# Usage
That's it. Once the webhook(s) are created and the variables are filled in properly, you should be able to run the scripts and it send the relevant information to your Discord server/channel.

Cron example:
```sudo crontab -e```
add a new line like this:

```# Current Streams
* * * * * docker exec tautulli2discord pwsh CurrentStreams.ps1 >/dev/null 2>&1
```

# Examples
CurrentStreams.ps1

![DiscordCurrentlyStreaming.ps1](https://i.imgur.com/pDA3Tvs.png)

PopularOnPlex.ps1

![PopularOnPlex.ps1](https://i.imgur.com/MpEhVWJ.png)

LibraryStats.ps1

![DiscordLibraryStats.ps1](https://i.imgur.com/ghONij6.png)


TopPlexStats.ps1

![DiscordTopXUsersByMediaType.ps1](https://i.imgur.com/0SNBXA9.png)

# Issues
Probably. Just let me know and I will try to correct.

# Thanks
Many thanks to @Shayne55434 for his help and contributions

# Enjoy
This one is simple.
