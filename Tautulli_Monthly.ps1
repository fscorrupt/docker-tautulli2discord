Clear-Host
function CreateChart {
# Chart creator

[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

# chart object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 1200
   $chart1.Height = 600
   $chart1.BackColor = [System.Drawing.Color]::White

# title 
   [void]$chart1.Titles.Add("Monthly Plays!")
   $chart1.Titles[0].Font = "Calibri,13pt"
   $chart1.Titles[0].Alignment = "topLeft"

# chart area 
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Total Plays"
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
   $objResult.Month | ForEach-Object {$chart1.Series["Month"].Points.addxy($_, $_) }
# data series
   [void]$chart1.Series.Add("MoviePlays")
   $chart1.Series["MoviePlays"].ChartType = "Column"
   $chart1.Series["MoviePlays"].BorderWidth  = 3
   $chart1.Series["MoviePlays"].IsVisibleInLegend = $true
   $chart1.Series["MoviePlays"].chartarea = "ChartArea1"
   $chart1.Series["MoviePlays"].Legend = "Legend1"
   $chart1.Series["MoviePlays"].color = "#5B9BD5"
   $objResult.MoviePlays | ForEach-Object {$chart1.Series["MoviePlays"].Points.addxy("MoviePlays", $_) }
# data series
   [void]$chart1.Series.Add("TVPlays")
   $chart1.Series["TVPlays"].ChartType = "Column"
   $chart1.Series["TVPlays"].BorderWidth  = 3
   $chart1.Series["TVPlays"].IsVisibleInLegend = $true
   $chart1.Series["TVPlays"].chartarea = "ChartArea1"
   $chart1.Series["TVPlays"].Legend = "Legend1"
   $chart1.Series["TVPlays"].color = "#ED7D31"
   $objResult.TVPlays | ForEach-Object {$chart1.Series["TVPlays"].Points.addxy("TVPlays", $_) }
<# data series
   [void]$chart1.Series.Add("MusicPlays")
   $chart1.Series["MusicPlays"].ChartType = "Column"
   $chart1.Series["MusicPlays"].BorderWidth  = 3
   $chart1.Series["MusicPlays"].IsVisibleInLegend = $true
   $chart1.Series["MusicPlays"].chartarea = "ChartArea1"
   $chart1.Series["MusicPlays"].Legend = "Legend1"
   $chart1.Series["MusicPlays"].color = "#A5A5A5"
   $objResult.MusicPlays | ForEach-Object {$chart1.Series["MusicPlays"].Points.addxy("MusicPlays", $_) }#>
# data series
   [void]$chart1.Series.Add("TotalPlays")
   $chart1.Series["TotalPlays"].ChartType = "Column"
   $chart1.Series["TotalPlays"].BorderWidth  = 3
   $chart1.Series["TotalPlays"].IsVisibleInLegend = $true
   $chart1.Series["TotalPlays"].chartarea = "ChartArea1"
   $chart1.Series["TotalPlays"].Legend = "Legend1"
   $chart1.Series["TotalPlays"].color = "#FFC000"
   $objResult.TotalPlays | ForEach-Object {$chart1.Series["TotalPlays"].Points.addxy("TotalPlays", $_) }
# save chart
   $chart1.SaveImage($PicturePath,"png")
   Clear-Host
}

# Discord Webhook Prod Uri
$Uri = 'https://discordapp.com/api/webhooks/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

# Tautulli Api Key
$apiKey='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
# Tautulli Url with port
$URL = "http://xxx.xxx.x.x:8181"
# Webhook 
$PicturePath = "C:\temp\Monthly_Plays.png"
$PSCore = "C:\Program Files\PowerShell\7\pwsh.exe" # Sending Files to Discord currently only works with powershell 6+
$SendScriptPath = "D:\Tools\Send-FileToDiscord.ps1" # Second Script Required, also on My Repo.
$Arguments = "-NoLogo -noninteractive -ExecutionPolicy Bypass -file $SendScriptPath -FilePath $PicturePath -WebhookUrl $Uri"


<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

#Clear previously used variables
$StreamList = $null

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_per_month"

$objTemplate = '' | Select-Object -Property Month, MoviePlays, TVPlays, TotalPlays #, MusicPlays
#$objTemplate | Add-Member -MemberType NoteProperty -Name Month -Value $null
#$objTemplate | Add-Member -MemberType NoteProperty -Name MoviePlays -Value $null
#$objTemplate | Add-Member -MemberType NoteProperty -Name TVPlays -Value $null
#$objTemplate | Add-Member -MemberType NoteProperty -Name MusicPlays -Value $null
#$objTemplate | Add-Member -MemberType NoteProperty -Name TotalPlays -Value $null
$objResult = @()

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$months = $dataResult.response.data.categories
$Movieplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Movies').data
$TVplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'TV').data
#$Musicplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Music').data
$i = 0

foreach($month in $months) {
    #Fill Temp object with current section data
    $objTemp = $objTemplate | Select-Object *
    $objTemp.Month = $month -replace 'ä', 'a'
    $objTemp.MoviePlays = $Movieplays[$i]
    $objTemp.TVPlays = $TVplays[$i]
    #$objTemp.MusicPlays= $Musicplays[$i]
    $objTemp.TotalPlays= $Movieplays[$i] + $TVplays[$i]# + $Musicplays[$i]

    #Add section data results to final object
    $objResult += $objTemp

    $i++
}



# Convert the object to a string
$stringResult = $objResult | FT -AutoSize | Out-String

<# Preview the data
$stringResult
#>

$Content = @"
**Monthly Plays:**
```
$stringResult```
"@

#Create Paylaod
$Payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

# Create Chart (Call function)
CreateChart

#Call PS7 to Send file into Discord
$CallPSCore = Start-Process -WindowStyle hidden $PSCore -ArgumentList $Arguments