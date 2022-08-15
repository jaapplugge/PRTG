<#
.SYNOPSIS

PRTG-Sensor for checking the current status of a Tasksequence for OSD in a Config Manager Site

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects the results of a named tasksequence.

By setting error-limits in PRTG, this can be used to prompt an error. Clearing the sensor can be done by either 
successfully deploying an OS, or clearing the alert-value in PRTG.

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Tasksequence
Mandatory parameter of the name of the Tasksequence to monitor.

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
- EXE/Script:       Get-SCCMTaskSequenceStatus_sensor.ps1
- Parameters:       -SiteServer 'Sccm01.test.local' -Tasksequence "Deploy Windows 10" -Configuration 'C:\Scripting\Configurations\Get-SCCMTaskSequenceStatus_ChannelConfiguration.xml'
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
Version 1.0 / 14.03.2019: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14.11.2021: Moved functions to PRTG Module
Version 2.1 / 10.07.2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Siteserver,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $TaskSequence,
        [Parameter(Mandatory=$True ,Position=3)] [String]  $Filename,
        [Parameter(Mandatory=$False)] [String]  $Username = $null,
        [Parameter(Mandatory=$False)] [String]  $Password = $null 
)
## Variables
[Boolean]   $Boolean_Exit    = $False
[Boolean]   $Boolean_Cred    = $False
[String]    $Output_Message  = $null
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[XML]       $Configuration   = $null
[Int]       $NumberErrors     = 0
[Int]       $NumberInProgress = 0
[Int]       $NumberOther      = 0
[Int]       $NumberSuccess    = 0
[Int]       $NumberTargeted   = 0
[Int]       $NumberUnknown    = 0

## Query
[String] $Query = @"
Select 
        ApplicationName
        ,CollectionName
        ,NumberErrors
        ,NumberInProgress
        ,NumberOther
        ,NumberSuccess
        ,NumberTargeted
        ,NumberUnknown 
From 
        SMS_DeploymentSummary 
Where 
        ApplicationName = `"$TaskSequence`"
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
        Write-Verbose "$Timestamp : LOG   : Credentialobject build on username $Username."
    } Catch {
        Write-Error     "$Timestamp : ERROR : Could not build credential object."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
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
        $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

##Collecting SCCM Sitecode
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $True) {
        Try {        
            $site = Connect-PRTGtoSCCMforSiteCode -SiteServer $SiteServer -Credential $Credential
            Write-Verbose "$Timestamp : LOG   : Collected sitecode $Sitecode from siteserver $Siteserver w/ cred."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect sitecode from server $Siteserver w/ cred."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect sitecode from server $Siteserver w/ cred."
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $site = Connect-PRTGtoSCCMforSiteCode -SiteServer $SiteServer 
            Write-Verbose "$Timestamp : LOG   : Collected sitecode $Sitecode from siteserver $Siteserver."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect sitecode from server $Siteserver."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect sitecode from server $Siteserver"
            $Boolean_Exit = $True
        }
    }
}

##Collecting errormessages from SCCM-server
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $False) {
        Try {
            $Collected = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI"
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from SCCM via WMI."
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Collected = (Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI w/ cred."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI w/ cred."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from SCCM via WMI w/ cred."
            $Boolean_Exit = $True
        }
    }
}

##Calculating results
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {        
    Foreach ($Item in $Collected) {
        Try {
            $NumberErrors     += $Item.NumberErrors
            $NumberInProgress += $Item.NumberInProgress
            $NumberOther      += $Item.NumberOther
            $NumberSuccess    += $Item.NumberSuccess
            $NumberTargeted   += $Item.NumberTargeted
            $NumberUnknown    += $Item.NumberUnknown
            Write-Verbose "$TimeStamp : LOG   : Added numbers from deployment $($Item.CollectionName)"
        } Catch {
            Write-Error   "$Timestamp : ERROR : Could not add up numbers."
            Write-Error   "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not add up numbers."
            $Boolean_Exit = $True
        }
    }
}

##Writing to PRTG
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {        
    Try {
        Write-Verbose "$Timestamp : LOG   : Writing results to PRTG"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Clients total'       -Value $NumberTargeted
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Clients error'       -Value $NumberErrors
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Clients in progress' -Value $NumberInProgress
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Clients unknown'     -Value $NumberUnknown
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Clients other'       -Value $NumberOther
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Clients success'     -Value $NumberSuccess
        Write-Verbose "$Timestamp : LOG   : Clients total       : $NumberTargeted"
        Write-Verbose "$Timestamp : LOG   : Clients error       : $NumberErrors"
        Write-Verbose "$Timestamp : LOG   : Clients in progress : $NumberInProgress"
        Write-Verbose "$Timestamp : LOG   : Clients unknown     : $NumberUnknown"
        Write-Verbose "$Timestamp : LOG   : Clients other       : $NumberOther"
        Write-Verbose "$Timestamp : LOG   : Clients success     : $NumberSuccess"
    } Catch {
        Write-Error   "$Timestamp : ERROR : Could not write results to PRTG."
        Write-Error   "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write results to PRTG."
        $Boolean_Exit = $True
    }
}

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
} Else {
    $Output_Message = "Tasksequence `"$TaskSequence`" results: $NumberTargeted total, $NumberErrors error, $NumberSuccess success."
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml