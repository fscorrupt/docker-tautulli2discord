Clear-Host

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config.json"
#[string]$strPathToConfig = 'C:\Scripts\config.json' # Used only during testing

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
[string]$strWebhookName = 'CurrentStreams'

# Log file path
[string]$strStreamLogPath = "$PSScriptRoot\StreamLog.txt"
[string]$strStreamLogPath = 'C:\Scripts\StreamLog.txt'


<############################################################
Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
function Get-SanitizedString ([string]$strInputString) {
   # Credit to FS.Corrupt for the initial version of this function. https://github.com/FSCorrupt
   [regex]$regAppendedYear = ' \(([0-9]{4})\)' # This will match any titles with the year appended. I ran into issues with 'Yellowstone (2018)'
   [hashtable]$htbReplaceValues = @{
      'ß' = 'ss'
      'à' = 'a'
      'á' = 'a'
      'â' = 'a'
      'ã' = 'a'
      'ä' = 'a'
      'å' = 'a'
      'æ' = 'ae'
      'ç' = 'c'
      'è' = 'e'
      'é' = 'e'
      'ê' = 'e'
      'ë' = 'e'
      'ì' = 'i'
      'í' = 'i'
      'î' = 'i'
      'ï' = 'i'
      'ð' = 'd'
      'ñ' = 'n'
      'ò' = 'o'
      'ó' = 'o'
      'ô' = 'o'
      'õ' = 'o'
      'ö' = 'o'
      'ø' = 'o'
      'ù' = 'u'
      'ú' = 'u'
      'û' = 'u'
      'ü' = 'u'
      'ý' = 'y'
      'þ' = 'p'
      'ÿ' = 'y'
      '“' = '"'
      '·' = ' '
      ':' = ''
      '-' = ' '
      $regAppendedYear = ''
   }
   
   foreach($key in $htbReplaceValues.Keys){
      $strInputString = $strInputString -Replace($key, $htbReplaceValues.$key)
   }
   return $strInputString
}
function Get-TMDBInfo ([string]$strAPIKey, [ValidateSet('tv', 'movie')][string]$strMediaType, [string]$strTMDB_ID) {
   [string]$strTMDB_URL = "https://api.themoviedb.org/3/$($strMediaType)/$($strTMDB_ID)?api_key=$($strTMDB_APIKey)&language=en-US"
   [object]$objResults = Invoke-RestMethod -Method Get -Uri $strTMDB_URL
   
   return $objResults
}
function Push-ObjectToDiscord([string]$strDiscordWebhook, [object]$objPayload) {
   try {
      Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/Json'
      Start-Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord. $($_)" -ForegroundColor Red
      Write-Host $objPayload
   }
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.Webhooks.$strWebhookName
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$apiKey = $objConfig.Tautulli.APIKey
[string]$strTMDB_APIKey = $objConfig.TMDB.APIKey
[string]$strTautulliAPI_URL = "$strTautulliURL/api/v2?apikey=$apiKey&cmd=get_activity"
[object]$objCurrentActivity = Invoke-RestMethod -Method Get -Uri $strTautulliAPI_URL
[array]$arrCurrentStreams = $objCurrentActivity.response.data.sessions

# Loop through each stream
[System.Collections.ArrayList]$arrCurrentStreamsEmbed = @()
foreach ($stream in $arrCurrentStreams) {
   $strSanitizedTitle = Get-SanitizedString -strInputString $stream.grandparent_title
   # TV
   if ($stream.media_type -eq "episode") {
      [string]$strTMDB_ID = ($stream.guids[1]).Split('/')[2]
      [object]$objTMDBResults = Get-TMDBInfo -strAPIKey $strTMDB_APIKey -strMediaType tv -strTMDB_ID $strTMDB_ID
      
      [hashtable]$htbEmbedParameters = @{
         color = '40635'
         title = $strSanitizedTitle
         url = "https://www.themoviedb.org/tv/$strTMDB_ID"
         author = @{
            name = 'Open on Plex'
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F$($stream.grandparent_rating_key)"
            icon_url = 'https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775'
         }
         description = $stream.summary
         thumbnail = @{url = "https://image.tmdb.org/t/p/w500" + $($objTMDBResults.poster_path)}
         fields = @{
            name = 'User'
            value = $stream.friendly_name
            inline = $false
         },@{
            name = 'Season'
            value = $stream.parent_media_index
            inline = $true
         },@{
            name = 'Episode'
            value = $stream.media_index
            inline = $true
         }
         footer = @{
            text = "$($stream.state) - $($stream.progress_percent)%"
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   # MUSIC
   elseif($stream.media_type -eq 'track') {
      [hashtable]$htbEmbedParameters = @{
         color = '3066993'
         title = $strSanitizedTitle
         author = @{
            name = 'Open on Plex'
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F$($stream.rating_key)"
            icon_url = 'https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775'
         }
         description = $stream.summary
         fields = @{
            name = 'User'
            value = $stream.friendly_name
            inline = $false
         },@{
            name = 'Album'
            value = $stream.parent_title
            inline = $true
         },@{
            name = 'Track'
            value = $stream.media_index
            inline = $true
         }
         footer = @{
            text = "$($stream.state) - $($stream.progress_percent)%"
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   # MOVIE
   else {
      [string]$strTMDB_ID = ($stream.guids[1]).Split('/')[2]
      [object]$objTMDBResults = Get-TMDBInfo -strAPIKey $strTMDB_APIKey -strMediaType movie -strTMDB_ID $strTMDB_ID
      
      [hashtable]$htbEmbedParameters = @{
         color = '13400320'
         title = $strSanitizedTitle
         url = "https://www.themoviedb.org/movie/$strTMDB_ID"
         author = @{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F$($stream.rating_key)"
            icon_url = 'https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775'
         }
         description = $stream.summary
         thumbnail = @{url = "https://image.tmdb.org/t/p/w500$($objTMDBResults.poster_path)"}
         fields = @{
            name = 'User'
            value = $stream.friendly_name
            inline = $false
         },@{
            name = 'Resolution'
            value = $stream.stream_video_full_resolution
            inline = $true
         },@{
            name = 'Direct Play/Transcode'
            value = $stream.transcode_decision
            inline = $true
         }
         footer = @{
            text = "$($stream.state) - $($stream.progress_percent)%"
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   
   # Add line results to final object
   $null = $arrCurrentStreamsEmbed.Add($htbEmbedParameters)
}

[object]$objPayload = $arrCurrentStreamsEmbed | ConvertTo-Json -Depth 4

if (!(Test-Path $strStreamLogPath)) { # Log file doesn't exist. Create it and update Discord
   # Create the log file
   $arrCurrentStreams.Count | Out-File -FilePath $strStreamLogPath -Force
   
   # Send to Discord
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}
else { # Log file exists.
   [int]$lastStreamCount = Get-Content $strStreamLogPath | Out-String
   
   if ($lastStreamCount -eq 0 -and $arrCurrentStreams.Count -eq 0) { # Log file and current stream count are both 0. Do not update.
      Write-Host 'Nothing to update.'
   }
   else {
      # Update the log file
      $arrCurrentStreams.Count | Out-File -FilePath $strStreamLogPath -Force
      
      if ($arrCurrentStreamsEmbed.Count -gt 0) {
         Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
      }
      else {
         [object]$objNoStreamsPayload = @{
            embeds = @(
               @{
                  color = '15158332'
                  title = "Nothing is currently streaming"
                  timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
               }
            )
         } | ConvertTo-Json -Depth 4
         Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objNoStreamsPayload
      }
   }
}
