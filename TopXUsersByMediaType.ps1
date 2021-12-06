Clear-Host

<############################################################

Note - In order for this to work, you must set "api_sql = 1"
       in the Tautulli config file. It will require a restart
       of Tautulli.

#############################################################>

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
$WebhookName = "Top5"

# Top Play Movie/Show Count
$Count = '5'

# How many Days do you want to look Back?
$Days = '30'

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function SendStringToDiscord {
   [CmdletBinding()]
      param(
         [Parameter(Position = 0, Mandatory)]
         [ValidateNotNullOrEmpty()]
         [string]
         $title,
         
         [Parameter(Position = 1, Mandatory)]
         [ValidateNotNullOrEmpty()]
         [string]
         $body
      )
   
   $Content = @"
$title
$body
"@
   
   $Payload = [PSCustomObject]@{content = $Content}
   try {
      Invoke-RestMethod -Uri $script:DiscordURL -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
      Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord." -ForegroundColor Red
   }
}

# Parse the config file and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json

# This query gets plays by media type
$query = "
SELECT
CASE
   WHEN friendly_name IS NULL THEN username
   ELSE friendly_name
END AS friendly_name,
CASE
   WHEN media_type = 'episode' THEN 'TV Show'
   WHEN media_type = 'movie' THEN 'Movie'
   WHEN media_type = 'track' THEN 'Music'
   ELSE media_type
END AS media_type,
count(user) AS plays
FROM (
   SELECT
   session_history.user,
   session_history.user_id,
   users.username,
   users.friendly_name,
   started,
   session_history_metadata.media_type
   FROM session_history
   JOIN session_history_metadata
      ON session_history_metadata.id = session_history.id
   LEFT OUTER JOIN users
      ON session_history.user_id = users.user_id
   WHERE datetime(session_history.stopped, 'unixepoch', 'localtime') >= datetime('now', '-$Days days', 'localtime')
   AND users.user_id <> 0
   GROUP BY session_history.reference_id
) AS Results
GROUP BY user, media_type
"


[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$TopUsers_Movies = $DataResult.response.data | Where-Object -Property media_type -EQ 'Movie' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $count
$TopUsers_TV = $DataResult.response.data | Where-Object -Property media_type -EQ 'TV Show' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $count
$TopUsers_Music = $DataResult.response.data | Where-Object -Property media_type -EQ 'Music' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $count

# Clear previously used variables
$UserMoviePlays = $null
$UserTVPlays = $null
$UserMusicPlays = $null
$MovieList = $null
$ShowList = $null
$UserList = $null
$ArtistList = $null
$PlatformList = $null
$StreamList = $null

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$top_movies = ($DataResult.response.data | Where -property stat_id -eq "popular_movies").rows
$top_tv = ($DataResult.response.data | Where -property stat_id -eq "popular_tv").rows
$top_music = ($DataResult.response.data | Where -property stat_id -eq "popular_music").rows
$top_users = ($DataResult.response.data | Where -property stat_id -eq "top_users").rows
$top_platforms = ($DataResult.response.data | Where -property stat_id -eq "top_platforms").rows
$most_concurrent = ($DataResult.response.data | Where -property stat_id -eq "most_concurrent").rows

foreach ($user in $TopUsers_Movies) {
   $UserMoviePlays += "> $($user.friendly_name) - **$($user.plays)** Plays`n"
}

foreach ($user in $TopUsers_TV) {
   $UserTVPlays += "> $($user.friendly_name) - **$($user.plays)** Plays`n"
}

foreach ($user in $TopUsers_Music) {
   $UserMusicPlays += "> $($user.friendly_name) - **$($user.plays)** Plays`n"
}

foreach ($movie in $top_movies) {
   #Sanitize the movie title. I ran into an issue with "WALL·E" and it would not send to Discord.
   $CleanMovieTitle = $movie.title `
      -replace '·', ' ' `
      -replace 'ö','oe' `
      -replace 'ä','ae' `
      -replace 'ü','ue' `
      -replace 'ß','ss' `
      -replace 'Ö','Oe' `
      -replace 'Ü','Ue' `
      -replace 'Ä','Ae' `
      -replace 'é','e'
   $RatingKey = $movie.rating_key

   # This section gets TMDB Url
   $query = "
   SELECT *
   FROM themoviedb_lookup 
   WHERE rating_key = '$RatingKey'
   "

   #Complete API URL for SQL querying
   $apiSQLQueryURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query
   $SQLQuerydataResult = Invoke-RestMethod -Method Get -Uri $apiSQLQueryURL
   $tmdbURL = $SQLQuerydataResult.response.data.themoviedb_url

   if ($tmdbURL -ne "" -and $tmdbURL -ne $null) {
      $MovieList += "> [$CleanMovieTitle](<$tmdbURL>) - **$($Movie.users_watched)** Users have watched`n"
   }
   else {
      $MovieList += "> $CleanMovieTitle - **$($movie.users_watched)** Users have watched`n"
   }
}

foreach ($show in $top_tv) {
   #Sanitize the show title.
   $CleanShowTitle = $show.title `
      -replace '·', ' ' `
      -replace 'ö','oe' `
      -replace 'ä','ae' `
      -replace 'ü','ue' `
      -replace 'ß','ss' `
      -replace 'Ö','Oe' `
      -replace 'Ü','Ue' `
      -replace 'Ä','Ae' `
      -replace 'é','e'
   $RatingKey = $show.rating_key

   # This section gets TMDB Url
   $query = "
    SELECT *
    FROM themoviedb_lookup 
    WHERE rating_key IN (
	    SELECT
	    rating_key
	    FROM session_history_metadata
	    WHERE media_type = 'episode'
	    AND grandparent_title = '" + ($show.title).Replace("'", "''") + "'
    )
   "

   #Complete API URL for SQL querying
   $apiSQLQueryURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query
   $SQLQuerydataResult = Invoke-RestMethod -Method Get -Uri $apiSQLQueryURL
   $tmdbURL = $SQLQuerydataResult.response.data.themoviedb_url

   if ($tmdbURL -ne "" -and $tmdbURL -ne $null) {
      $ShowList += "> [$CleanShowTitle](<$tmdbURL>) - **$($show.users_watched)** Users have watched`n"
   }
   else {
      $ShowList += "> $CleanShowTitle - **$($show.users_watched)** Users have watched`n"
   }
}

foreach ($artist in $top_music) {
   $ArtistList += "> $($artist.title) - **$($artist.users_watched)** Users have listened`n"
}

foreach ($user in $top_users) {
   $ts = New-TimeSpan -Seconds $user.total_duration
   $UserList += "> $($user.friendly_name) - **$($user.total_plays)** Plays for a total of $($ts.Days) days, $($ts.Hours) hours, $($ts.Minutes) minutes`n"
}

foreach ($platform in $top_platforms) {
   $PlatformList += "> $($platform.platform) - **$($platform.total_plays)** Plays`n"
}

foreach ($stream in $most_concurrent) {
   $StreamList += "> $($stream.title) - **$($stream.count)**`n"
}

SendStringToDiscord -title "Top $Count **Users** overall in the last $Days Days!" -body $UserList

SendStringToDiscord -title "Top $Count **Users** in Movies for the last $Days Days!" -body $UserMoviePlays

SendStringToDiscord -title "Top $Count **Users** in TV for the last $Days Days!" -body $UserTVPlays

SendStringToDiscord -title "Top $Count **Users** in Music for the last $Days Days!" -body $UserMusicPlays

SendStringToDiscord -title "Top $Count most popular **Movies** in the last $Days Days!" -body $MovieList

SendStringToDiscord -title "Top $Count most popular **Shows** in the last $Days Days!" -body $ShowList

SendStringToDiscord -title "Top $Count most popular **Artists** in the last $Days Days!" -body $ArtistList

SendStringToDiscord -title "Top $Count **Platforms** in the last $Days Days!" -body $platformList

SendStringToDiscord -title "Top **Concurrent Streams** in the last $Days Days!" -body $StreamList
