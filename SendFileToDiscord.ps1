[cmdletbinding()]
param(
   [Parameter(Mandatory)]
   [string]
   $WebhookUrl,
   
   [Parameter(Mandatory, ParameterSetName = 'file')]
   [string]$FilePath
)

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

# Call the function that will send the embed array to the webhook URL via the default configuration file
Invoke-PSDsHook -FilePath $FilePath -WebhookUrl $WebhookUrl