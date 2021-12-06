Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
$WebhookName = "CurrentStreams"

# Log file path
#$StreamLog = "C:\Users\Shayne\Google Drive\Plex Stuff\PowerShell\StreamLog.txt"
$StreamLog = "$PSScriptRoot\StreamLog.txt"

# This script requires an API from TheMovieDB.org
$tmdb_api = "XXXXXXXXXXXXXXXXXXXXXXXXX"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function SendStringToDiscord($url, $body) {
   $payload = [PSCustomObject]@{
      embeds = $body
   }
   
   try {
      Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
      Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord." -ForegroundColor Red
   }
}

# Parse the config file and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json

[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_activity"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$streams = $dataResult.response.data.sessions

# Loop through each stream
[System.Collections.ArrayList]$embedCurrentStreams = @()
foreach ($stream in $streams) {
   $cleanTitle = $stream.full_title `
      -replace '·', ' ' `
      -replace 'ö','oe' `
      -replace 'ä','ae' `
      -replace 'ü','ue' `
      -replace 'ß','ss' `
      -replace 'Ö','Oe' `
      -replace 'Ü','Ue' `
      -replace 'Ä','Ae' `
      -replace 'é','e' `
      -replace "'", ''
   
   # TV
   if ($stream.media_type -eq "episode") {
      $tmdb_id = ($stream.guids[1]).Split('/')[2]
      $tmdbResults = Invoke-RestMethod -Method Get -Uri ("https://api.themoviedb.org/3/tv/" + $tmdb_id + "?api_key=" + $tmdb_api + "&language=en-US")
      
      $embedObject = [PSCustomObject]@{
         color = '40635'
         title = $cleanTitle
         url = "https://www.themoviedb.org/tv/$tmdb_id"
         author = [PSCustomObject]@{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $stream.grandparent_rating_key
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = $stream.summary
         thumbnail = [PSCustomObject]@{url = "https://image.tmdb.org/t/p/w500" + $($tmdbResults.poster_path)}
         fields = [PSCustomObject]@{
            name = 'User'
            value = $stream.friendly_name
            inline = $false
         },[PSCustomObject]@{
            name = 'Season'
            value = $stream.parent_media_index
            inline = $true
         },[PSCustomObject]@{
            name = 'Episode'
            value = $stream.media_index
            inline = $true
         }
         footer = [PSCustomObject]@{
            text = $stream.state + " - $($stream.progress_percent)%"
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
         #timestamp = "2015-12-31T12:00:00.000Z"
       }
   }
   # MUSIC
   elseif($stream.media_type -eq 'track') {
      $embedObject = [PSCustomObject]@{
         color = '3066993'
         title = $stream.full_title
         #url = "https://www.themoviedb.org/movie/"
         author = [PSCustomObject]@{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $stream.rating_key
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = $stream.summary
         #thumbnail = [PSCustomObject]@{url = "https://image.tmdb.org/t/p/w500" + $($json.poster_path)}
         fields = [PSCustomObject]@{
            name = 'User'
            value = $stream.friendly_name
            inline = $false
         },[PSCustomObject]@{
            name = 'Album'
            value = $stream.parent_title
            inline = $true
         },[PSCustomObject]@{
            name = 'Track'
            value = $stream.media_index
            inline = $true
         }
         footer = [PSCustomObject]@{
            text = $stream.state + " - $($stream.progress_percent)%"
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
       }
   }
   # MOVIE
   else {
      $tmdb_id = ($stream.guids[1]).Split('/')[2]
      $tmdbResults = Invoke-RestMethod -Method Get -Uri ("https://api.themoviedb.org/3/movie/" + $tmdb_id + "?api_key=" + $tmdb_api + "&language=en-US")
      
      $embedObject = [PSCustomObject]@{
         color = '13400320'
         title = $cleanTitle
         url = "https://www.themoviedb.org/movie/$tmdb_id"
         author = [PSCustomObject]@{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $stream.rating_key
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = $stream.summary
         thumbnail = [PSCustomObject]@{url = "https://image.tmdb.org/t/p/w500" + $($tmdbResults.poster_path)}
         fields = [PSCustomObject]@{
            name = 'User'
            value = $stream.friendly_name
            inline = $false
         },[PSCustomObject]@{
            name = 'Resolution'
            value = $stream.stream_video_full_resolution
            inline = $true
         },[PSCustomObject]@{
            name = 'Direct Play/Transcode'
            value = $stream.transcode_decision
            inline = $true
         }
         footer = [PSCustomObject]@{
            text = $stream.state + " - $($stream.progress_percent)%"
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
       }
   }
   
   # Add line results to final object
   $embedCurrentStreams.Add($embedObject)
}

if (!(Test-Path $StreamLog)) { # Log file doesn't exist. Create it and update Discord
   # Create the log file
   $streams.Count | Out-File -FilePath $StreamLog -Force
   
   # Send to Discord
   SendStringToDiscord -url $DiscordURL -body $embedCurrentStreams
}
else { # Log file exists.
   [int]$lastStreamCount = Get-Content $StreamLog | Out-String
   
   if ($lastStreamCount -eq 0 -and $streams.Count -eq 0) { # Log file and current stream count are both 0. Do not update.
      Write-Host "Nothing to update"
   }
   else { 
      # Update the log file
      $streams.Count | Out-File -FilePath $StreamLog -Force
      
      if ($embedCurrentStreams.Count -gt 0) {
         SendStringToDiscord -url $DiscordURL -body $embedCurrentStreams
      }
      else {
         [System.Collections.ArrayList]$embedCurrentStreams = @()
         $embedObject = [PSCustomObject]@{
            color = '15158332'
            title = "Nothing is currently streaming"
            timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
         }
         $embedCurrentStreams.Add($embedObject)
         SendStringToDiscord -url $DiscordURL -body $embedCurrentStreams
      }
   }
}
