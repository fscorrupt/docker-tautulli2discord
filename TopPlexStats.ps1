Clear-Host

<############################################################
Note - In order for this to work, you must set "api_sql = 1"
       in the Tautulli config file. It will require a restart
       of Tautulli.
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'TopPlexStats'

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
      $null = Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/JSON'
      Start-Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord. $($_)" -ForegroundColor Red
      Write-Host $objPayload
   }
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

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strCount = $objConfig.ScriptSettings.$strScriptName.Count
[string]$strDays = $objConfig.ScriptSettings.$strScriptName.Days
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[string]$strQuery = "
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
   WHERE datetime(session_history.stopped, 'unixepoch', 'localtime') >= datetime('now', '-$strDays days', 'localtime')
   AND users.user_id <> 0
   GROUP BY session_history.reference_id
) AS Results
GROUP BY user, media_type
"
# Get and store results from the query
[object]$objTautulliQueryResults = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=sql&query=$($strQuery)"
[object]$objTopUsersInMovies = $objTautulliQueryResults.response.data | Where-Object -Property media_type -EQ 'Movie' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $strCount
[object]$objTopUsersInTV = $objTautulliQueryResults.response.data | Where-Object -Property media_type -EQ 'TV Show' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $strCount
[object]$objTopUsersInMusic = $objTautulliQueryResults.response.data | Where-Object -Property media_type -EQ 'Music' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $strCount

# Get and store Home Stats from Tautulli
[object]$objTautulliHomeStats = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_home_stats&grouping=1&time_range=$strDays&stats_count=$strCount"
[object]$objTopUsers = ($objTautulliHomeStats.response.data | Where-Object -property stat_id -eq "top_users").rows | Sort-Object -Property total_plays -Descending | Select-Object -Property friendly_name, total_plays
[object]$objTopPlatforms = ($objTautulliHomeStats.response.data | Where-Object -property stat_id -eq "top_platforms").rows  | Sort-Object -Property total_plays -Descending | Select-Object -Property platform, total_plays
[object]$objMostConcurrent = ($objTautulliHomeStats.response.data | Where-Object -property stat_id -eq "most_concurrent").rows | Sort-Object -Property count -Descending | Select-Object -Property title, count

[System.Collections.ArrayList]$arrAllStats = @()
foreach ($user in $objTopUsers) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Users Overall"
      Metric = $user.friendly_name
      Value = "$($user.total_plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($user in $objTopUsersInMovies) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Users in Movies"
      Metric = $user.friendly_name
      Value = "$($user.plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($user in $objTopUsersInTV) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Users in TV"
      Metric = $user.friendly_name
      Value = "$($user.plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($user in $objTopUsersInMusic) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Users in Music"
      Metric = $user.friendly_name
      Value = "$($user.plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($platform in $objTopPlatforms) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Platforms"
      Metric = $platform.platform
      Value = "$($platform.total_plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($stat in $objMostConcurrent) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top Concurrent Streams"
      Metric = $stat.title
      Value = $stat.count
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}

# Group and sort the Array in a logical order
[System.Collections.ArrayList]$arrAllStatsGroupedAndOrdered = @()
foreach ($value in "Top $strCount Users Overall", "Top $strCount Users in Movies", "Top $strCount Users in TV", "Top $strCount Users in Music", "Top $strCount Platforms", 'Top Concurrent Streams') {
   [object]$objGroupInfo = ($arrAllStats | ForEach-Object {[PSCustomObject]$_} | Group-Object -Property Group | Where-Object {$_.Name -eq $value } | Sort-Object Name)
   if($null -ne $objGroupInfo) {
      $null = $arrAllStatsGroupedAndOrdered.Add($objGroupInfo)
   }
}

# Convert results to string and send to Discord
foreach ($group in $arrAllStatsGroupedAndOrdered) {
   [string]$strBody = $group.group | Select-Object -Property Metric, Value | Format-Table -AutoSize -HideTableHeaders | Out-String
   [object]$objPayload = @{
      content = "**$($group.Name)** for the last **$($strDays)** Days!`n``````$strBody``````"
   } | ConvertTo-Json -Depth 4
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}