<powershell>
Add-Content C:\Windows\System32\drivers\etc\hosts "`n${masterip} ${master_name} puppet"
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile('https://${master_name}:8140/packages/current/install.ps1', 'install.ps1'); .\install.ps1 extension_requests:pp_role=${role}
</powershell>
