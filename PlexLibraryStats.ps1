Clear-Host

<############################################################
    Note - For this script to include library sizes, you need to
    go into Tautulli > Settings > General > and enable
    "Calculate Total File Sizes". It may take a while for
    Tautulli to update the stats, depending on your
    library sizes.
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot/config/config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'PlexLibraryStats'

<############################################################
    Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
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
[array]$arrExcludedLibraries = $objConfig.ScriptSettings.$strScriptName.ExcludedLibraries
[array]$arrIncludedLibraries = $objConfig.ScriptSettings.$strScriptName.IncludedLibraries
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[object]$objLibrariesTable = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_libraries_table&length=100"
[object]$objLibraries = $objLibrariesTable.response.data.data | Select-Object section_id, section_name, section_type, count, parent_count, child_count | Where-Object -Property section_name -notin ($arrExcludedLibraries) 

# Loop through each library
[System.Collections.ArrayList]$arrLibraryStats = @()
if($arrIncludedLibraries){
  foreach ($Library in $objLibraries){
    if ($Library.section_name -in $arrIncludedLibraries){
      [float]$fltTotalSizeBytes = (Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_library_media_info&section_id=$($Library.section_id)").response.data.total_file_size
   
      if ($fltTotalSizeBytes -ge '1000000000000'){
        [string]$strFormat = 'Tb'
        [float]$fltFormattedSize = [math]::round($fltTotalSizeBytes / 1Tb, 2)
      }
      else{
        [string]$strFormat = 'Gb'
        [float]$fltFormattedSize = [math]::round($fltTotalSizeBytes / 1Gb, 2)
      }
   
      # Fill Temp object with current section data
      [hashtable]$htbCurrentLibraryStats = @{
        Library = $Library.section_name
        Type = $Library.section_type
        Count = $Library.count
        SeasonAlbumCount= $Library.parent_count
        EpisodeTrackCount = $Library.child_count
        Size = $fltFormattedSize
        Format = $strFormat
      }
   
      # Add section data results to final object
      $null = $arrLibraryStats.Add($htbCurrentLibraryStats)
    }
  }
}
Else{
  foreach ($Library in $objLibraries){
    [float]$fltTotalSizeBytes = (Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_library_media_info&section_id=$($Library.section_id)").response.data.total_file_size
   
    if ($fltTotalSizeBytes -ge '1000000000000'){
      [string]$strFormat = 'Tb'
      [float]$fltFormattedSize = [math]::round($fltTotalSizeBytes / 1Tb, 2)
    }
    else{
      [string]$strFormat = 'Gb'
      [float]$fltFormattedSize = [math]::round($fltTotalSizeBytes / 1Gb, 2)
    }
   
    # Fill Temp object with current section data
    [hashtable]$htbCurrentLibraryStats = @{
      Library = $Library.section_name
      Type = $Library.section_type
      Count = $Library.count
      SeasonAlbumCount= $Library.parent_count
      EpisodeTrackCount = $Library.child_count
      Size = $fltFormattedSize
      Format = $strFormat
    }
   
    # Add section data results to final object
    $null = $arrLibraryStats.Add($htbCurrentLibraryStats)
  }
}
# Sort the results
$arrLibraryStats = $arrLibraryStats | Sort-Object -Property Library, Type
[string]$strBody = $null
  
foreach($Library in $arrLibraryStats){
    if ($Library.Library -eq 'Audiobooks') {
      $strBody += "> $($Library.Library) - **$($Library.count)** authors, **$($Library.SeasonAlbumCount)** books, **$($Library.EpisodeTrackCount)** chapters. ($($Library.Size)$($Library.Format))`n"
    }
    elseif ($Library.Type -eq 'movie') {
      $strBody += "> $($Library.Library) - **$($Library.count)** movies. ($($Library.Size)$($Library.Format))`n"
    }
    elseif ($Library.Type -eq 'show') {
      $strBody += "> $($Library.Library) - **$($Library.count)** shows, **$($Library.SeasonAlbumCount)** seasons, **$($Library.EpisodeTrackCount)** episodes. ($($Library.Size)$($Library.Format))`n"
    }
    elseif ($Library.Type -eq 'artist') {
      $strBody += "> $($Library.Library) - **$($Library.count)** artists, **$($Library.SeasonAlbumCount)** albums, **$($Library.EpisodeTrackCount)** tracks. ($($Library.Size)$($Library.Format))`n"
    }
  }
  
  [object]$objPayload = @{
    content = "**Library stats:**`n$strBody"
  } | ConvertTo-Json -Depth 4
  Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
