Clear-Host

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'SABnzbdStatus'

# Log file path
[string]$strLogFilePath = "$PSScriptRoot\config\log\SABLog.txt"

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

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strSABnzbdURL = $objConfig.SABnzbd.URL
[string]$strSABnzbdAPIKey = $objConfig.SABnzbd.APIKey
[object]$objSABnzbdQueue = (Invoke-RestMethod -Method Get -Uri "$strSABnzbdURL/api?apikey=$strSABnzbdAPIKey&output=json&mode=queue").queue
[string]$strSummary = "Downloading **$(($objSABnzbdQueue.slots).Count)** item(s) at **$($objSABnzbdQueue.speed)**Bs/second. Time remaining: **$($objSABnzbdQueue.timeleft)**"

# Ensure the log file exists. If not, create it.
if (-not(Test-Path $strLogFilePath)) {
   '' | Out-File -FilePath $strLogFilePath -Force
}

[System.Collections.ArrayList]$arrSlotEmbed = @()
if($objSABnzbdQueue.paused) {
   '-1' | Out-File -FilePath $strLogFilePath -Force
   if ($objSABnzbdQueue.pause_int -gt 0) {
      [string]$strTimeRemaining = $($objSABnzbdQueue.pause_int)
   }
   else {
      [string]$strTimeRemaining = 'Unknown'
   }
   
   [hashtable]$htbEmbedProperties = @{
      color = '15197440'
      title = 'Downloads Paused'
      description = 'Downloads are currently paused. Either this was manually done by the server admin, or automatically if there is no free space remaining.'
      fields = @{
         name = 'Time Left'
         value = $strTimeRemaining
         inline = $false
      }, @{
         name = 'Free Space'
         value = "$($objSABnzbdQueue.diskspace1)GB"
         inline = $true
      }, @{
         name = 'Total Space'
         value = "$($objSABnzbdQueue.diskspacetotal1)GB"
         inline = $true
      }
      footer = @{
         text = 'Updated'
      }
      timestamp = ((Get-Date).AddHours(5)).ToString('yyyy-MM-ddTHH:mm:ss.Mss')
   }
   # Add the hashtable to the Embed Array
   $null = $arrSlotEmbed.Add($htbEmbedProperties)
   
   # Send to Discord
   [object]$objPayload = @{
      username = 'Downloads Paused'
      content = $strSummary
      embeds = $arrSlotEmbed
   } | ConvertTo-Json -Depth 4
   
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}
elseif (($objSABnzbdQueue.slots).Count -gt 0) {
   # Update the log file with current number of downloads
   ($objSABnzbdQueue.slots).Count | Out-File -FilePath $strLogFilePath -Force
   
   foreach ($slot in ($objSABnzbdQueue.slots | Select-Object -First 10)) {
      $htbEmbedProperties = @{
         color = '15197440'
         title = 'Filename'
         description = $slot.filename
         fields = @{
            name = 'Completed'
            value = "$($slot.percentage)%"
            inline = $false
         }, @{
            name = 'Time Left'
            value = $slot.timeleft
            inline = $true
         }, @{
            name = 'Category'
            value = $slot.cat
            inline = $true
         }, @{
            name = 'File Size'
            value = $slot.size
            inline = $true
         }
         footer = @{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString('yyyy-MM-ddTHH:mm:ss.Mss')
      }
      # Add the current hashtable to the Embed Array
      $null = $arrSlotEmbed.Add($htbEmbedProperties) | Out-Null
   }
   
   # Send to Discord
   [object]$objPayload = @{
      username = 'First 10 Downloads'
      content = $strSummary
      embeds = $arrSlotEmbed
   } | ConvertTo-Json -Depth 4
   
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}
# Nothing is being downloaded and SAB is not paused
else {
   [hashtable]$htbEmbedProperties = @{
      color = '15197440'
      title = 'No downloads'
      description = 'There is nothing currently in the download queue.'
      fields = @{
         name = 'Time Left'
         value = 'NA'
         inline = $false
      }, @{
         name = 'Free Space'
         value = "$($objSABnzbdQueue.diskspace1)GB"
         inline = $true
      }, @{
         name = 'Total Space'
         value = "$($objSABnzbdQueue.diskspacetotal1)GB"
         inline = $true
      }
      footer = @{
         text = 'Updated'
      }
      timestamp = ((Get-Date).AddHours(5)).ToString('yyyy-MM-ddTHH:mm:ss.Mss')
   }
   # Add the hashtable to the Embed Array
   $null = $arrSlotEmbed.Add($htbEmbedProperties)
   
   # Get the last logged value
   [int]$intLastLogValue = Get-Content $strLogFilePath
   
   # The last logged value is the same as ($objSABnzbdQueue.slots).Count
   if ($intLastLogValue -eq 0) {
      Write-Host 'Nothing to update.'
   }
   # The last logged value is NOT the same as ($objSABnzbdQueue.slots).Count. Update the log file and send to Discord
   else {
      '0' | Out-File -FilePath $strLogFilePath -Force
      
      # Send to Discord
      [object]$objPayload = @{
         username = 'No Downloads'
         content = 'Nothing currently in the download queue.'
         embeds = $arrSlotEmbed
      } | ConvertTo-Json -Depth 4
      
      Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
   }
}