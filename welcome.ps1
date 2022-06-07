# Show integraded Scripts
$scripts =  (get-childitem -Filter *.ps1).Name

Write-Host "################################################"
Write-Host "#Currently there are '$($scripts.count)' Scripts integrated#"
Write-Host "################################################"

Write-Host $scripts
