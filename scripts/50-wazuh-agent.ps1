# Instala el agente Wazuh en un cliente Windows y lo enrola al manager.
# Ejecutar en PowerShell COMO ADMINISTRADOR.
param(
  [string]$Manager = "192.168.2.102",
  [string]$Version = "4.14.5",
  [string]$AgentName = $env:COMPUTERNAME
)
$msi = "$env:TEMP\wazuh-agent-$Version-1.msi"
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-$Version-1.msi" -OutFile $msi
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn WAZUH_MANAGER=$Manager WAZUH_REGISTRATION_SERVER=$Manager WAZUH_AGENT_NAME=$AgentName"
Start-Service WazuhSvc
Get-Service WazuhSvc
Write-Host "Agente instalado y enrolado a $Manager. Verifica en el manager con: /var/ossec/bin/agent_control -l"
