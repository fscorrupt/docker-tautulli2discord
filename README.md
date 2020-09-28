# Tautulli2Discord
This is a collection of PowerShell scripts that collect information from Tautulli's API and sends it off to Discord via webhooks.

# Configuration
All of the scripts have a few variables after the Functions that need to be set. Such as **Webhook URI**, **Tautulli URL** (with port), **Tautulli API Key**, and a few others.
Some Examples....
![Config](https://i.imgur.com/Pfok2ob.png)

# Tautulli Specific 
If you want Tautulli to calculate the total file size for TV Shows/Seasons and Artists/Albums, you must enable "Calculate Total File Sizes" in Settings > General AND refresh media info. 
Some Scipts directly call Tautulli SQL, In order for this to work, you must set "api_sql = 1" in the Tautulli config file. It will require a restart of Tautulli.

# HowTo Discord Webhook 
Information on how to set up a Discord webhook can be found be [here.](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)

# Examples
Tautulli_Monthly.ps1 - Whole Year in Monthly Stats.
Chart will be created in Powershell without the need of Excel ("System.Windows.Forms.DataVisualization")
This Script requires Powershell Core!!!

![Tautulli_Monthly.ps1](https://i.imgur.com/Hnf5S6N.png)

Tautulli_Stats.ps1 - Top Everything

![Media Stats](https://i.imgur.com/bWzEEUJ.png)

Tautulli_Stats.ps1 - Concurrent Streams

![Streams](https://i.imgur.com/IKQxQwo.png)

Recently_Added.ps1 - Last x Days back -  Movies/Shows added to Plex.

![Recently_Added](https://i.imgur.com/znJh1Pw.png)

