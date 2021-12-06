Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the config file under "[Webhooks]".
$WebhookName = "StorageInfo"

# Comma separated list of excluded Usernames for this report
$ExcludeUsers = ('Local', 'jyanik', 'Ladrek1989', 'FS.Corrupt', 'am15h', 'DAN-FLIX')

# Path to the exported database from Invitarr
$InvitarrDatabase = "$PSScriptRoot\db.txt"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function ParseInvitarrDatabase ($DatabaseLocation) {
   if (Test-Path $DatabaseLocation) {
      $objResult = @()
      $array = Get-Content $DatabaseLocation
      $array = ($array `
         -replace " ", "" `
         -replace "\+", '' `
         -replace "#", 'Number' `
         -replace "\|", ',' `
         -replace "\-", ''`
         -replace ","," ").split(" ")
      $x = 1
      
      for($i=0; $i -lt $array.Count; $i+=3) {
         if ($array[$i] -notin ('', 'Number', 'Name', 'Email')) {
            $objTemp = [PSCustomObject]@{
               Number = $x
               DiscordName = $array[$i]
               PlexName = $array[$i+1]
            }
            
            #Add line results to final object
            $objResult += $objTemp
            $x++
         }
      }
      return $objResult
   }
   else {
      Write-Host "Invalid path to Invitarr database. Exiting" -ForegroundColor Red
      exit
   }
}

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

# Parse the config and Invitarr Database files and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
$objUsernameMap = ParseInvitarrDatabase($InvitarrDatabase)
[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey
[datetime]$origin = '1970-01-01 00:00:00' #Used to calculate the LastSeen value
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_users"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$users = $DataResult.response.data | Where-Object -Property username -notin $ExcludeUsers  | Sort-Object -Property username

# Loop through each user and collect relevant data
$objResult = @()
foreach ($user in $users) {
   $apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_history&user_id=$($user.user_id)&length=1"
   $DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
   $LastSeenDate = $origin.AddSeconds(($DataResult.response.data.data).date)
   
   $objTemp = [PSCustomObject]@{
      Username = $user.username
      FriendlyName = ($user.friendly_name).Split("@")[0]
      LastSeen = (New-TimeSpan -Start $LastSeenDate -End (Get-Date)).Days
      Time = "Days Ago"
   }
   
   # Add line results to final object
   $objResult += $objTemp
}

# Filter the resulting object into usable objects
$SafeUsers = $objResult | Sort-Object -Property LastSeen -Descending | Where-Object -Property LastSeen -le 1
$InDangerUsers = $objResult | Sort-Object -Property LastSeen -Descending | Where-Object {($_.LastSeen -gt 1) -and ($_.LastSeen -lt 7)}
$GettingKicked = $objResult | Sort-Object -Property LastSeen -Descending | Where-Object {($_.LastSeen -ge 7) -and ($_.LastSeen -lt 999)}
$NeverSeen = $objResult | Sort-Object -Property LastSeen -Descending | Where-Object -Property LastSeen -ge 999

# Convert results to string and send to Discord
if ($SafeUsers.Count -gt 0) {
   $stringSafeUsers = $SafeUsers | Select-Object -Property FriendlyName, LastSeen, Time | FT -AutoSize | Out-String
   SendStringToDiscord -title "**Safe Users:**" -body $stringSafeUsers
}

if ($InDangerUsers.Count -gt 0) {
   $stringDangerUsers = $InDangerUsers | Select-Object -Property FriendlyName, LastSeen, Time | FT -AutoSize | Out-String
   SendStringToDiscord -title "**In Danger Users:**" -body $stringDangerUsers
}

if ($GettingKicked.Count -gt 0) {
   $stringGettingKicked = $GettingKicked | Select-Object -Property FriendlyName, LastSeen, Time | FT -AutoSize | Out-String
   SendStringToDiscord -title "**Users Getting Kicked:**" -body $stringGettingKicked
}

if ($NeverSeen.Count -gt 0) {
   $stringNeverSeen = $NeverSeen | Select-Object -Property FriendlyName | FT -AutoSize | Out-String
   SendStringToDiscord -title "**Never Seen Users:**" -body $stringNeverSeen
}

# Create bot commands to drop dead users and send to Discord
$DeadUsers = $GettingKicked + $NeverSeen
$stringCommand = $null
if ($DeadUsers.Count -gt 0) {
   foreach ($DeadUser in $DeadUsers) {
      $DiscordName = ($objUsernameMap | Where-Object -Property PlexName -match $DeadUser.Username).DiscordName
      
      if ($DiscordName -ne "" -and $DiscordName -ne $null) {
         $command = "m:role @" + $DiscordName + " @1Month"
         $stringCommand += ($command | Out-String)
      }
   }
   
   if ($stringCommand -ne "" -and $stringCommand -ne $null) {
      SendStringToDiscord -title "**Bot Commands:**" -body $stringCommand
   }
}