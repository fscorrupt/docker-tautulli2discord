Clear-Host
function LibraryStats {
<############################################################

 Do NOT edit lines below unless you know what you are doing!

############################################################>

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_libraries_table"

# Create empty object
$objTemplate = '' | Select-Object -Property  Library, Type, Count, SeasonAlbumCount, EpisodeTrackCount, Size, Format
$objResult = @()

#Get the Data Count
$CountdataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$Sections = $CountdataResult.response.data.data | Select section_id, section_name, section_type, count, parent_count, child_count | Where-Object -Property section_name -notin ($ExcludedLibraries)

foreach ($Section in $Sections){
   $SizeResult = (Invoke-RestMethod -Method Get -Uri "$URL/api/v2?apikey=$apiKey&cmd=get_library_media_info&section_id=$($Section.section_id)").response.data.total_file_size
   $SizeTotal += (Invoke-RestMethod -Method Get -Uri "$URL/api/v2?apikey=$apiKey&cmd=get_library_media_info&section_id=$($Section.section_id)").response.data.total_file_size

   if ($SizeResult -ge '1000000000000'){
      $Format = 'Tb'
      $SizeResult = [math]::round($SizeResult /1Tb, 2)
   }
   else{
      $Format = 'Gb'
      $SizeResult = [math]::round($SizeResult /1Gb, 2)
   }
   
   #Fill Temp object with current section data
   $objTemp = $objTemplate | Select-Object *
   $objTemp.Library = $Section.section_name
   $objTemp.Type = $Section.section_type
   $objTemp.Count = $Section.count
   $objTemp.SeasonAlbumCount= $Section.parent_count
   $objTemp.EpisodeTrackCount = $Section.child_count
   $objTemp.Size = $SizeResult
   $objTemp.Format = $Format
   
   #Add section data results to final object
   $objResult += $objTemp
}

$objResult = $objResult | Sort-Object -Property Library, Type
$CountdataResultShow = $null

$CountMovie = ($objResult | where Type -eq 'Movie' | Select-Object count | Measure-Object -Property count -Sum).sum
$CountShows = ($objResult | where Type -eq 'show' | Select-Object count | Measure-Object -Property count -Sum).sum

if ($SizeTotal -ge '1000000000000'){
      $TFormat = 'Tb'
      $SizeTotal = [math]::round($SizeTotal /1Tb, 2)
   }
   else{
      $TFormat = 'Gb'
      $SizeTotal = [math]::round($SizeTotal /1Tb, 2)
   }

$CountdataResultShow += "> `n"

foreach($Library in $objResult){
   if ($Library.Type -eq 'movie') {
      $CountdataResultShow += "> $($Library.Library) - **$($Library.count)** movies. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'show') {
      $CountdataResultShow += "> $($Library.Library) - **$($Library.count)** shows, **$($Library.SeasonAlbumCount)** seasons, **$($Library.EpisodeTrackCount)** episodes. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'artist') {
      $CountdataResultShow += "> $($Library.Library) - **$($Library.count)** artists, **$($Library.SeasonAlbumCount)** albums, **$($Library.EpisodeTrackCount)** tracks. ($($Library.Size)$($Library.Format))`n"
   }
}

$CountdataResultShow += "> `n"
$CountdataResultShow += "> Total Movie Count - **$CountMovie** `n"
$CountdataResultShow += "> Total Shows Count - **$CountShows** `n"
$CountdataResultShow += "> Total Library Size - **$SizeTotal $TFormat** `n"

#Generate Content.
$Content = @"
**Library stats:**
$CountdataResultShow
"@

#Send to Discord
$payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
}
function CurrentStreams {
Clear-Host
<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>
#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_activity"

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$streams = $dataResult.response.data.sessions | select user, friendly_name, full_title, video_decision, progress_percent, parent_title, media_index -Unique

foreach ($stream in $streams){
    $videoDecision = ($stream.video_decision).Replace('transcode', 'transcoding').Replace('copy','direct playing')
    $Season = ($stream.parent_title).Replace('Season ','S')
    $Episode = 'EP'+$stream.media_index
    $StreamList += "$($stream.friendly_name) is $($videoDecision) **$($stream.full_title) - $Season $Episode** - $($stream.progress_percent)%`n"
}

if ($StreamList -eq $null -or $StreamList -eq "") {
    $StreamContent = @"
Nothing is currently streaming
"@
}
else {
    $StreamContent = @"
Current streams:
$StreamList
"@
}

if (Test-Path $StreamLog) {
    $lastStreamList = Get-Content $StreamLog | Out-String

    if (($StreamContent -match "Nothing is currently streaming") -and ($lastStreamList -match "Nothing is currently streaming")) {
        Write-Host "Nothing to update"
    }
    else {
        $StreamPayload = [PSCustomObject]@{content = $StreamContent}

        #Send Concurrent Streams to Discord
        Invoke-RestMethod -Uri $uri -Body ($StreamPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
    }
}
}
function Top10 {
  <############################################################

      Do NOT edit lines below unless you know what you are doing!

  ############################################################>

  #Complete API URL
  $apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"

  #Get the Data
  $dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

  #Split Data into Movie/Show/User
  $MovieStats = $dataResult.response.data.rows | select title, guid, media_type, total_plays -Unique | where {($_.total_plays -ne $null) -and ($_.media_type -eq 'movie')}| where {($_.title -ne '')}| Sort-Object -Descending -Property total_plays | select -First $Count
  $ShowStats = $dataResult.response.data.rows | select title, guid, media_type, total_plays -Unique | where {($_.total_plays -ne $null) -and ($_.media_type -eq 'episode')}| where {($_.title -ne '')}| Sort-Object -Descending -Property total_plays | select -First $Count
  $UserStats = $dataResult.response.data.rows | select user, friendly_name, total_plays -Unique | where {($_.user -ne $null) -and ($_.user -ne "") -and ($_.user -ne "Local") -and ($_.total_plays -ne $null)} | Sort-Object -Descending -Property total_plays | select -First $Count

  #Generate nice looking Output....
  foreach ($Movie in $MovieStats){
    $MovieStat=$Movie.guid.replace('//','').split('?').replace('com.plexapp.agents.imdb:','https://www.imdb.com/title/').replace('?lang=de','').replace('?lang=en','')[0]
    $MovieList += "> "+"["+$Movie.title.Replace('ö','oe').Replace('ä','ae').Replace('ü','ue').Replace('ß','ss').Replace('Ö','Oe').Replace('Ü','Ue').Replace('Ä','Ae').Replace('é','e')+"]("+$MovieStat+")"+" - Play Count: "+"**"+$Movie.total_plays+"**"+"`n"
  }

  foreach ($Show in $ShowStats){
    $ShowStat=$Show.guid.replace('//','').split('/').replace('com.plexapp.agents.thetvdb:','https://www.thetvdb.com/?tab=series&id=').replace('com.plexapp.agents.themoviedb:','https://www.thetvdb.com/?tab=series&id=')[0]
    $ShowList += "> "+"["+$Show.title.Replace('Ã©','e').Replace("'",'').Replace("!",'').Replace("&",'and').Replace("#",'').Replace(":",'').Replace("(",'').Replace(")",'')+"]("+$ShowStat+")"+" - Play Count: "+"**"+$Show.total_plays+"**"+"`n"
  }

  foreach ($User in $UserStats){
    $UserList += "> " +"["+$User.friendly_name+"]("+$User.friendly_name+")" + " - Play Count: "+"**"+$User.total_plays+"**"+"`n"
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

  $UserContent = @"
  $HeadingUser
  $UserList
"@

  #Send top 10 Movies to Discord
  $MoviePayload = [PSCustomObject]@{content = $MovieContent}
  Invoke-RestMethod -Uri $uri -Body ($MoviePayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

  #Send top 10 Shows to Discord
  $ShowPayload = [PSCustomObject]@{content = $ShowContent}
  Invoke-RestMethod -Uri $uri -Body ($ShowPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
  
  #Send top 10 Users to Discord
  $UserPayload = [PSCustomObject]@{content = $UserContent}
  Invoke-RestMethod -Uri $uri -Body ($UserPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
}

# Top Play Movie/Show Count
$Count = '10'
# How many Days do you want to look Back?
$Days = '30'
# Discord Webhook Prod Uri
$Uri = 'https://discordapp.com/api/webhooks/XXXXXXXXXX'
# Tautulli Api Key
$apiKey='XXXXXXXXXX'
# Tautulli Url with port
$URL = "http://X.X.X.X:8181"

# Cosmetics
# Clear previously used variables
$StreamList = $null
$MovieList = $null
$ShowList = $null
$UserList = $null
$SizeTotal = $null
$CountdataResultMovie = $null
$CountdataResultShow = $null

# Headings
$HeadingMovie = "Top $Count played **Movies** in the last $Days Days!"
$HeadingShow = "Top $Count played **Shows** in the last $Days Days!"  
$HeadingUser = "Top $Count **Users** in the last $Days Days!"
$HeadingStats = "**Library stats:**"

Top10
LibraryStats
CurrentStreams
