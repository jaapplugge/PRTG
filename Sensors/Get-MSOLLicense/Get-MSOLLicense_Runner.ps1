<#Powershell runner#>
## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$False,Position=1)] [String]  $Username,
        [Parameter(Mandatory=$False,Position=2)] [String]  $Password,
        [Parameter(Mandatory=$False,Position=3)] [String]  $Prefix
)
##Run in an x64 context
c:\windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -command ". 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Get-MSOLLicense_sensor.ps1' -filename 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Get-MSOLLicense_Sensor.xml' -username $username -password $Password -prefix $Prefix"
$Password = $null
$Username = $null