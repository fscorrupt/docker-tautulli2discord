Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
$WebhookName = "SABnzbd"

# Log file path
$SABLog = "$PSScriptRoot\SABLog.txt"

<############################################################

 Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function SendStringToDiscord($url, $payload) {
    try {
       Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
       Start-Sleep -Seconds 1
    }
    catch {
       Write-Host "Unable to send to Discord." -ForegroundColor Red
       Write-Host $payload
    }
 }

# Parse the config file and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json

[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.SABnzbd.URL
[string]$apiKey = $config.SABnzbd.APIKey
$apiURL = "$URL/api?apikey=$apiKey&output=json&mode=queue"
$SABnzbdInfo = (Invoke-RestMethod -Method Get -Uri $apiURL).queue
$embedSlots = @()

if($SABnzbdInfo.paused -and $SABnzbdInfo.pause_int -ne 0) {
   $embedObject = [PSCustomObject]@{
         color = '15197440'
         title = "Everything has been temporarily paused."
         description = "Downloads may have been paused manually or automatically until there is enough free space left to proceed."
         fields = [PSCustomObject]@{
            name = 'Time Left'
            value = "$($SABnzbdInfo.pause_int) minutes."
            inline = $false
         }, [PSCustomObject]@{
            name = 'Free Space'
            value = "$($SABnzbdInfo.diskspace1)GB"
            inline = $true
         }, [PSCustomObject]@{
            name = 'Total Space'
            value = "$($SABnzbdInfo.diskspacetotal1)GB"
            inline = $true
         }
         footer = [PSCustomObject]@{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
      # Add section data results to final object
      #$embedSlots.Add($embedObject) | Out-Null
      $embedSlots += $embedObject

   # Send to Discord
   $payload = [PSCustomObject]@{
      username = "Downloads Paused"
      #content = "Everything is paused for the next $($SABnzbdInfo.pause_int) minutes."
      embeds = $embedSlots
   }
   SendStringToDiscord -url $DiscordURL -payload $payload
}
elseif($SABnzbdInfo.paused) {
   # Send to Discord
   $payload = [PSCustomObject]@{
      username = "Downloads Paused"
      content = "Everything has been temporarily paused."
      #embeds = $embedSlots
   }
   SendStringToDiscord -url $DiscordURL -payload $payload
}
elseif (($SABnzbdInfo.slots).Count -gt 0) {
   #$timeLeftFormatted = ($SABnzbdInfo.timeleft).Split(':')
   #$hours = $timeLeftFormatted[0]
   #$minutes = $timeLeftFormatted[1]
   #$seconds = $timeLeftFormatted[2]
   #$summary = "Downloading **" + ($SABnzbdInfo.slots).Count + "** item(s) at **" + $SABnzbdInfo.speed + "B**s/second. Time remaining: **$hours hours, $minutes minutes, and $seconds seconds**"
   $summary = "Downloading **" + ($SABnzbdInfo.slots).Count + "** item(s) at **" + $SABnzbdInfo.speed + "B**s/second. Time remaining: **$($SABnzbdInfo.timeleft)**"
   
   # Update the log file with current number of downloads
   ($SABnzbdInfo.slots).Count | Out-File -FilePath $SABLog -Force
   
   foreach ($slot in ($SABnzbdInfo.slots | Select-Object -First 10)) {
      $embedObject = [PSCustomObject]@{
         color = '15197440'
         #title = ($slot.filename).Substring(0, 40) + "..." # This is used to reduce the length, as filenames can be 50+ characters long
         title = "Filename"
         description = $slot.filename
         fields = [PSCustomObject]@{
            name = 'Completed'
            value = "$($slot.percentage)%"
            inline = $false
         }, [PSCustomObject]@{
            name = 'Time Left'
            value = $slot.timeleft
            inline = $true
         }, [PSCustomObject]@{
            name = 'Category'
            value = $slot.cat
            inline = $true
         }, [PSCustomObject]@{
            name = 'File Size'
            value = $slot.size
            inline = $true
         }
         footer = [PSCustomObject]@{
            text = 'Updated'
         }
         timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
      }
      # Add section data results to final object
      #$embedSlots.Add($embedObject) | Out-Null
      $embedSlots += $embedObject
   }
   
   $payload = [PSCustomObject]@{
      username = "First 10 Downloads"
      content  = $summary
      embeds   = $embedSlots
   }
   SendStringToDiscord -url $DiscordURL -payload $payload
}
else { # Nothing is being downloaded and SAB is not paused
   $summary = "Downloading **0** items at 0 MB/second. Time remaining: NA"
   $body = "Nothing currently being downloaded."
   
   if(!(Test-Path $SABLog)) { # Log file doesn't exist yet. Create it and send message to Discord
      "0" | Out-File -FilePath $SABLog -Force
      
      # Send to Discord
      $payload = [PSCustomObject]@{
         username = "No Downloads"
         content = "Nothing currently in the download queue."
         #embeds = $embedSlots
      }
      SendStringToDiscord -url $DiscordURL -payload $payload
   }
   else { # Log file exists. Run a compare to see if Discord needs to be updated
      [int]$lastSABLog = Get-Content $SABLog
      
      if ($lastSABLog -eq 0) { # The last message sent to Discord matches the latest message
         Write-Host "Nothing to update."
      }
      else { # The last message sent to Discord does NOT match the latest message. Update the log file and send to Discord
         "0" | Out-File -FilePath $SABLog -Force
         
         # Send to Discord
         $payload = [PSCustomObject]@{
            username = "No Downloads"
            content = "Nothing currently in the download queue."
            #embeds = $embedSlots
         }
         SendStringToDiscord -url $DiscordURL -payload $payload
      }
   }
}
