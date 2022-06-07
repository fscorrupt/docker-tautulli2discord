cls
# Show integraded Scripts
$scripts =  (get-childitem -Filter *.ps1 | where name -ne 'welcome.ps1').Name.replace('.ps1','')

Write-Host "Currently there are '$($scripts.count)' Scripts integrated" -ForegroundColor Yellow
Write-Host  ''
Write-Host "Example on how to run them:" -ForegroundColor Yellow
Write-Host "docker exec -it mcr.microsoft.com/powershell pwsh PlexLibraryStats.ps1" -ForegroundColor Cyan
Write-Host "####################################################" -ForegroundColor Green

foreach ($script in $scripts){
  write-host $script -ForegroundColor Cyan
}
