<#Powershell runner#>
## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True,  Position=1)] [String]  $Computer,
        [Parameter(Mandatory=$False, Position=2)] [String]  $Password,
        [Parameter(Mandatory=$False, Position=3)] [String]  $Username,
        [Parameter(Mandatory=$False, Position=3)] [String]  $Sensor = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Get-McAfeeStatus_Sensor.ps1',
        [Parameter(Mandatory=$False, Position=3)] [String]  $ChannelConfiguration = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Get-McAfeeStatus_ChannelConfiguration.xml'
)

##Run in an x64 context
If ($Username) {
    c:\windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -command ". `"$Sensor`" -filename `"$ChannelConfiguration`" -username $username -password `"$Password`" -computer $Computer"
} Else {
    c:\windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -command ". `"$Sensor`" -filename `"$ChannelConfiguration`" -computer $Computer"
}
$Password = $null
$Username = $null