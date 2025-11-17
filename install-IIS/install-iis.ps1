# install-iis.ps1
Install-WindowsFeature -name Web-Server -IncludeManagementTools

# Remove default IIS page (ensure both common filenames are covered)
Remove-Item C:\inetpub\wwwroot\iisstart.htm -Force
Remove-Item C:\inetpub\wwwroot\iisstart.html -Force 

# Add custom index page
Add-Content -Path C:\inetpub\wwwroot\index.html -Value "<h1>Hello from IaC VMSS!</h1><h2>Instance ID: $($env:COMPUTERNAME)</h2>"