Clear-Host

# For this script to include library sizes, you need to go into
# Tautulli > Settings > General > and enable "Calculate Total File Sizes".
# It may take a while for Tautulli to update the stats, depending on your library sizes.

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the config file under "[Webhooks]".
$WebhookName = "LibraryStats"

# Libraries to exclude
$ExcludedLibraries = @('Photos', 'Live TV', 'Fitness')

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
[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_libraries_table"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$Sections = $DataResult.response.data.data | Select section_id, section_name, section_type, count, parent_count, child_count | Where-Object -Property section_name -notin ($ExcludedLibraries)

# Clear previously used variables
$MovieList = $null
$ShowList = $null
$body = $null
$objResult = @()

foreach ($Section in $Sections){
   $SizeResult = (Invoke-RestMethod -Method Get -Uri "$URL/api/v2?apikey=$apiKey&cmd=get_library_media_info&section_id=$($Section.section_id)").response.data.total_file_size
   
   if ($SizeResult -ge '1000000000000'){
      $Format = 'Tb'
      $SizeResult = [math]::round($SizeResult /1Tb, 2)
   }
   else{
      $Format = 'Gb'
      $SizeResult = [math]::round($SizeResult /1Gb, 2)
   }
   
   # Fill Temp object with current section data
   $objTemp = [PSCustomObject]@{
      Library = $Section.section_name
      Type = $Section.section_type
      Count = $Section.count
      SeasonAlbumCount= $Section.parent_count
      EpisodeTrackCount = $Section.child_count
      Size = $SizeResult
      Format = $Format
   }
   
   # Add section data results to final object
   $objResult += $objTemp
}

# Sort the results
$objResult = $objResult | Sort-Object -Property Library, Type

foreach($Library in $objResult){
   if ($Library.Library -eq 'Audiobooks') {
      $body += "> $($Library.Library) - **$($Library.count)** authors, **$($Library.SeasonAlbumCount)** books, **$($Library.EpisodeTrackCount)** chapters. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'movie') {
      $body += "> $($Library.Library) - **$($Library.count)** movies. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'show') {
      $body += "> $($Library.Library) - **$($Library.count)** shows, **$($Library.SeasonAlbumCount)** seasons, **$($Library.EpisodeTrackCount)** episodes. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'artist') {
      $body += "> $($Library.Library) - **$($Library.count)** artists, **$($Library.SeasonAlbumCount)** albums, **$($Library.EpisodeTrackCount)** tracks. ($($Library.Size)$($Library.Format))`n"
   }
}

SendStringToDiscord -title "**Library stats:**" -body $body
