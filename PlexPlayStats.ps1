Clear-Host

<############################################################
    Note - For this script to send files to Discord, you must
    have PowerShell 6 or newer installed and have
    "PSCoreFilePath" configured in config.json Install
    relevant PS version from here:
    https://github.com/PowerShell/PowerShell/releases
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = "PlexPlayStats"

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

$objTemplate = '' | Select-Object -Property Month, MoviePlays, TVPlays, TotalPlays
$objResult = @()

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[object]$objPlaysPerMonth = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_plays_per_month"
[array]$arrLast12Months = $objPlaysPerMonth.response.data.categories
[array]$arrMoviePlaysPerMonth = ($objPlaysPerMonth.response.data.series | Where-Object -Property name -eq 'Movies').data
[array]$arrTVPlaysPerMonth = ($objPlaysPerMonth.response.data.series | Where-Object -Property name -eq 'TV').data

$i = 0
foreach($month in $arrLast12Months) {
  #Fill Temp object with current section data
  $objTemp = $objTemplate | Select-Object *
  $objTemp.Month = $month -replace 'ä', 'a'
  $objTemp.MoviePlays = $arrMoviePlaysPerMonth[$i]
  $objTemp.TVPlays = $arrTVPlaysPerMonth[$i]
  #$objTemp.MusicPlays= $Musicplays[$i]
  $objTemp.TotalPlays= $arrMoviePlaysPerMonth[$i] + $arrTVPlaysPerMonth[$i]

  #Add section data results to final object
  $objResult += $objTemp

  $i++
}

# Convert the object to a string
$stringResult = $objResult | Out-String

[object]$objPayload = @{
  content = @"
**Monthly Plays:**
``````
$stringResult
``````
"@
} | ConvertTo-Json -Depth 4
Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload.Replace('\r\n\r\n\u001b[32;1m','').replace('\n\u001b[32;1m','').replace('\u001b[0m','')
