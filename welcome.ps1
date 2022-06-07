function recurse {
  sleep 180
  $elapsedTime = $(get-date) - $StartTime
  $totalTime = $elapsedTime.Days.ToString() +' Days '+ $elapsedTime.Hours.ToString() +' Hours '+ $elapsedTime.Minutes.ToString() +' Min ' + $elapsedTime.Seconds.ToString() +' Sec'
  write-host ""
  write-host "Container is running since: " -NoNewline
  write-host "$totalTime" -ForegroundColor Cyan
  recurse
}

$json = @"
{
   "Plex" : {
      "Url" : "https://plex.domain.com",
      "token" : "<redacted>"
   },
   "Tautulli" : {
      "Url" : "https://tautulli.domain.com",
      "APIKey" : "<redacted>"
   },
   "SABnzbd" : {
      "Url" : "https://sabnzbd.domain.com",
      "APIKey" : "<redacted>"
   },
   "TMDB" : {
      "APIKey" : "<redacted>"
   },
   "ScriptSettings" : {
      "CurrentStreams" : {
         "Webhook" : "https://discord.com/api/webhooks/<redacted>/<redacted>"
      },
      "PlexLibraryStats" : {
         "Webhook" : "https://discord.com/api/webhooks/<redacted>/<redacted>",
         "ExcludedLibraries" : ["Photos", "Live TV", "Fitness", "YouTube"]
      },
      "PlexPlayStats" : {
         "Webhook" : "https://discord.com/api/webhooks/<redacted>/<redacted>",
         "RemoveMonthsWithZeroPlays" : true
      },
      "PopularOnPlex" : {
         "Webhook" : "https://discord.com/api/webhooks/<redacted>/<redacted>",
         "Count" : 5,
         "Days" : 30
      },
      "SABnzbdStatus" : {
         "Webhook" : "https://discord.com/api/webhooks/<redacted>/<redacted>"
      },
      "TopPlexStats" : {
         "Webhook" : "https://discord.com/api/webhooks/<redacted>/<redacted>",
         "Count" : 5,
         "Days" : 30
      }
   }
}
"@

$json | Out-File "$PSScriptRoot\config\config.json.template"

# Show integraded Scripts
$starttime = Get-Date
$scripts =  (get-childitem -Filter *.ps1 | where name -ne 'welcome.ps1').Name.replace('.ps1','')

cls
Write-Host "Currently there are '$($scripts.count)' Scripts integrated" -ForegroundColor Yellow
Write-Host  ''
Write-Host "First fill out config here: " -ForegroundColor Yellow -NoNewline
Write-Host "/opt/appdata/tautulli2discord/config/config.json" -ForegroundColor Cyan 
Write-Host "Example on how to run the Script: " -ForegroundColor Yellow -NoNewline
Write-Host "docker exec -it tautulli2discord pwsh PlexLibraryStats.ps1" -ForegroundColor Cyan
Write-Host "####################################################" -ForegroundColor Green

foreach ($script in $scripts){
  write-host $script -ForegroundColor Cyan
}

# Call Recursive Function.
recurse
