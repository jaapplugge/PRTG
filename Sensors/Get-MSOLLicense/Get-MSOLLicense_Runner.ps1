<#Powershell runner#>
## Parameters
[cmdletbinding()] Param (
    [Parameter(Mandatory=$True,Position=1)] [String]  $Username,
    [Parameter(Mandatory=$True,Position=2)] [String]  $Password,
    [Parameter(Mandatory=$True,Position=3)] [String]  $Prefix,
    [Parameter(Mandatory=$False)] [String]  $Sensor = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Get-MSOLLicense_Sensor.ps1',
    [Parameter(Mandatory=$False)] [String]  $ChannelConfiguration = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Get-MSOLLicense_ChannelConfiguration.xml'        
)
##Run in an x64 context
c:\windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -command ". `"$Sensor`" -filename `"$ChannelConfiguration`" -username $username -password `"$Password`" -prefix $Prefix"
$Password = $null
$Username = $null