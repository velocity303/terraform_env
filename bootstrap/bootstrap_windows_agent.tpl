<powershell>
$DNSSuffix = "${dnssuffix}"

#Update primary DNS Suffix for FQDN
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" -Name Domain -Value $DNSSuffix
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" -Name "NV Domain" -Value $DNSSuffix

Add-Content C:\Windows\System32\drivers\etc\hosts "`n${masterip} ${master_name} puppet"
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile('https://${master_name}:8140/packages/current/install.ps1', 'install.ps1'); .\install.ps1 extension_requests:pp_role=${role}
</powershell>
