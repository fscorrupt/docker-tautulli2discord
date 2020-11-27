function Remove-Diacritics
{
    Param(
        [String]$inputString
    )
    #replace diacritics
    $sb = [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($inputString))
    return $sb
}

function RecentlyAdded {
  <############################################################

      Do NOT edit lines below unless you know what you are doing!

  ############################################################>

  #Complete API URL
  $apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_recently_added&count=100"

  #Get the Data
  $dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

  #Split Data into Movie/Show/User
  $MovieStats = $dataResult.response.data.recently_added | select title, guid, media_type, rating_key, year, added_at -Unique | where {$_.media_type -eq 'movie'}| where {($_.title -ne '')}| Sort-Object -Property title | select -First $MovieCount
  $ShowStats = $dataResult.response.data.recently_added | select grandparent_title, parent_title, Title, media_index, grandparent_rating_key, media_type, added_at  -Unique | where {$_.media_type -eq 'episode'}| where {($_.title -ne '')}| Sort-Object -Property grandparent_title | select -First $ShowCount

  #Generate nice looking Output....
  foreach ($Movie in $MovieStats){
    $DateAdded = (Get-Date 01.01.1970).AddSeconds($Movie.added_at)
    $DateBack = (Get-Date).AddDays(-$DaysBack)
    if ($DateAdded -ge $DateBack){
      $RatingKey = $Movie.rating_key
      # This section gets TMDB Url
      $query = "
        SELECT themoviedb_url
        FROM themoviedb_lookup 
        WHERE rating_key = '$RatingKey'
      "

      #Complete API URL for SQL querying
      $apiSQLQueryURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query

      $SQLQuerydataResult = Invoke-RestMethod -Method Get -Uri $apiSQLQueryURL
      $MovieTitle = Remove-Diacritics -inputString $Movie.title
      $MovieStat = $SQLQuerydataResult.response.data.themoviedb_url
      $MovieList += "> "+"["+$MovieTitle+" ("+$Movie.year+")](<"+$MovieStat+">)"+"`n"
    }
   }

  foreach ($Show in $ShowStats){
    $DateAdded = (Get-Date 01.01.1970).AddSeconds($Show.added_at)
    $DateBack = (Get-Date).AddDays(-$DaysBack)
    if ($DateAdded -ge $DateBack){
      $RatingKey = $Show.grandparent_rating_key
      # This section gets TMDB Url
      $query = "
        SELECT themoviedb_url
        FROM themoviedb_lookup 
        WHERE rating_key = '$RatingKey'
      "

      #Complete API URL for SQL querying
      $apiSQLQueryURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query

      $SQLQuerydataResult = Invoke-RestMethod -Method Get -Uri $apiSQLQueryURL

      $ShowStat = $SQLQuerydataResult.response.data.themoviedb_url
      $ShowTitle = Remove-Diacritics -inputString $Show.grandparent_title
      $ShowList += "> "+"["+$ShowTitle.Replace('-',' ').Replace('Ã©','e').Replace("'",'').Replace("!",'').Replace("&",'and').Replace("#",'').Replace(":",'').Replace("(",'').Replace(")",'')+"](<"+$ShowStat+">)"+" - "+$Show.parent_title +" / Episode "+$Show.media_index+"`n"
    }
  }

  #Generate Content. 
  $MovieContent = @"
  $HeadingMovie
  $MovieList
"@

  $ShowContent = @"
  $HeadingShow
  $ShowList
"@

  #Send top 10 Movies to Discord
  $MoviePayload = [PSCustomObject]@{content = $MovieContent}
  Invoke-RestMethod -Uri $uri -Body ($MoviePayload | ConvertTo-Json) -Method Post -ContentType 'Application/Json'

  #Send top 10 Shows to Discord
  $ShowPayload = [PSCustomObject]@{content = $ShowContent}
  Invoke-RestMethod -Uri $uri -Body ($ShowPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

}

# Top Play Movie/Show Count
$MovieCount = '25' # The Content Lenght from Discord webhook is limited to 2000, so this value works best for me (if you have more then 25 new movies a day, i would suggest you to send the webhook more then once a day
$ShowCount = '30' # The Content Lenght from Discord webhook is limited to 2000, so this value works best for me (if you have more then 30 new Shows a day, i would suggest you to send the webhook more then once a day
# How many Days do you want to look Back?
$DaysBack = '1'
# Discord Webhook Prod Uri
$Uri = 'https://discordapp.com/api/webhooks/XXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
# Tautulli Api Key
$apiKey='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
# Tautulli Url with port
$URL = "http://XXXXXXXXXXXXXXXXXXXXXXX:8181"

# Cosmetics
# Clear previously used variables
$MovieList = $null
$ShowList = $null

$CountdataResultMovie = $null
$CountdataResultShow = $null
# Headings
$HeadingMovie = "Recently Added **Movies** in the last $DaysBack Days!"
$HeadingShow = "Recently Added **Shows** in the last $DaysBack Days!"  

RecentlyAdded
