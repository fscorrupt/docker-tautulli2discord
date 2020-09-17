###############################
#                             #
# Powershell Core is Required #
#                             #
###############################

class DiscordFile {

    [string]$FilePath                                  = [string]::Empty
    [string]$FileName                                  = [string]::Empty
    [string]$FileTitle                                 = [string]::Empty
    [System.Net.Http.MultipartFormDataContent]$Content = [System.Net.Http.MultipartFormDataContent]::new()
    [System.IO.FileStream]$Stream                      = $null

    DiscordFile([string]$FilePath)
    {
        $this.FilePath  = $FilePath
        $this.FileName  = Split-Path $filePath -Leaf
        $this.fileTitle = $this.FileName.Substring(0,$this.FileName.LastIndexOf('.'))
        $fileContent = $this.GetFileContent($FilePath)
        $this.Content.Add($fileContent)                 
    }

    [System.Net.Http.StreamContent]GetFileContent($filePath)
    {        
        $fileStream                             = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open)
        $fileHeader                             = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
        $fileHeader.Name                        = $this.fileTitle
        $fileHeader.FileName                    = $this.FileName
        $fileContent                            = [System.Net.Http.StreamContent]::new($fileStream)        
        $fileContent.Headers.ContentDisposition = $fileHeader
        $fileContent.Headers.ContentType        = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/plain")   
                        
        $this.stream = $fileStream
        return $fileContent        
    }    
}
function Invoke-PayloadBuilder {
    [cmdletbinding()]
    param(
        [Parameter(
            Mandatory
        )]
        $PayloadObject
    )
    
    process {

        $type = $PayloadObject | Get-Member | Select-Object -ExpandProperty TypeName -Unique
    
        switch ($type) {
                        
            'DiscordEmbed' {

                [bool]$createArray = $true

                #check if array
                $PayloadObject.PSObject.TypeNames | ForEach-Object {

                    switch ($_) {

                        {$_ -match '^System\.Collections\.Generic\.List.+'} {
                            
                            $createArray = $false

                        }

                        'System.Array' {

                            $createArray = $false

                        }

                        'System.Collections.ArrayList' {
                            
                            $createArray = $false

                        }
                    }
                }

                if (!$createArray) {

                    $payload = [PSCustomObject]@{

                        embeds = $PayloadObject
    
                    }

                } else {

                    $embedArray = New-Object 'System.Collections.Generic.List[DiscordEmbed]'
                    $embedArray.Add($PayloadObject) | Out-Null

                    $payload = [PSCustomObject]@{

                        embeds = $embedArray

                    }
                }
            }

            'System.String' {

                if (Test-Path $PayloadObject -ErrorAction SilentlyContinue) {

                    $payload = [DiscordFile]::New($payloadObject)

                } else {

                    $payload = [PSCustomObject]@{

                        content = ($PayloadObject | Out-String)

                    }
                }                
            }
        }
    }
    
    end {

        return $payload

    }
}
function Invoke-PSDsHook {
    <#
    .SYNOPSIS
    Invoke-PSDsHook
    Use PowerShell classes to make using Discord Webhooks easy and extensible

    .DESCRIPTION
    This function allows you to use Discord Webhooks with embeds, files, and various configuration settings

    .PARAMETER CreateConfig
    If specified, will create a configuration file containing the webhook URL as the argument.
    You can use the ConfigName parameter to create another configuration separate from the default.

    .PARAMETER WebhookUrl   
    If used with an embed or file, this URL will be used in the webhook call.

    .PARAMETER ConfigName
    Specified a name for the configuration file. 
    Can be used when creating a configuration file, as well as when passing embeds/files.

    .PARAMETER ListConfigs
    Lists configuration files

    .PARAMETER EmbedObject
    Accepts an array of [EmbedObject]'s to pass in the webhook call.

    .EXAMPLE
    (Create a configuration file)
    Configuration files are stored in a sub directory of your user's home directory named .psdshook/configs

    Invoke-PsDsHook -CreateConfig "www.hook.com/hook"
    .EXAMPLE
    (Create a configuration file with a non-standard name)
    Configuration files are stored in a sub directory of your user's home directory named .psdshook/configs

    Invoke-PsDsHook -CreateConfig "www.hook.com/hook2" -ConfigName 'config2'

    .EXAMPLE
    (Send an embed with the default config)

    using module PSDsHook

    If the module is not in one of the folders listed in ($env:PSModulePath -split "$([IO.Path]::PathSeparator)")
    You must specify the full path to the psm1 file in the above using statement
    Example: using module 'C:\users\thegn\repos\PsDsHook\out\PSDsHook\0.0.1\PSDsHook.psm1'

    Create embed builder object via the [DiscordEmbed] class
    $embedBuilder = [DiscordEmbed]::New(
                        'title',
                        'description'
                    )

    Add blue color
    $embedBuilder.WithColor(
        [DiscordColor]::New(
                'blue'
        )
    )
    
    Finally, call the function that will send the embed array to the webhook url via the default configuraiton file
    Invoke-PSDsHook $embedBuilder -Verbose

    .EXAMPLE
    (Send an webhook with just text)

    Invoke-PSDsHook -HookText 'this is the webhook message' -Verbose
    #>    
    [cmdletbinding()]
    param(
        [Parameter(
            ParameterSetName = 'createDsConfig'
        )]
        [string]
        $CreateConfig,

        [Parameter(
        )]
        [string]
        $WebhookUrl,

        [Parameter(
            Mandatory,
            ParameterSetName = 'file'
        )]
        [string]
        $FilePath,

        [Parameter(

        )]
        [string]
        $ConfigName = 'config',

        [Parameter(
            ParameterSetName = 'configList'
        )]
        [switch]
        $ListConfigs,

        [Parameter(
            ParameterSetName = 'embed',
            Position = 0
        )]
        $EmbedObject,

        [Parameter(
            ParameterSetName = 'simple'
        )]
        [string]
        $HookText
    )

    begin {            

        #Create full path to the configuration file
        $configPath = "$($configDir)$($separator)$($ConfigName).json"
                    
        #Ensure we can access the path, and error out if we cannot
        if (!(Test-Path -Path $configPath -ErrorAction SilentlyContinue) -and !$CreateConfig -and !$WebhookUrl) {

            throw "Unable to access [$configPath]. Please provide a valid configuration name. Use -ListConfigs to list configurations, or -CreateConfig to create one."

        } elseif (!$CreateConfig -and $WebhookUrl) {

            $hookUrl = $WebhookUrl

            Write-Verbose "Manual mode enabled..."

        } elseif ((!$CreateConfig -and !$WebhookUrl) -and $configPath) {

            #Get configuration information from the file specified                 
            $config = [DiscordConfig]::New($configPath)                
            $hookUrl = $config.HookUrl             

        }        
    }

    process {
            
        switch ($PSCmdlet.ParameterSetName) {

            'embed' {

                $payload = Invoke-PayloadBuilder -PayloadObject $EmbedObject

                Write-Verbose "Sending:"
                Write-Verbose ""
                Write-Verbose ($payload | ConvertTo-Json -Depth 4)

                try {

                    Invoke-RestMethod -Uri $hookUrl -Body ($payload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json' -Method Post

                }
                catch {

                    $errorMessage = $_.Exception.Message
                    throw "Error executing Discord Webhook -> [$errorMessage]!"

                }
            }

            'file' {

                if ($PSVersionTable.PSVersion.Major -lt 6) {

                    throw "Support for sending files is not yet available in PowerShell 5.x"
                    
                } else {

                    $fileInfo = Invoke-PayloadBuilder -PayloadObject $FilePath
                    $payload  = $fileInfo.Content
    
                    Write-Verbose "Sending:"
                    Write-Verbose ""
                    Write-Verbose ($payload | Out-String)
    
                    #If it is a file, we don't want to include the ContentType parameter as it is included in the body
                    try {
    
                        Invoke-RestMethod -Uri $hookUrl -Body $payload -Method Post
    
                    }
                    catch {
    
                        $errorMessage = $_.Exception.Message
                        throw "Error executing Discord Webhook -> [$errorMessage]!"
    
                    }
                    finally {
    
                        $fileInfo.Stream.Dispose()
                        
                    }
                } 
            }

            'simple' {

                $payload = Invoke-PayloadBuilder -PayloadObject $HookText

                Write-Verbose "Sending:"
                Write-Verbose ""
                Write-Verbose ($payload | ConvertTo-Json -Depth 4)

                try {
                    
                    Invoke-RestMethod -Uri $hookUrl -Body ($payload | ConvertTo-Json -Depth 4) -ContentType 'Application/Json' -Method Post

                }
                catch {

                    $errorMessage = $_.Exception.Message
                    throw "Error executing Discord Webhook -> [$errorMessage]!"

                }
            }

            'createDsConfig' {
                
                [DiscordConfig]::New($CreateConfig, $configPath)

            }

            'configList' {

                $configs = (Get-ChildItem -Path (Split-Path $configPath) | Where-Object {$PSitem.Extension -eq '.json'} | Select-Object -ExpandProperty Name)
                if ($configs) {

                    Write-Host "Configuration files in [$configDir]:"
                    return $configs

                } else {

                    Write-Host "No configuration files found in [$configDir]"

                }
            }
        }        
    }
}
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
# data series
   [void]$chart1.Series.Add("MusicPlays")
   $chart1.Series["MusicPlays"].ChartType = "Column"
   $chart1.Series["MusicPlays"].BorderWidth  = 3
   $chart1.Series["MusicPlays"].IsVisibleInLegend = $true
   $chart1.Series["MusicPlays"].chartarea = "ChartArea1"
   $chart1.Series["MusicPlays"].Legend = "Legend1"
   $chart1.Series["MusicPlays"].color = "#A5A5A5"
   $objResult.MusicPlays | ForEach-Object {$chart1.Series["MusicPlays"].Points.addxy("MusicPlays", $_) }#
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

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

#Clear previously used variables
$StreamList = $null

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_per_month"

$objTemplate = '' | Select-Object -Property Month, MoviePlays, TVPlays, TotalPlays , MusicPlays
$objResult = @()

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$months = $dataResult.response.data.categories
$Movieplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Movies').data
$TVplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'TV').data
$Musicplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Music').data
$i = 0

foreach($month in $months) {
    #Fill Temp object with current section data
    $objTemp = $objTemplate | Select-Object *
    $objTemp.Month = $month -replace 'ä', 'a'
    $objTemp.MoviePlays = $Movieplays[$i]
    $objTemp.TVPlays = $TVplays[$i]
    $objTemp.MusicPlays= $Musicplays[$i]
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

#Finally, call the function that will send the embed array to the webhook url via the default configuration file
Invoke-PSDsHook -FilePath $PicturePath -WebhookUrl $Uri
