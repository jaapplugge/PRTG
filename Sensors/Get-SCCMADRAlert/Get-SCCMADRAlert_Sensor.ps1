<#
.SYNOPSIS
PRTG-Sensor for checking the current status of an automatic deployment rule (ADR) in a Config Manager Site

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects any alert triggered in SCCM for a
failure of an ADR. 
For the ADR's listed in the XML, it will show a value of '100' if all is well, and '0' (Error) if the ADR has failed.

By setting error-limits in PRTG, this can be used to prompt an error. Clearing the sensor can be done by either 
successfully running the ADR, or clearing the alert-value in PRTG.

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Site
Mandatory parameter for the Sitecode of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Username
Optional parameter, for defining the name of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string in a domain\accountname format.

.PARAMETER Password
Optional parameter, for defining the password of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string value, ment to be used with %windowspassword (PRTG variable).

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-SCCMADRAlert_Sensor.ps1
- Parameters:       -SiteServer 'Sccm01.test.local' -Site 'TST' -Configuration 'C:\Scripting\Configurations\Get-SCCMADRAlert_ChannelConfiguration.xml'
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
https://github.com/jaapplugge/PRTGModule
#>  

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Siteserver,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $Site,
        [Parameter(Mandatory=$True ,Position=3)] [String]  $Filename,
        [Parameter(Mandatory=$False)] [String]  $Username = $null,
        [Parameter(Mandatory=$False)] [String]  $Password = $null,        
        [Parameter(Mandatory=$False)] [Boolean] $Timeframe = $False,
        [Parameter(Mandatory=$False)] [Int]     $Months = 2
)

## Variables
[BOOLEAN]   $Boolean_Exit    = $False
[BOOLEAN]   $Boolean_Error   = $False
[BOOLEAN]   $Boolean_Warning = $False
[BOOLEAN]   $Boolean_Cred    = $False
[INT]       $Collected_Count = 0
[int]       $Status          = 100
[Array]     $Collected       = @()
[STRING]    $Output_Message  = ""
[STRING]    $Command         = $MyInvocation.MyCommand.Name
[ARRAY]     $Unique_Errors   = @()
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]    $String_Error    = 'Rule Failure alert'
[XML]       $Configuration   = $null

## Query
[String] $Query = @"
SELECT 
        Alertstate
        ,InstanceNameParam1
        ,InstanceNameParam2
        ,DateCreated
        ,Enabled
        ,Name
FROM 
        SMS_Alert
WHERE
        AlertState = 0
AND
        Enabled = 'True'
AND 
        Name = 'Rule Failure alert'
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
[String] $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
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
                Write-Verbose "$Timestamp : LOG   : Credentialobject build on username $Username. `n"
        } Catch {
                Write-Error "$Timestamp : ERROR : Could not build credential object."
                $Output_Message = "Could not build credential object."
                $Boolean_Exit = $True 
        }
}
$Username = $null
$Password = $null

## Importing configuration-file
[String] $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration          = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $ChannelConfiguration   = $Configuration.prtg.result
        Write-Verbose             "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

##Collecting errormessages from SCCM-server
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $False) {
        Try {
            $Collected = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.message)"
            $Output_Message = "Could not collect data from SCCM via WMI."
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Collected = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI with Credentials."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI with Credentials."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.message)"
            $Output_Message = "Could not collect data from SCCM via WMI with Credentials."
            $Boolean_Exit = $True
        }
    }
}

##Sorting results
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {        
    Try {
        $Collected       = $Collected | Sort-Object -Property InstanceNameParam1,DateCreated -Descending
        $Collected_Count = $Collected.Count
        Write-Verbose "$Timestamp : LOG   : Imported and sorted $Collected_Count Alerts from SCCM."
    } Catch {
        Write-Error   "$Timestamp : ERROR : Could not sort and count Collected events."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.message)"
        $Output_Message = "Could not sort and count Collected events."
        $Boolean_Exit = $True
    }
}

##Looping through channels to filter events
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Collected_Count -eq 0) {
        $Count_Collected_Errors = 0
        $Output_Message         = 'No Errors found'
        Write-Verbose             "$Timestamp : LOG   : No Alerts found in SCCM."
        Write-Verbose             "$Timestamp : LOG   : writing 'No Errors found'."
    } Else {
        Foreach ($Item in $ChannelConfiguration) {
            $Unique_Errors += ($Collected | Where-Object -FilterScript {$_.InstanceNameParam1 -eq ($Item.Channel)} | Select-Object -first 1)
            Write-Verbose "$Timestamp : LOG   : Filtered unique error for channel $($Item.Channel)" 
        }
        $Count_Collected_Errors = $Unique_Errors.Count
        Write-Verbose "$Timestamp : LOG   : Counted $Count_Collected_Errors Unique alerts."
    }
}

##Writing to XML
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($Item in $ChannelConfiguration) {
        [int]     $Count     = 0
        [int]     $Status    = 100
        While ($Count -lt $Count_Collected_Errors) {
            [String]  $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
            Write-Verbose    "$Timestamp : LOG   : Looping through channels ($count)"
            If ( ($Count_Collected_Errors -gt 0) -and (($Unique_Errors[$Count].InstanceNameParam1) -eq ($Item.Channel)) -and (($Unique_Errors[$Count].Name) -eq $String_Error) ) {
                Write-Verbose      "$Timestamp : LOG   : Alert evaluated to be Error $String_Error." 
                [int] $Status    = 0
                Write-Verbose      "$Timestamp : LOG   : Set Status for channel $($Item.Channel) to 0." 
                If ($Boolean_Error -eq $False) {
                    Write-verbose "$Timestamp : LOG   : Outputmessage not yet set to error." 
                    $Output_Message = ($Item.Channel) + ' - Rule Failure alert since ' + ([Management.ManagementDateTimeConverter]::ToDateTime($Unique_Errors[$Count].DateCreated)) 
                    Write-Verbose "$Timestamp : LOG   : $Output_message." 
                    $Boolean_Error = $True
                }
            } Else {
                If ( ($Boolean_Error -eq $False) -and ($Boolean_warning -eq $False) ) {
                    $Output_Message  = 'No Errors found'
                    Write-Verbose "$Timestamp : LOG   : No matching alert found, returning all is well!"
                }
            }
            $Count++
        }
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel ($Item.Channel) -Value $Status
        Write-Verbose    "$Timestamp : LOG   : Written result to PRTG XML for Channel."
    }
}

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml