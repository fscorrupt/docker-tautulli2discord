Clear-Host

<############################################################
    Note - For this script to include library sizes, you need to
    go into Tautulli > Settings > General > and enable
    "Calculate Total File Sizes". It may take a while for
    Tautulli to update the stats, depending on your
    library sizes.
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'PlexLibraryStats'

# Path to where the stat image should be saved and sent from
[string]$strImagePath = "$PSScriptRoot/config/stats.png"

<############################################################
    Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
class DiscordFile {
   [string]$FilePath = [string]::Empty
   [string]$FileName = [string]::Empty
   [string]$FileTitle = [string]::Empty
   [System.Net.Http.MultipartFormDataContent]$Content = [System.Net.Http.MultipartFormDataContent]::new()
   [System.IO.FileStream]$Stream = $null
   
   DiscordFile([string]$FilePath) {
      $this.FilePath = $FilePath
      $this.FileName = Split-Path $filePath -Leaf
      $this.fileTitle = $this.FileName.Substring(0,$this.FileName.LastIndexOf('.'))
      $fileContent = $this.GetFileContent($FilePath)
      $this.Content.Add($fileContent)
   }
   
   [System.Net.Http.StreamContent]GetFileContent($filePath) {
      $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open)
      $fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
      $fileHeader.Name = $this.fileTitle
      $fileHeader.FileName = $this.FileName
      $fileContent = [System.Net.Http.StreamContent]::new($fileStream)
      $fileContent.Headers.ContentDisposition = $fileHeader
      $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/plain")
      
      $this.stream = $fileStream
      return $fileContent
   }
}
function ConvertToImage {
	<#
	A URL to the license for this module.
    LicenseUri = 'https://raw.githubusercontent.com/deathcrafter/Text-To-Image-Mod/master/LICENSE'
    
    A URL to the main website for this project.
    ProjectUri = 'https://github.com/deathcrafter/Text-To-Image-Mod'
	#>
    [CmdletBinding(SupportsShouldProcess=$true,
                  PositionalBinding=$false,
                  ConfirmImpact='Medium')]
    [Alias('txt2img')]
    Param
    (
        # Text which should be converted to Image
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("Text")] 
        [string]
        $ImageText,

        # Generated Image Style
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [ValidateNotNull()]
        [ValidateSet("Transparent","SolidColor")]
        [Alias("BackgroundMode")]
        $ImageStyle="Transparent",

        #Background color in solid mode
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("SolidColor")]
        $SColor='255,30,30,30',

        #FontFace
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("FontFace","font")]
        $Face="Segoe UI",

        #FontSize
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("FontSize","size")]
        $FSize="11",

        #FontColor
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("FontColor")]
        $FColor="White",

                
        # New Image Format
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [ValidateSet("Png", "Bmp", "Gif", "Jpeg", "Tiff")]
        [Alias("ImageType","type")]
        $ImageFormat="Png",

        # New Image Output Path. Default to Current Lcoation
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("ImagePath","path")]
        $OutputPath,

        # New Image Name
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("name","ImageName")]
        $NewImageName="NewImage"

    )

    Begin
    {
    }
    Process
    {
        if ($pscmdlet.ShouldProcess("'$($ImageText)'. Using $ImageStyle style"))
        {
            try
              {
                  
                  switch ($ImageStyle)
                  {
                      'Transparent' {
                        $ImageStyleObjProps=@{
                            FontName=$Face
                            FontSize=$FSize
                            TextColor=[System.Drawing.Brushes]::$FColor
                            BackgroundColor=[System.Drawing.Color]::FromArgb(0,0,0,0)
                        }
                        break
                      }
                      'SolidColor' {
                        $aCache = [regex]::Match($SColor, "^(\d{0,3}?)\,?\s*?(\d{0,3})\,\s*?(\d{0,3})\,\s*?(\d{0,3})$").captures.groups[1].value
                        $aCol = $(if($aCache){$aCache}else{255})
                        $rCol = [regex]::Match($SColor, "^(\d{0,3}?)\,?\s*?(\d{0,3})\,\s*?(\d{0,3})\,\s*?(\d{0,3})$").captures.groups[2].value
                        $gCol = [regex]::Match($SColor, "^(\d{0,3}?)\,?\s*?(\d{0,3})\,\s*?(\d{0,3})\,\s*?(\d{0,3})$").captures.groups[3].value
                        $bCol = [regex]::Match($SColor, "^(\d{0,3}?)\,?\s*?(\d{0,3})\,\s*?(\d{0,3})\,\s*?(\d{0,3})$").captures.groups[4].value
                        $ImageStyleObjProps=@{
                            FontName=$Face
                            FontSize=$FSize
                            TextColor=[System.Drawing.Brushes]::$FColor
                            BackgroundColor=[System.Drawing.Color]::FromArgb($aCol,$rCol,$gCol,$bCol)
                        }
                        break
                      }
                      Default {}
                  }
                  $ImageStyleObj=New-Object -TypeName psobject -Property $ImageStyleObjProps
                  $Format=[System.Drawing.Imaging.ImageFormat]::$ImageFormat
                  $FontObj=New-Object System.Drawing.Font $ImageStyleObj.FontName,$ImageStyleObj.FontSize
                  $BitmapObj=New-Object System.Drawing.Bitmap 1,1
                  $GraphicsObj=[System.Drawing.Graphics]::FromImage($BitmapObj)
                  $StringSize=$GraphicsObj.MeasureString($ImageText, $FontObj)
                  $BitmapObj=New-Object System.Drawing.Bitmap $([int]$StringSize.Width),$([int]$StringSize.Height)
                  $GraphicsObj=[System.Drawing.Graphics]::FromImage($BitmapObj)

                  $GraphicsObj.CompositingQuality=[System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                  $GraphicsObj.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
                  $GraphicsObj.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                  $GraphicsObj.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

                  $GraphicsObj.Clear($ImageStyleObj.BackgroundColor)
                  $GraphicsObj.DrawString($ImageText, $FontObj, $ImageStyleObj.TextColor, 0, 0)

                  $FontObj.Dispose()
                  $GraphicsObj.Flush()
                  $GraphicsObj.Dispose()
                  
                  if($null -eq $OutputPath){
                    $OutputPath=Get-Location
                    $OutputPath=$OutputPath.Path.Replace("\","/")
                  }else{
                    $OutputPath=$OutputPath.Replace("\","/")
                  }
                  
                  $ImageFileName="$OutputPath"+"$NewImageName.$($ImageFormat.ToLower())"
                  
                  $BitmapObj.Save("$ImageFileName", $Format);


              }
              catch 
              {
                Write-Verbose "Failed -  please review exception message for more details"
                Write-Output ("Catched Exception: - $($_.exception.message)")
              }
              
              
        }
    }
    End
    {
    }
}
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
function Invoke-PayloadBuilder {
   [cmdletbinding()]
   param(
      [Parameter(Mandatory)]
      $PayloadObject
   )
   
   process {
      $type = $PayloadObject | Get-Member | Select-Object -ExpandProperty TypeName -Unique
      switch ($type) {
         'DiscordEmbed' {
            [boolean]$createArray = $true
            
            #check if array
            $PayloadObject.PSObject.TypeNames | ForEach-Object {
               switch -Regex ($_) {
                  '^System\.Collections\.Generic\.List.+' {
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
            
            if (-not ($createArray)) {
               $payload = [PSCustomObject]@{
                  embeds = $PayloadObject
               }
            }
            else {
               $embedArray = New-Object 'System.Collections.Generic.List[DiscordEmbed]'
               $null = $embedArray.Add($PayloadObject)
               
               $payload = [PSCustomObject]@{
                  embeds = $embedArray
               }
            }
         }
         'System.String' {
            if (Test-Path $PayloadObject -ErrorAction SilentlyContinue) {
               $payload = [DiscordFile]::New($payloadObject)
            }
            else {
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
   [cmdletbinding()]
   param(
      [Parameter(ParameterSetName = 'createDsConfig')]
      [string]$CreateConfig,
      
      [Parameter()]
      [string]$WebhookUrl,
      
      [Parameter(Mandatory,ParameterSetName = 'file')]
      [string]$FilePath,
      
      [Parameter()]
      [string]$ConfigName = 'config',
      
      [Parameter(ParameterSetName = 'configList')]
      [switch]$ListConfigs,
      
      [Parameter(ParameterSetName = 'embed', Position = 0)]
      $EmbedObject,
      
      [Parameter(ParameterSetName = 'simple')]
      [string]$HookText
   )
   
   begin {
      #Create full path to the configuration file
      $configPath = "$($configDir)$($separator)$($ConfigName).json"
      
      #Ensure we can access the path, and error out if we cannot
      if (!(Test-Path -Path $configPath -ErrorAction SilentlyContinue) -and !$CreateConfig -and !$WebhookUrl) {
         throw "Unable to access [$configPath]. Please provide a valid configuration name. Use -ListConfigs to list configurations, or -CreateConfig to create one."
      }
      elseif (!$CreateConfig -and $WebhookUrl) {
         $hookUrl = $WebhookUrl
         Write-Verbose "Manual mode enabled..."
      }
      elseif ((!$CreateConfig -and !$WebhookUrl) -and $configPath) {
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
            }
            else {
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
            }
            else {
               Write-Host "No configuration files found in [$configDir]"
            }
         }
      }
   }
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[array]$arrExcludedLibraries = $objConfig.ScriptSettings.$strScriptName.ExcludedLibraries
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[object]$objLibrariesTable = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_libraries_table"
[object]$objLibraries = $objLibrariesTable.response.data.data | Select-Object section_id, section_name, section_type, count, parent_count, child_count | Where-Object -Property section_name -notin ($arrExcludedLibraries)

# Loop through each library
[System.Collections.ArrayList]$arrLibraryStats = @()
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

# Sort the results
$arrLibraryStats = $arrLibraryStats | Sort-Object -Property Library, Type
[string]$strBody = $null

if ($arrLibraryStats.count -gt '15'){
  foreach($Library in $arrLibraryStats){
    if ($Library.Library -eq 'Audiobooks') {
      $strBody += "`n$($Library.Library)`n$($Library.count) authors | $($Library.SeasonAlbumCount) books | $($Library.EpisodeTrackCount) chapters | ($($Library.Size)$($Library.Format))`n________________________________________________________`n"
    }
    elseif ($Library.Type -eq 'movie') {
      $strBody += "`n$($Library.Library)`n$($Library.count) movies | ($($Library.Size)$($Library.Format))`n________________________________________________________`n"
    }
    elseif ($Library.Type -eq 'show') {
      $strBody += "`n$($Library.Library)`n$($Library.count) shows | $($Library.SeasonAlbumCount) seasons | $($Library.EpisodeTrackCount) episodes | ($($Library.Size)$($Library.Format))`n________________________________________________________`n"
    }
    elseif ($Library.Type -eq 'artist') {
      $strBody += "`n$($Library.Library)`n$($Library.count) artists | $($Library.SeasonAlbumCount) albums | $($Library.EpisodeTrackCount) tracks | ($($Library.Size)$($Library.Format))`n________________________________________________________`n"
    }
  }

  # Call the function that will send the embed array to the webhook URL via the default configuration file
  ConvertToImage -Text $strBody -path "$PSScriptRoot/config/" -ImageType "png" -ImageName "stats" -BackGroundMode "SolidColor" -FontSize 25 -font "Comfortaa Regular"
  Invoke-PSDsHook -FilePath $strImagePath -WebhookUrl $strDiscordWebhook
}
Else{
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
  }
