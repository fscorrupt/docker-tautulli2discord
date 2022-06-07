function recurse { 
  sleep 60
  echo "Running"
  recurse
}

# Show integraded Scripts
$scripts =  (get-childitem -Filter *.ps1 | where name -ne 'welcome.ps1').Name.replace('.ps1','')

Write-Host "Currently there are '$($scripts.count)' Scripts integrated" -ForegroundColor Yellow
Write-Host  ''
Write-Host "First fill out Config here: " -ForegroundColor Yellow -NoNewline
Write-Host "/opt/appdata/tautulli2discord/config/config.json" -ForegroundColor Cyan 
Write-Host "Example on how to run them:" -ForegroundColor Yellow -NoNewline
Write-Host "docker exec -it tautulli2discord pwsh PlexLibraryStats.ps1" -ForegroundColor Cyan
Write-Host "####################################################" -ForegroundColor Green

foreach ($script in $scripts){
  write-host $script -ForegroundColor Cyan
}

# Call Recursive Function.
recurse
