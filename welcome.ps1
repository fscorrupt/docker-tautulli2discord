# Show integraded Scripts
$scripts =  (get-childitem -Filter *.ps1 | where name -ne 'welcome.ps1').Name.replace('.ps1','')

Write-Host "################################################"
Write-Host "#Currently there are '$($scripts.count)' Scripts integrated#"
Write-Host "################################################"

Write-Host $scripts



