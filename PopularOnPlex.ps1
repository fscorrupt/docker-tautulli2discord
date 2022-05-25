Clear-Host

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config.json"
#[string]$strPathToConfig = 'C:\Scripts\config.json' # Used only during testing

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
[string]$strWebhookName = 'PopularOnPlex'

# Top Play Movie/Show Count
[string]$strCount = '5'

# How many Days do you want to look Back?
[string]$strDays = '30'

<############################################################
Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
function Get-TMDBInfo ([string]$strAPIKey, [ValidateSet('tv', 'movie')][string]$strMediaType, [string]$strTitle, [string]$strYear) {
   [string]$strTMDB_URL = "https://api.themoviedb.org/3/search/$($strMediaType)?api_key=$($strAPIKey)&language=en-US&page=1&include_adult=false&year=$($strYear)&query=$strTitle"
   
   # Highly inaccurate method that relies on TMDB's ability to match the search title and year, but what other choice do I have?
   [string]$strMediaID = (Invoke-RestMethod -Method Get -Uri $strTMDB_URL).results[0].id
   [object]$objResults = Invoke-RestMethod -Method Get -Uri "https://api.themoviedb.org/3/$($strMediaType)/$($strMediaID)?api_key=$($strAPIKey)&language=en-US"
   
   return $objResults
}
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
      '·' = '-'
      ':' = ''
      $regAppendedYear = ''
   }
   
   foreach($key in $htbReplaceValues.Keys){
      $strInputString = $strInputString -Replace($key, $htbReplaceValues.$key)
   }
   return $strInputString
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
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[string]$strTMDB_APIKey = $objConfig.TMDB.APIKey

# Complete API URL
[string]$strTautulliAPI_URL = "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_home_stats&grouping=1&time_range=$strDays&stats_count=$strCount"
[object]$objDataResult = Invoke-RestMethod -Method Get -Uri $strTautulliAPI_URL
[array]$arrTopMovies = ($objDataResult.response.data | Where-Object -Property stat_id -eq "popular_movies").rows
[array]$arrTopTVShows = ($objDataResult.response.data | Where-Object -Property stat_id -eq "popular_tv").rows

# Clear variables that will be populated
[System.Collections.ArrayList]$arrTopMoviesEmbed = @()
[System.Collections.ArrayList]$arrTopTVShowsEmbed = @()

# Collect Movie information
foreach ($movie in $arrTopMovies) {
   [string]$strSanitizedMovieTitle = Get-SanitizedString $($movie.title)
   [object]$objTMDBMovieResults = Get-TMDBInfo -strAPIKey $strTMDB_APIKey -strMediaType 'movie' -strTitle $strSanitizedMovieTitle -strYear $movie.year
   
   if($objTMDBMovieResults.id -eq '') {
      [hashtable]$htbMovieEmbedParameters = @{
         color = '13400320'
         title = $strSanitizedMovieTitle
         url = "https://www.themoviedb.org/movie/"
         author = @{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $movie.rating_key
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = "Unknown"
         thumbnail = @{url = "https://www.programmableweb.com/sites/default/files/TMDb.jpg"}
         fields = @{
            name = 'Rating'
            value = "??? :star:'s"
            inline = $false
         },@{
            name = 'Users Watched'
            value = $movie.users_watched
            inline = $false
         },@{
            name = 'Released'
            value = $movie.year
            inline = $true
         }
         footer = @{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   else {
      [hashtable]$htbMovieEmbedParameters = @{
         color = '13400320'
         title = $strSanitizedMovieTitle
         url = "https://www.themoviedb.org/movie/$($objTMDBMovieResults.id)"
         author = @{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F$($movie.rating_key)"
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = Get-SanitizedString -strInputString $($objTMDBMovieResults.overview)
         thumbnail = @{url = "https://image.tmdb.org/t/p/w500$($objTMDBMovieResults.poster_path)"}
         fields = @{
            name = 'Rating'
            value = "$($objTMDBMovieResults.vote_average) :star:'s"
            inline = $false
         },@{
            name = 'Users Watched'
            value = $movie.users_watched
            inline = $true
         },@{
            name = 'Released'
            value = $movie.year
            inline = $true
         }
         footer = @{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   $null = $arrTopMoviesEmbed.Add($htbMovieEmbedParameters)
}

# Collect TV Show information
foreach ($show in $arrTopTVShows) {
   [string]$strSanitizedShowTitle = Get-SanitizedString $($show.title)
   [object]$objTMDBTVResults = Get-TMDBInfo -strAPIKey $strTMDB_APIKey -strMediaType 'tv' -strTitle $strSanitizedShowTitle -strYear $show.year
   
   if($objTMDBTVResults.id -eq '') { # This is likely due to RatingKey being changed
      [hashtable]$htbEmbedParameters = @{
         color = '40635'
         title = $strSanitizedShowTitle
         url = "https://www.themoviedb.org/movie/$($json.id)"
         author = @{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $movie.rating_key
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = "Unknown"
         thumbnail = @{url = "https://image.tmdb.org/t/p/w500" + $($json.poster_path)}
         fields = @{
            name = 'Rating'
            value = "??? :star:'s"
            inline = $false
         },@{
            name = 'Users Watched'
            value = $show.users_watched
            inline = $true
         },@{
            name = 'Seasons'
            value = "??? Seasons "
            inline = $true
         },@{
            name = 'Runtime'
            value = "??? Minutes"
            inline = $true
         }
         footer = @{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   else {
      [hashtable]$htbEmbedParameters = @{
         color = '40635'
         title = $strSanitizedShowTitle
         url = "https://www.themoviedb.org/tv/$($objTMDBTVResults.id)"
         author = @{
            name = "Open on Plex"
            url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F$($show.rating_key)"
            icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
         }
         description = Get-SanitizedString -strInputString $objTMDBTVResults.overview
         #description = "Descriptions are broken. Can't figure it out."
         thumbnail = @{url = "https://image.tmdb.org/t/p/w500$($objTMDBTVResults.poster_path)"}
         fields = @{
            name = 'Rating'
            value = "$($objTMDBTVResults.vote_average) :star:'s"
            inline = $false
         },@{
            name = 'Users Watched'
            value = $show.users_watched
            inline = $true
         },@{
            name = 'Seasons'
            value = "$($objTMDBTVResults.number_of_seasons) Seasons "
            inline = $true
         },@{
            name = 'Runtime'
            value = "$($objTMDBTVResults.episode_run_time | Select-Object -First 1) Minutes"
            inline = $true
         }
         footer = @{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
   }
   
   $null = $arrTopTVShowsEmbed.Add($htbEmbedParameters)
}

# Create and send the Movie Payload
[object]$objMoviesPayload = @{
   username = "Popular on Plex"
   content = "**Popular Movies on Plex:**"
   embeds = $arrTopMoviesEmbed
} | ConvertTo-Json -Depth 4

Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objMoviesPayload

# Create and send the TV Show Payload
[object]$objShowsPayload = @{
   username = "Popular on Plex"
   content = "**Popular TV Shows on Plex:**"
   embeds = $arrTopTVShowsEmbed
} | ConvertTo-Json -Depth 4

Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objShowsPayload
