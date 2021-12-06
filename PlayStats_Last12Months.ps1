Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the config file under "[Webhooks]".
$WebhookName = "MonthlyStats"

# Path to where the chart image should be saved and sent from
$ImagePath = "$PSScriptRoot\MonthlyStats.png"

# PowerShell variables - Install relevant PS version from here: https://github.com/PowerShell/PowerShell/releases
$PSCore = "C:\Program Files\PowerShell\7-preview\pwsh.exe" # Sending Files to Discord currently only works with powershell 6+
$SendScriptPath = "$PSScriptRoot\SendFileToDiscord.ps1"

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
``````
$body
``````
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

function CreateChart {
# Chart creator
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

# chart object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 1200
   $chart1.Height = 500
   $chart1.BackColor = [System.Drawing.Color]::White
# title
   [void]$chart1.Titles.Add("Monthly Plays!")
   $chart1.Titles[0].Font = "Calibri,18pt"
   $chart1.Titles[0].Alignment = "topCenter"
# chart area
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Number of Plays"
   $chartarea.AxisX.Title = "Month"
   $chartarea.AxisY.Interval = 50
   $chartarea.AxisX.Interval = 1
   $chart1.ChartAreas.Add($chartarea)
# legend
   $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
   $legend.name = "Legend1"
   $chart1.Legends.Add($legend)
# data series
   [void]$chart1.Series.Add("Month")
   $chart1.Series["Month"].ChartType = "Column"
   $chart1.Series["Month"].BorderWidth  = 3
   $chart1.Series["Month"].IsVisibleInLegend = $false
   $chart1.Series["Month"].chartarea = "ChartArea1"
   $chart1.Series["Month"].Legend = "Legend1"
   $chart1.Series["Month"].color = "#90b19c"
   $objResult.Month | ForEach-Object {$chart1.Series["Month"].Points.addxy($_, $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("MoviePlays")
   $chart1.Series["MoviePlays"].ChartType = "Column"
   $chart1.Series["MoviePlays"].BorderWidth  = 3
   $chart1.Series["MoviePlays"].IsVisibleInLegend = $true
   $chart1.Series["MoviePlays"].chartarea = "ChartArea1"
   $chart1.Series["MoviePlays"].Legend = "Legend1"
   $chart1.Series["MoviePlays"].color = "#5B9BD5"
   $objResult.MoviePlays | ForEach-Object {$chart1.Series["MoviePlays"].Points.addxy("MoviePlays", $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("TVPlays")
   $chart1.Series["TVPlays"].ChartType = "Column"
   $chart1.Series["TVPlays"].BorderWidth  = 3
   $chart1.Series["TVPlays"].IsVisibleInLegend = $true
   $chart1.Series["TVPlays"].chartarea = "ChartArea1"
   $chart1.Series["TVPlays"].Legend = "Legend1"
   $chart1.Series["TVPlays"].color = "#ED7D31"
   $objResult.TVPlays | ForEach-Object {$chart1.Series["TVPlays"].Points.addxy("TVPlays", $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("MusicPlays")
   $chart1.Series["MusicPlays"].ChartType = "Column"
   $chart1.Series["MusicPlays"].BorderWidth  = 3
   $chart1.Series["MusicPlays"].IsVisibleInLegend = $true
   $chart1.Series["MusicPlays"].chartarea = "ChartArea1"
   $chart1.Series["MusicPlays"].Legend = "Legend1"
   $chart1.Series["MusicPlays"].color = "#A5A5A5"
   $objResult.MusicPlays | ForEach-Object {$chart1.Series["MusicPlays"].Points.addxy("MusicPlays", $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("TotalPlays")
   $chart1.Series["TotalPlays"].ChartType = "Column"
   $chart1.Series["TotalPlays"].BorderWidth  = 3
   $chart1.Series["TotalPlays"].IsVisibleInLegend = $true
   $chart1.Series["TotalPlays"].chartarea = "ChartArea1"
   $chart1.Series["TotalPlays"].Legend = "Legend1"
   $chart1.Series["TotalPlays"].color = "#FFC000"
   $objResult.TotalPlays | ForEach-Object {$chart1.Series["TotalPlays"].Points.addxy("TotalPlays", $_) } | Out-Null
# save chart
   $chart1.SaveImage($ImagePath,"png")
}

# Parse the config file and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_per_month"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$months = $dataResult.response.data.categories
$Movieplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Movies').data
$TVplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'TV').data
$Musicplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Music').data
$i = 0
$objResult = @()

# Fill the temp object with current section data
foreach($month in $months) {
   $objTemp = [PSCustomObject]@{
      Month = $month
      MoviePlays = $Movieplays[$i]
      TVPlays = $TVplays[$i]
      MusicPlays = $Musicplays[$i]
      TotalPlays = $Movieplays[$i] + $TVplays[$i] + $Musicplays[$i]
   }
   
   # Add section data results to final object
   $objResult += $objTemp
   $i++
}

# Remove any lines with all 0s
$objResult = $objResult | Where-Object -Property TotalPlays -gt 0

# Create Chart (Call function)
CreateChart

# Convert results to string and send to Discord
$body = $objResult | FT -AutoSize | Out-String
SendStringToDiscord -title "**Monthly Plays:**" -body $body

# Call $SendScriptPath to send the newly created image to Discord via PS v7
& $PSCore -NoLogo -NonInteractive -ExecutionPolicy Bypass -File $SendScriptPath -FilePath $ImagePath -WebhookUrl $script:DiscordURL | Out-Null