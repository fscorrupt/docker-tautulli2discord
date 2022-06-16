using namespace System.Drawing
using namespace System.Windows.Forms

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

function Export-Png
{
<#
	Thanks: https://www.reddit.com/user/ka-splam/
.Synopsis
    Convert text to image
.DESCRIPTION
    Takes text input from the pipeline or as a parameter, and makes an image of it.

.EXAMPLE
    "sample text" | export-png -Path output.png

.EXAMPLE
    get-childitem c:\ | export-png -path output.png

.EXAMPLE
    get-process | format-table -AutoSize | Out-String | Export-Png -path output.png

#>
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0)]
        [string[]]$InputObject,

        # Path where output image should be saved
        [string]$Path,

        # Clipboard support,
        [switch]$ToClipboard
    )

    begin
    {
        # can render multiple lines, so $lines exists to gather
        # all input from the pipeline into one collection
        [Collections.Generic.List[String]]$lines = @()
    }
    Process
    {
        # each incoming string from the pipeline, works even
        # if it's a multiline-string. If it's an array of string
        # this implicitly joins them using $OFS
        $null = $lines.Add($InputObject)
    }

    End
    {
        # join the array of lines into a string, so the 
        # drawing routines can render the multiline string directly
        # without us looping over them or calculating line offsets, etc.
        [string]$lines = $lines -join "`n"


        # placeholder 1x1 pixel bitmap, will be used to measure the line
        # size, before re-creating it big enough for all the text
        [Bitmap]$bmpImage = [Bitmap]::new(1, 1)


        # Create the Font, using any available MonoSpace font
        # hardcoded size and style, because it's easy
        [Font]$font = [Font]::new([FontFamily]::GenericMonospace, 12, [FontStyle]::Regular, [GraphicsUnit]::Pixel)


        # Create a graphics object and measure the text's width and height,
        # in the chosen font, with the chosen style.
        [Graphics]$Graphics = [Graphics]::FromImage($BmpImage)
        [int]$width  = $Graphics.MeasureString($lines, $Font).Width
        [int]$height = $Graphics.MeasureString($lines, $Font).Height


        # Recreate the bmpImage big enough for the text.
        # and recreate the Graphics context from the new bitmap
        $BmpImage = [Bitmap]::new($width, $height)
        $Graphics = [Graphics]::FromImage($BmpImage)


        # Set Background color, and font drawing styles
        # hard coded because early version, it's easy
        $Graphics.Clear([Color]::Black)
        $Graphics.SmoothingMode = [Drawing2D.SmoothingMode]::Default
        $Graphics.TextRenderingHint = [Text.TextRenderingHint]::SystemDefault
        $brushColour = [SolidBrush]::new([Color]::FromArgb(200, 200, 200))


        # Render the text onto the image
        $Graphics.DrawString($lines, $Font, $brushColour, 0, 0)

        $Graphics.Flush()


        if ($Path)
        {
            # Export image to file
            [System.IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath))
            $Path = [System.IO.Path]::GetFullPath($Path)
            $bmpImage.Save($Path, [Imaging.ImageFormat]::Png)
        }

        if ($ToClipboard)
        {
            [Windows.Forms.Clipboard]::SetImage($bmpImage)
        }

        if (-not $ToClipboard -and -not $Path)
        {
            Write-Warning -Message "No output chosen. Use parameter -LiteralPath 'out.png' , or -ToClipboard , or both"
        }
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

if ($arrLibraryStats.count -gt '5'){
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
  $strBody | export-png -Path $strImagePath
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
