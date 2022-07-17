<#
.SYNOPSIS Get-SCCMSCEPAlerts
PRTG-Sensor for alerting whether a Virus / threat is detected in SCEP by SCCM.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects the alerts given by the SCEP service.
I.e. this is the Scep alert page in the SCCM Console.

By setting error-limits in PRTG, this can be used to prompt an error. As errortext, the script will use the
a description based on the first found error. 

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Site
Mandatory parameter for the Sitecode of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-SCCMSiteSystemStatus.ps1
- Parameters:       -SiteServer 'Sccm01.ogd.local' -Site 'OGD' -Configuration 'C:\Scripting\Configurations\Get-SCCMSCEP_Alerts.xml'
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
Version 1.0 / 07.12.2017: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://docs.microsoft.com/en-us/sccm/develop/reference/core/servers/manage/sms_alertevent-server-wmi-class
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True,Position=1)]  [String] $Siteserver,
        [Parameter(Mandatory=$True,Position=2)]  [String] $Site,
        [Parameter(Mandatory=$True,Position=3)]  [String] $Filename,
        [Parameter(Mandatory=$False,Position=4)] [String] $Username,
        [Parameter(Mandatory=$False,Position=5)] [String] $Password
)
## Variables
[Boolean]   $Boolean_Exit    = $False
[Boolean]   $Boolean_Cred    = $False

[XML]       $Configuration   = $null
[XML]       $Error_XML       = $null
[String]    $MachineName     = $null
[String]    $ThreatName      = $null
[String]    $EventTime       = $null

[Array]     $Collected           = @()
[Array]     $Sort_Virus          = @()
[Array]     $Sort_Virus_repeat   = @()
[Array]     $Sort_Virus_multiple = @()
[PSObject]  $FirstAlert          = @()

[Int]       $WarningMax      = 0
[Int]       $ErrorMax        = 0
[String]    $Output_Message  = "OK"
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm

## Query
[String] $Query = @"
SELECT
       SMS_AlertEvent.AlertID
       ,SMS_AlertEvent.EventData
       ,SMS_AlertEvent.EventTime
       ,SMS_AlertEvent.isClosed
       ,SMS_EPAlert.Name
       ,SMS_EPAlert.ID
FROM 
       SMS_AlertEvent
INNER JOIN
       SMS_EPAlert
ON
       SMS_AlertEvent.AlertID = SMS_EPAlert.ID
WHERE 
       SMS_EPAlert.Name like "%Malware detection%"
AND
       SMS_AlertEvent.isClosed = 0
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
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
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
            Write-Error "$TimeStamp : ERROR : Could not collect data from SCCM via WMI."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Output_Message = "Could not collect data from SCCM via WMI." 
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Collected  = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI with Credentials."
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not collect data from SCCM via WMI with Credentials."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Output_Message = "Could not collect data from SCCM via WMI with Credentials." 
            $Boolean_Exit = $True
        }
    }
}

##Sorting and formatting
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Sort_Virus          = $Collected  | Where-Object -Filterscript {$_.SMS_EPAlert.Name -like "Malware detection alert*"} | Sort-object -Property EventTime -Descending
        $FirstAlert          = $Sort_Virus | Select-Object -First 1
        $Sort_Virus_repeat   = $Collected  | Where-Object -Filterscript {$_.SMS_EPAlert.Name -like "Repeated malware detection alert*"} | Sort-object -Property EventTime -Descending
        $Sort_Virus_multiple = $Collected  | Where-Object -Filterscript {$_.SMS_EPAlert.Name -like "Multiple malware detection alert*"} | Sort-object -Property EventTime -Descending
        Write-Verbose   "$Timestamp : LOG   : Collected Virusses       : $($Sort_Virus.Count)."
        Write-Verbose   "$Timestamp : LOG   : Collected Repeat Virus   : $($Sort_Virus_repeat.Count)."
        Write-Verbose   "$Timestamp : LOG   : Collected Multiple Virus : $($Sort_Virus_multiple.Count)."
        If ($Sort_Virus.Count -gt 0) {
            $Error_XML    = $FirstAlert.SMS_AlertEvent.EventData
            $MachineName  = $Error_XML.Event.Computername
            $ThreatName   = $Error_XML.Event.ThreatName
            $EventTime    = ([Management.ManagementDateTimeConverter]::ToDateTime($FirstAlert.SMS_AlertEvent.EventTime)).ToString()
            Write-verbose   "$TimeStamp : LOG   : MachineName : $MachineName"
            Write-verbose   "$TimeStamp : LOG   : ThreatName  : $ThreatName"
            Write-verbose   "$TimeStamp : LOG   : EventTime   : $EventTime"
        }
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not sort and format data."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not sort and format data." 
        $Boolean_Exit = $True
    }
}

##Writing to PRTG
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try { 
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Virus Alert" -Value $($Sort_Virus.Count)
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Repeated Virusses detected" -Value $($Sort_Virus_repeat.Count)
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Multiple Virusses detected" -Value $($Sort_Virus_multiple.Count)
        Write-Verbose    "$TimeStamp : LOG   : Written values to PRTG channels"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not write data to PRTG."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not write data to PRTG." 
        $Boolean_Exit  = $True
    }
}

##Determine Error-Status
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose    "$TimeStamp : LOG   : Looping through channel-configuration for error-values"
    $WarningMax    = ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq "Virus Alert"}).LimitMaxWarning
    $ErrorMax      = ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq "Virus Alert"}).LimitMaxWarning
    If ( (($Sort_Virus.Count) -gt $ErrorMax) -and ($ErrorMax -ge 0) ) {
        $Output_Message = "$MachineName - Virus detected `"$ThreatName`" on $EventTime"
    } ElseIf ( (($Sort_Virus.Count) -gt $WarningMax) -and ($WarningMax -ge 0) ) {
        $Output_Message = "Warning $MachineName - Virus detected `"$ThreatName`" on $EventTime"
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