<#
.SYNOPSIS Get-SCCMSCEPClientHealthStatus

PRTG-Sensor for checking the current status of the SCEP defenition, on a tennant managing SCEP via SCCM.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects the status summary for the deployment
of anti-virus-definitions for a collection listed in the 'Collection' parameter from the siteservers WMI.  

By setting error-limits in PRTG, this can be used to prompt an error. Clearing the sensor can be done by either 
successfully remediating the clients AntiVirus definitions, or clearing the alert-value in PRTG.

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Site
Mandatory parameter for the Sitecode of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Collection
Mandatory parameter to the name of the Collection in SCCM which to monitor.

.PARAMETER Username
Optional parameter, for defining the name of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string in a domain\accountname format.

.PARAMTER Password
Optional parameter, for defining the password of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string value, ment to be used with %windowspassword (PRTG variable).

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-SCCMSCEPClientHealthStatus_sensor.ps1
- Parameters:       -SiteServer 'Sccm01.ogd.local' -Site 'OGD' -Configuration 'C:\Scripting\Configurations\Get-SCCMSCEPClientHealthStatus_ChannelConfiguration.xml'
- Enviroment:       personal preference
- Security context: a serviceaccount with the 'read-only analyst' role in SCCM
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. Running this sensor every hour will be more than enough.

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 19.11.2018: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Siteserver,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $Site,
        [Parameter(Mandatory=$True ,Position=3)] [String]  $Filename,
        [Parameter(Mandatory=$False,Position=4)] [String]  $Collection = 'SMS00001',
        [Parameter(Mandatory=$False,Position=5)] [String]  $Username,
        [Parameter(Mandatory=$False,Position=6)] [String]  $Password
)

## Variables
[Boolean]   $Boolean_Exit    = $False
[Boolean]   $Boolean_Error   = $False
[Boolean]   $Boolean_Warning = $False
[Boolean]   $Boolean_Cred    = $False
[XML]       $Configuration   = $null
[Array]     $Collected       = @()
[String]    $Output_Message  = "OK"
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm

## Query
[String] $Query = @"
SELECT 
        CollectionID
        ,OverallStatusNotYetInstalledCount
        ,OverallStatusNotSupportedCount
        ,OverallStatusInactiveCount
        ,OverallNotClientCount
        ,UnhealthyCount
        ,OverallStatusAtRiskCount
        ,InstallFailedCount
        ,InstallRebootPendingCount
        ,TotalMemberCount
FROM 
        SMS_EndpointProtectionHealthStatus 
WHERE 
        CollectionID = `"$Collection`"
"@

Write-Verbose "SENSOR:$Command"
Write-Verbose $("_" * 120)
Write-Verbose "$Timestamp : LOG   : Username: $env:username"
Write-Verbose "$Timestamp : LOG   : Session : $( ([System.IntPtr]::Size)*8 )bit Session"

##Importing Module File
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_Exit -eq $False) -and ( (Get-Module).Name -notcontains 'PRTG_Module') ) {
    Try {
        Import-Module -Name 'PRTG_Module'
        Write-Verbose "$TimeStamp : LOG   : Imported PRTG-module"
    } Catch {
        Write-Error     "$Timestamp : ERROR : Could not import PRTG-module."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "PRTG-Module could not be loaded"
        $Boolean_Exit   = $True        
    }
}

##Checking if Creds are given
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Username -eq "") -or ($Username -eq $null) ) {
    Write-Verbose "$TimeStamp : LOG   : Using context creds."
    $Boolean_Cred = $False
} Else {
    $Boolean_Cred = $True
    Write-Verbose "$TimeStamp : LOG   : Creds provided, using.."
    ##Building credential-object
    Try {
        $SecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $Credential   = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecureString
        Write-Verbose "$Timestamp : LOG   : Credentialobject build on username $Username."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not build credential object."        
        $Boolean_Exit = $True 
    }
}
$SecureString = $null
$Username     = $null
$Password     = $null

## Importing configuration-file
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML." 
        $Boolean_Exit = $True
    }
}

##Collecting errormessages from SCCM-server
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $False) {
        Try {
            $Collected = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from SCCM via WMI." 
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Collected = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI with Credentials"
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI with Credentials."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from SCCM via WMI with Credentials." 
            $Boolean_Exit = $True
        }
    }
}

##Writing to PRTG
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try { 
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "All Clients" -Value $($Collected.TotalMemberCount)
        Write-Verbose    "$TimeStamp : LOG   : All Clients                        : $($Collected.TotalMemberCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client installation failed" -Value $($Collected.InstallFailedCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client installation failed    : $($Collected.InstallFailedCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client install PendingReboot" -Value $($Collected.InstallRebootPendingCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client install PendingReboot  : $($Collected.InstallRebootPendingCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client not installed" -Value $($Collected.OverallStatusNotYetInstalledCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client not installed          : $($Collected.OverallStatusNotYetInstalledCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client install not supported" -Value $($Collected.OverallStatusNotSupportedCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client install not supported  : $($Collected.OverallStatusNotSupportedCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client inactive" -Value $($Collected.OverallStatusInactiveCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client inactive               : $($Collected.OverallStatusInactiveCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Conf.Mgr. client not installed" -Value $($Collected.OverallNotClientCount)
        Write-Verbose    "$TimeStamp : LOG   : Conf.Mgr. client not installed     : $($Collected.OverallNotClientCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client unhealthy" -Value $($Collected.UnhealthyCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client unhealthy              : $($Collected.UnhealthyCount)"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "SCEP Client at risk" -Value $($Collected.OverallStatusAtRiskCount)
        Write-Verbose    "$TimeStamp : LOG   : SCEP Client at risk                : $($Collected.OverallStatusAtRiskCount)"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not write data to PRTG for each channel."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write data to PRTG for each channel." 
        $Boolean_Exit  = $True
    }
}

##Determine Error-Status
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose    "$TimeStamp : LOG   : Looping through channel-configuration for error-values"
    $ChannelConfiguration   = $Configuration.prtg.result
    Foreach ($Channel in $ChannelConfiguration) {
        [Int] $Int_Value      = 0
        [Int] $Int_MaxWarning = 0
        [Int] $Int_MaxError   = 0
        [String] $Timestamp   = Get-Date -format yyyy.MM.dd_hh:mm
        [Int] $Int_Value      = $Channel.Value
        [Int] $Int_MaxWarning = $Channel.LimitMaxWarning
        [Int] $Int_MaxError   = $Channel.LimitMaxError
        Write-Verbose "$TimeStamp : LOG   : Channel $($Channel.channel) : $($Channel.Value) : Checking for error values."
        If ( ($Int_MaxWarning -lt $Int_Value) -and ($Int_MaxWarning -ne 0) -and ($Boolean_Warning -eq $False) -and ($Boolean_Error -eq $False) ) {
            $Boolean_Warning = $True
            $Output_Message  = "$($Channel.Channel)  : $($Channel.Value) - Create a supportticket!"
            Write-Verbose      "$TimeStamp : LOG   : Channel $($Channel.channel) : $($Channel.Value) > $($Channel.LimitMaxWarning) : Warning triggered."
            Write-Verbose      "$TimeStamp : LOG   : $Output_Message `n"
        }
        If ( ($Int_MaxError -lt $Int_Value) -and ($Int_MaxError -ne 0) -and ($Boolean_Error -eq $False) ) {
            $Boolean_Warning = $True
            $Boolean_Error   = $True
            $Output_Message  = "$($Channel.Channel)  : $($Channel.Value) - Create a supportticket!!"
            Write-Verbose      "$TimeStamp : LOG   : Channel $($Channel.channel) : $($Channel.Value) > $($Channel.LimitMaxError) : Error triggered."
            Write-Verbose      "$TimeStamp : LOG   : $Output_Message `n"
        }
    }
}

##Caching errors
If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml
##Script ends