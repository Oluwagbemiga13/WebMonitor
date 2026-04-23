using module ./modules/Logger.psm1
using module ./modules/Scheduler.psm1



Write-Warning "Configuration and modules are cached at the script level. If you make changes to the configuration or modules, you will need to restart the PowerShell session for the changes to take effect."

Invoke-Scheduler
