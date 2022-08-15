<#
.SYNOPSIS

PRTG-Sensor for checking the Status for Windows updates on SCCM Managed servers

.DESCRIPTION
This script is ment to be used as PRTG-sensor. PRTG has a perfectly fine built-in sensor for reading 
systemuptime of a windows server via WMI. This server can alert if a server has been up for more than
x days.
We usually update (and thus reboot) a server based on maintenancewindows. This means that we cannot
measure uptime-error-values based on number of days. These can vary, according to how the maintenance-
windows are set.

This sensor reads the uptime from a server, and from its local WMI the previous and last maintenancewindow.
It will compare these dates, and a) give a warning if a server is in maintenancewindow, but has not restarted. 
And b) give an error if server is not in maintenancewindow, but has last restarted before the start of
the previous maintenancewindow. Thus too long ago.

.PARAMETER Server
Mandatory parameter for the FQDN of the server to monitor.

.PARAMETER FileName
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Override
Optional switch parameter for overriding the errorstatus of the sensor. Gives a green light.

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
- EXE/Script:       Get-SCCMUptimeSensor.ps1
- Parameters:       -Server 'Sccm01.ogd.local' -Configuration 'C:\Scripting\Configurations\Get-SCCMUptimeSensor.xml'
- Enviroment:       personal preference
- Security context: a serviceaccount with remote management role on the server
- Mutex name:       optionally
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. Running this sensor 15min will be more than enough.

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 18.02.2019: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14.11.2021: Moved functions to PRTG Module
Version 2.1 / 10.07.2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True  ,Position=1)] [String]  $Server,
        [Parameter(Mandatory=$True  ,Position=2)] [String]  $Filename,
        [Parameter(Mandatory=$False ,Position=3)] [String]  $Username,
        [Parameter(Mandatory=$False ,Position=4)] [String]  $Password,
        [Parameter(Mandatory=$False ,Position=5)] [Switch]  $Override
)
## Variables
[Boolean]   $Boolean_Exit     = $False
[Boolean]   $Boolean_override = $False
[Boolean]   $Boolean_Cred     = $False
If ($Override) { $Boolean_override -eq $True }

[Array] $Updates_Missing_Alert   = @()
[Array] $Updates_Installed_Alert = @()
[Array] $Updates_Failed_Alert    = @()

[PSObject]  $Updates         = $null
[XML]       $Configuration   = $null
[DateTime]  $PatchTuesday    = 0
[DateTime]  $LastRebootTime  = 0
[String]    $Output_Message  = "OK"
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm

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
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not build credential object."        
        $Boolean_Exit = $True 
    }
}
$Username = $null
$Password = $null
$SecureString = $null

## Importing configuration-file
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
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

## Collecting LastRebootTime from WMI
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $True) {
        Try {
            $LastRebootTime = Get-PRTGClientLastReboot -Server $Server -Credential $Credential
            Write-Verbose     "$TimeStamp : LOG   : Collected LastRebootTime $LastRebootTime"
            $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Days since last reboot" -Value $( ( (Get-Date) - $LastRebootTime ).Days)
            Write-Verbose     "$TimeStamp : LOG   : Written $( ( (Get-Date) - $LastRebootTime ).Days) to channel 'Days since last reboot'"
        } Catch {
            Write-Error       "$TimeStamp : ERROR : Could not collect LastRebootTime from server $Server w/ cred."
            Write-Error       "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect LastRebootTime from server $Server w/ cred."
            $Boolean_Exit   = $True
        }
    } Else {
        Try {
            $LastRebootTime = Get-PRTGClientLastReboot -Server $Server
            Write-Verbose     "$TimeStamp : LOG   : Collected LastRebootTime $LastRebootTime"
            $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Days since last reboot" -Value $( ( (Get-Date) - $LastRebootTime ).Days)
            Write-Verbose     "$TimeStamp : LOG   : Written $( ( (Get-Date) - $LastRebootTime ).Days) to channel 'Days since last reboot'"
        } Catch {
            Write-Error       "$TimeStamp : ERROR : Could not collect LastRebootTime from server $Server."
            Write-Error       "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect LastRebootTime from server $Server."
            $Boolean_Exit   = $True
        }
    }
}

## Collecting Windows updates through WMI
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $True) {
        Try {
            $Updates        = Get-PRTGClientUpdateStatus -Server $Server -Credential $Credential
            Write-Verbose     "$TimeStamp : LOG   : Collected updates listed on server $Server w/ creds."
        } Catch {
            Write-Error       "$TimeStamp : ERROR : Could not collect listed updates from server $Server w/ creds."
            Write-Error       "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect listed updates from server $Server w/ creds."
            $Boolean_Exit   = $True
        }
    } Else {
        Try {
            $Updates        = Get-PRTGClientUpdateStatus -Server $Server
            Write-Verbose     "$TimeStamp : LOG   : Collected updates listed on server $Server."
        } Catch {
            Write-Error       "$TimeStamp : ERROR : Could not collect listed updates from server $Server."
            Write-Error       "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect listed updates from server $Server."
            $Boolean_Exit   = $True
        }
    }
}

##Collect previous patchtuesday
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $PatchTuesday   = Get-PRTGSccmPatchTuesday 
        Write-Verbose     "$TimeStamp : LOG   : Collected previous patchtuesday: $PatchTuesday"
    } Catch {
        Write-Error       "$TimeStamp : ERROR : Could not collect patchtuesday."
        Write-Error       "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect patchtuesday."
        $Boolean_Exit   = $True
    }
}

##Writing to PRTG
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel 'Updates installed (total)' -Value $($Updates.Updates_installed.Count)
        Write-Verbose     "$TimeStamp : LOG   : Written $($Updates.Updates_installed.Count) to channel 'Updates installed (total)'."
        $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel 'Updates missing (total)' -Value $($Updates.Updates_missing.Count)
        Write-Verbose     "$TimeStamp : LOG   : Written $($Updates.Updates_missing.Count) to channel 'Updates missing (total)'."
        $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Updates failed (total)" -Value $($Updates.Updates_failed.Count)
        Write-Verbose     "$TimeStamp : LOG   : Written $($Updates.Updates_failed.Count) to channel 'Updates failed (total)'."
        If ($Updates.Updates_missing.Count -gt 0)   {$Updates_Missing_Alert   = $Updates.Updates_missing | Where-Object -FilterScript {[System.Management.ManagementDateTimeconverter]::ToDateTime($_.ScanTime) -gt $PatchTuesday} }
        If ($Updates.Updates_installed.Count -gt 0) {$Updates_Installed_Alert = $Updates.Updates_installed | Where-Object -FilterScript {[System.Management.ManagementDateTimeconverter]::ToDateTime($_.ScanTime) -gt $PatchTuesday} }
        If ($Updates.Updates_failed.Count -gt 0) {$Updates_Failed_Alert    = $Updates.Updates_failed | Where-Object -FilterScript {[System.Management.ManagementDateTimeconverter]::ToDateTime($_.ScanTime) -gt $PatchTuesday} }
        $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Updates installed (since patchtuesday)" -Value $($Updates_Installed_Alert.Count)
        Write-Verbose     "$TimeStamp : LOG   : Written $($Updates_Installed_Alert.Count) to channel 'Updates installed (since patchtuesday)'."
        $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Updates missing (since patchtuesday)"   -Value $($Updates_Missing_Alert.Count)
        Write-Verbose     "$TimeStamp : LOG   : Written $($Updates_Missing_Alert.Count) to channel 'Updates missing (since patchtuesday)'."
        $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Updates failed (since patchtuesday)"    -Value $($Updates_Failed_Alert.Count)
        Write-Verbose     "$TimeStamp : LOG   : Written $($Updates_Failed_Alert.Count) to channel 'Updates failed (since patchtuesday)'."
    } Catch {
        Write-Error       "$TimeStamp : ERROR : Could not write results to PRTG."
        Write-Error       "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write results to PRTG."
        $Boolean_Exit   = $True
    }
}

##Determining ReturnMessage
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose     "$TimeStamp : LOG   : Writing output-message."
    If ( $($Updates_Failed_Alert.Count) -gt 0) {
        $Output_Message = "Failed Windows updates: $($Updates_Failed_Alert[0].Title) ( $($Updates_Failed_Alert.Count) total)"
        $Configuration.prtg.error = '2'
        Write-Verbose     "$TimeStamp : LOG   : Writing output-message for failed updates."
        Write-Verbose     "$TimeStamp : LOG   : Failed Windows updates: $($Updates_Failed_Alert[0].Title) ($($Updates_Failed_Alert.Count) total) `n"
    } ElseIf ( $($Updates_Missing_Alert.Count) -gt 0) {
        $Output_Message = "Pending Windows updates: $($Updates_missing_Alert[0].Title) ($($Updates_Missing_Alert.Count) total)"
        Write-Verbose     "$TimeStamp : LOG   : Writing output-message for pending updates."
        Write-Verbose     "$TimeStamp : LOG   : Pending Windows updates: $($Updates_missing_Alert[0].Title) ( $($Updates_Missing_Alert.Count) total)"
        If ( ($LastRebootTime -gt $PatchTuesday) -and ($Boolean_override -eq $False) ) {
            $Configuration.prtg.error = '1'
            Write-Verbose     "$TimeStamp : LOG   : Last reboot was later than last patchtuesday, so all updates should be installed."
            Write-Verbose     "$TimeStamp : LOG   : Setting warningstate."
        }
    } Else {
        $Output_Message = "Installed Windows updates: $($Updates_Installed_Alert.Count) / Last reboot $LastRebootTime"
        Write-Verbose     "$TimeStamp : LOG   : Writing output-message for installed updates."
        Write-Verbose     "$TimeStamp : LOG   : Installed Windows updates: $($Updates_Installed_Alert.Count) / Last reboot $LastRebootTime"            
    }
} Else {
    $Configuration.prtg.error = '2'
    Write-Verbose     "$TimeStamp : LOG   : Setting sensor to ERROR-status."
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml
##Script end