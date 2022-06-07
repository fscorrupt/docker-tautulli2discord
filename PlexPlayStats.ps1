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

# Path to where the chart image should be saved and sent from
[string]$strImagePath = "$PSScriptRoot\config\MonthlyStats.png"

# PowerShell variables
[string]$strSendScriptFilePath = "$PSScriptRoot\SendFileToDiscord.ps1"

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
function New-ChartImage {
   # Chart Creator
   $null = [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
   
   # Chart Object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 1200
   $chart1.Height = 500
   $chart1.BackColor = [System.Drawing.Color]::White
   
   # Title
   $null = $chart1.Titles.Add("Monthly Plays!")
   $chart1.Titles[0].Font = "Calibri,18pt"
   $chart1.Titles[0].Alignment = "topCenter"
   
   # Chart Area
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Number of Plays"
   $chartarea.AxisX.Title = "Month"
   $chartarea.AxisY.Interval = 50
   $chartarea.AxisX.Interval = 1
   $chart1.ChartAreas.Add($chartarea)
   
   # Legend
   $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
   $legend.name = "Legend1"
   $chart1.Legends.Add($legend)
   
   # Data Series - Month
   $null = $chart1.Series.Add("Month")
   $chart1.Series["Month"].ChartType = "Column"
   $chart1.Series["Month"].BorderWidth  = 3
   $chart1.Series["Month"].IsVisibleInLegend = $false
   $chart1.Series["Month"].chartarea = "ChartArea1"
   $chart1.Series["Month"].Legend = "Legend1"
   $chart1.Series["Month"].color = "#90b19c"
   $arrPlaysPerMonth.Month | ForEach-Object {$chart1.Series["Month"].Points.addxy($_, $_) } | Out-Null
   
   # Data Series - Movie Plays
   $null = $chart1.Series.Add("MoviePlays")
   $chart1.Series["MoviePlays"].ChartType = "Column"
   $chart1.Series["MoviePlays"].BorderWidth  = 3
   $chart1.Series["MoviePlays"].IsVisibleInLegend = $true
   $chart1.Series["MoviePlays"].chartarea = "ChartArea1"
   $chart1.Series["MoviePlays"].Legend = "Legend1"
   $chart1.Series["MoviePlays"].color = "#5B9BD5"
   $arrPlaysPerMonth.MoviePlays | ForEach-Object {$chart1.Series["MoviePlays"].Points.addxy("MoviePlays", $_) } | Out-Null
   
   # Data Series - TV plays
   $null = $chart1.Series.Add("TVPlays")
   $chart1.Series["TVPlays"].ChartType = "Column"
   $chart1.Series["TVPlays"].BorderWidth  = 3
   $chart1.Series["TVPlays"].IsVisibleInLegend = $true
   $chart1.Series["TVPlays"].chartarea = "ChartArea1"
   $chart1.Series["TVPlays"].Legend = "Legend1"
   $chart1.Series["TVPlays"].color = "#ED7D31"
   $arrPlaysPerMonth.TVPlays | ForEach-Object {$chart1.Series["TVPlays"].Points.addxy("TVPlays", $_) } | Out-Null
   
   # Data Series - Music Plays
   $null = $chart1.Series.Add("MusicPlays")
   $chart1.Series["MusicPlays"].ChartType = "Column"
   $chart1.Series["MusicPlays"].BorderWidth  = 3
   $chart1.Series["MusicPlays"].IsVisibleInLegend = $true
   $chart1.Series["MusicPlays"].chartarea = "ChartArea1"
   $chart1.Series["MusicPlays"].Legend = "Legend1"
   $chart1.Series["MusicPlays"].color = "#A5A5A5"
   $arrPlaysPerMonth.MusicPlays | ForEach-Object {$chart1.Series["MusicPlays"].Points.addxy("MusicPlays", $_) } | Out-Null
   
   # Data Series - Total Plays
   $null = $chart1.Series.Add("TotalPlays")
   $chart1.Series["TotalPlays"].ChartType = "Column"
   $chart1.Series["TotalPlays"].BorderWidth  = 3
   $chart1.Series["TotalPlays"].IsVisibleInLegend = $true
   $chart1.Series["TotalPlays"].chartarea = "ChartArea1"
   $chart1.Series["TotalPlays"].Legend = "Legend1"
   $chart1.Series["TotalPlays"].color = "#FFC000"
   $arrPlaysPerMonth.TotalPlays | ForEach-Object {$chart1.Series["TotalPlays"].Points.addxy("TotalPlays", $_) } | Out-Null
   
   # Save Chart as Image
   $chart1.SaveImage($strImagePath,"png")
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[object]$objPlaysPerMonth = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_plays_per_month"
[array]$arrLast12Months = $objPlaysPerMonth.response.data.categories
[array]$arrMoviePlaysPerMonth = ($objPlaysPerMonth.response.data.series | Where-Object -Property name -eq 'Movies').data
[array]$arrTVPlaysPerMonth = ($objPlaysPerMonth.response.data.series | Where-Object -Property name -eq 'TV').data
[array]$arrMusicPlaysPerMonth = ($objPlaysPerMonth.response.data.series | Where-Object -Property name -eq 'Music').data

# Loop through each library
[System.Collections.ArrayList]$arrPlaysPerMonth = @()
$i = 0
foreach($month in $arrLast12Months) {
   [hashtable]$htbCurrentMonthPlayStats = @{
      Month = $month
      MoviePlays = $arrMoviePlaysPerMonth[$i]
      TVPlays = $arrTVPlaysPerMonth[$i]
      MusicPlays = $arrMusicPlaysPerMonth[$i]
      TotalPlays = $arrMoviePlaysPerMonth[$i] + $arrTVPlaysPerMonth[$i] + $arrMusicPlaysPerMonth[$i]
   }
   
   # Add section data results to final object
   $null = $arrPlaysPerMonth.Add($htbCurrentMonthPlayStats)
   $i++
}

if ($objConfig.ScriptSettings.$strScriptName.RemoveMonthsWithZeroPlays) {
   # Remove any lines with all 0s
   $arrPlaysPerMonth = $arrPlaysPerMonth | Where-Object -Property TotalPlays -gt 0
}

# Create Chart (Call function)
New-ChartImage

# Convert results to string and send to Discord
[string]$strBody = $arrPlaysPerMonth | ForEach-Object {[PSCustomObject]$_} | Format-Table -AutoSize -Property Month, MoviePlays, TVPlays, MusicPlays, TotalPlays | Out-String
[object]$objPayload = @{
   content = @"
**Monthly Plays:**
``````
$strBody
``````
"@
} | ConvertTo-Json -Depth 4
Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload

# Call $strSendScriptFilePath to send the newly created image to Discord via PS v6+
$null = & pwsh -NoLogo -NonInteractive -ExecutionPolicy Bypass -File $strSendScriptFilePath -FilePath $strImagePath -WebhookUrl $strDiscordWebhook
