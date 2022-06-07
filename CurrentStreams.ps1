Clear-Host

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config\config.json"

# Log file path
[string]$strStreamLogPath = "$PSScriptRoot\config\log\StreamLog.txt"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'CurrentStreams'

<############################################################
    Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
function Get-TMDBInfo {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strAPIKey,
      
      [Parameter(Mandatory)]
      [ValidateSet('tv', 'movie')]
      [string]$strMediaType,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strTMDB_ID
   )
   [object]$objResults = Invoke-RestMethod -Method Get -Uri "https://api.themoviedb.org/3/$($strMediaType)/$($strTMDB_ID)?api_key=$($strAPIKey)&language=en-US"
   
   return $objResults
}
function Get-SanitizedString {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strInputString
   )
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
      '”' = '"'
      '·' = '-'
      ':' = ''
      $regAppendedYear = ''
   }
   
   foreach($key in $htbReplaceValues.Keys){
      $strInputString = $strInputString -Replace($key, $htbReplaceValues.$key)
   }
   return $strInputString
}
function Push-ObjectToDiscord {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strDiscordWebhook,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [object]$objPayload
   )
   try {
      $null = Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/Json'
      Start-Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord. $($_)" -ForegroundColor Red
      Write-Host $objPayload
   }
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[string]$strTMDB_APIKey = $objConfig.TMDB.APIKey

# Get PMS Identifier
[object]$objPlexServerIdentifier = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_server_info"
[string]$strPlexServerIdentifier = ($objPlexServerIdentifier.response.data | Select-Object -ExpandProperty pms_identifier)

# Attempt to get Plex activity from Tautulli
try {
   [object]$objCurrentActivity = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_activity"
   [array]$arrCurrentStreams = $objCurrentActivity.response.data.sessions
}
catch {
   [object]$objPayload = @{
      username = "Current Streams"
      content = "**Could not get current streams from Tautulli.**`nError message:`n$($_)"
   } | ConvertTo-Json -Depth 4
   
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
   exit
}

# Loop through each stream
[System.Collections.ArrayList]$arrCurrentStreamsEmbed = @()
foreach ($stream in $arrCurrentStreams) {
   [string]$strSanitizedTitle = Get-SanitizedString -strInputString $stream.title
   # TV
   if ($stream.media_type -eq 'episode') {
      [string]$strTMDB_ID = ($stream.guids | Where-Object {$_ -match 'tmdb'}).Split('/')[2]
      [object]$objTMDBResults = Get-TMDBInfo -strAPIKey $strTMDB_APIKey -strMediaType tv -strTMDB_ID $strTMDB_ID
      
      [hashtable]$htbEmbedParameters = @{
         color = '40635'
         title = $strSanitizedTitle
         url = "https://www.themoviedb.org/tv/$strTMDB_ID"
         author = @{
            name = 'Open on Plex'
            url = "https://app.plex.tv/desktop/#!/server/$strPlexServerIdentifier/details?key=%2Flibrary%2Fmetadata%2F$($stream.grandparent_rating_key)"
            icon_url = 'https://i.imgur.com/FNoiYXP.png'
         }
         description = Get-SanitizedString -strInputString $stream.summary
         thumbnail = @{url = "https://image.tmdb.org/t/p/w500$($objTMDBResults.poster_path)"}
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
            url = "https://app.plex.tv/desktop/#!/server/$strPlexServerIdentifier/details?key=%2Flibrary%2Fmetadata%2F$($stream.rating_key)"
            icon_url = 'https://i.imgur.com/FNoiYXP.png'
         }
         description = Get-SanitizedString -strInputString $stream.summary
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
            url = "https://app.plex.tv/desktop/#!/server/$strPlexServerIdentifier/details?key=%2Flibrary%2Fmetadata%2F$($stream.rating_key)"
            icon_url = 'https://i.imgur.com/FNoiYXP.png'
         }
         description = Get-SanitizedString -strInputString $stream.summary
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

[object]$objPayload = @{
   username = "Current Streams"
   content = "**Current Streams on Plex:**"
   embeds = $arrCurrentStreamsEmbed
} | ConvertTo-Json -Depth 4

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
