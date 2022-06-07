function recurse {
  sleep 180
  $elapsedTime = $(get-date) - $StartTime
  $totalTime = $elapsedTime.Days.ToString() +' Days '+ $elapsedTime.Hours.ToString() +' Hours '+ $elapsedTime.Minutes.ToString() +' Min ' + $elapsedTime.Seconds.ToString() +' Sec'
  write-host ""
  write-host "Container is running since: " -NoNewline
  write-host "$totalTime" -ForegroundColor Cyan
  recurse
}

cls
# Show integraded Scripts
$starttime = Get-Date

$scripts =  (get-childitem -Filter *.ps1 | where name -ne 'welcome.ps1').Name.replace('.ps1','')

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
