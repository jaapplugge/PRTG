<#
.SYNOPSIS Get-SCCMUptime

PRTG-Sensor for checking the Uptime of a server managed by SCCM.

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
- EXE/Script:       Get-SCCMUptime_Sensor.ps1
- Parameters:       -Server 'Sccm01.test.local' -Configuration 'C:\Scripting\Configurations\Get-SCCMUptime_ChannelConfiguration.xml'
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
This script is written by Jaap Plugge, Σ OGD
Version 1.0 / 18-02-2019. 
Version 2.0 / 14-11-2021: Moved functions to PRTG Module

.NOTES
This script uses the PRTGModule published on https://dev.azure.com/ogd/Geldmaat/_git/GM_PRTGSensoren/_Powershell_Module

.LINK
https://code.ogdsoftware.nl/

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

[XML]       $Configuration   = $null
[DateTime]  $LastRebootTime  = 0
[PSObject]  $MWindow_object  = $null
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
            $LRT            = Get-Date -Year $($LastRebootTime).Year -Month $($LastRebootTime).Month -Day $($LastRebootTime).Day -Hour 3 -Minute 0 -Second 0 -Millisecond 0
            Write-Verbose     "$TimeStamp : LOG   : Collected LastRebootTime $LastRebootTime"
            $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Days since last reboot" -Value $( ( (Get-Date) - $LastRebootTime ).Days)
            Write-Verbose     "$TimeStamp : LOG   : Written $( ( (Get-Date) - $LastRebootTime ).Days) to channel 'Days since last reboot'"
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not collect LastRebootTime from server $Server w/ cred."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect LastRebootTime from server $Server w/ cred."
            $Boolean_Exit   = $True
        }
    } Else {
        Try {
            $LastRebootTime = Get-PRTGClientLastReboot -Server $Server
            $LRT            = Get-Date -Year $($LastRebootTime).Year -Month $($LastRebootTime).Month -Day $($LastRebootTime).Day -Hour 3 -Minute 0 -Second 0 -Millisecond 0
            Write-Verbose     "$TimeStamp : LOG   : Collected LastRebootTime $LastRebootTime"
            $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Days since last reboot" -Value $( ( (Get-Date) - $LastRebootTime ).Days)
            Write-Verbose     "$TimeStamp : LOG   : Written $( ( (Get-Date) - $LastRebootTime ).Days) to channel 'Days since last reboot'"
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not collect LastRebootTime from server $Server."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect LastRebootTime from server $Server."
            $Boolean_Exit   = $True
        }
    }
}

##Collecting maintenancewindows from client
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $True) {
        Try {
            $MWindow_object = Get-PRTGClientMaintenanceWindow -Server $Server -Credential $Credential
            Write-Verbose     "$TimeStamp : LOG   : Collected maintenancewindow-object"
            Write-Verbose     "$TimeStamp : LOG   : StartTime next maintenancewindow: $($MWindow_object.StartTime)"
            Write-Verbose     "$TimeStamp : LOG   : EndTime   next maintenancewindow: $($MWindow_object.EndTime)"
            $NMW            = Get-Date -Year $($MWindow_object.StartTime.Year) -Month $($MWindow_object.StartTime.Month) -Day $($MWindow_object.StartTime.Day) -Hour 3 -Minute 0 -Second 0 -Millisecond 0
            $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Days until start next maintenancewindow" -Value $( ( $($MWindow_object.StartTime) - (Get-Date) ).Days)
            Write-Verbose     "$TimeStamp : LOG   : Written days until start next maintenancewindow in PRTG."
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not collect maintenancewindows from SCCM client on server $Server w/ creds."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect maintenancewindows from SCCM client on server $Server w/ creds."
            $Boolean_Exit   = $True
        }
    } Else {
        Try {
            $MWindow_object = Get-PRTGClientMaintenanceWindow -Server $Server
            Write-Verbose     "$TimeStamp : LOG   : Collected maintenancewindow-object"
            Write-Verbose     "$TimeStamp : LOG   : StartTime next maintenancewindow: $($MWindow_object.StartTime)"
            Write-Verbose     "$TimeStamp : LOG   : EndTime   next maintenancewindow: $($MWindow_object.EndTime)"
            $NMW            = Get-Date -Year $($MWindow_object.StartTime).Year -Month $($MWindow_object.StartTime).Month -Day $($MWindow_object.StartTime).Day -Hour 3 -Minute 0 -Second 0 -Millisecond 0
            $Configuration  = Write-PRTGresult -Configuration $Configuration -Channel "Days until start next maintenancewindow" -Value $( ( $($MWindow_object.StartTime) - (Get-Date) ).Days)
            Write-Verbose     "$TimeStamp : LOG   : Written days until start next maintenancewindow in PRTG."
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not collect maintenancewindows from SCCM client on server $Server."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect maintenancewindows from SCCM client on server $Server."
            $Boolean_Exit   = $True
        }
    }
}

##Collect previous and next patchtuesday
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $NPT = Get-PRTGSccmPatchTuesday -Next
        $PPT = Get-PRTGSccmPatchTuesday
        Write-Verbose "$TimeStamp : LOG   : Collected next     patchtuesday: $NPT"
        Write-Verbose "$TimeStamp : LOG   : Collected previous patchtuesday: $PPT"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect patchtuesday."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect patchtuesday."
        $Boolean_Exit   = $True
    }
}

##First, lets see where we are compared to PPT, NWM
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
        $CheckDate = Get-Date -Hour 3 -Minute 0 -Second 0 -Millisecond 0
        Write-Verbose     "$TimeStamp : LOG   : Using checkdate $CheckDate."
        ##Checking for situation 1: PatchTuesday is today
        If ($CheckDate -eq $PPT) {
            $Configuration.prtg.error = '0'
            $Output_Message = "PatchTuesday !! Next MaintenanceWindow $($MWindow_object.StartTime)."
            Write-Verbose     "$TimeStamp : LOG   : Detected patchtuesday. No errorstatus possible."
            Write-Verbose     "$TimeStamp : OUT 0 : PatchTuesday !! Next MaintenanceWindow $($MWindow_object.StartTime)."
        ##Checking for situation 2: NextMaintenanceWindow is today
        } ElseIf ($CheckDate -eq $NMW) {
            Write-Verbose     "$TimeStamp : LOG   : Detected maintenancewindow."
            If ($CheckDate -eq $LRT) {
                $Configuration.prtg.error = '0'
                $Output_Message = "MaintenanceWindow !! This server has rebooted $LastRebootTime."
                Write-Verbose     "$TimeStamp : LOG   : Detected maintenancewindow and server has rebooted. No error."
                Write-Verbose     "$TimeStamp : OUT 0 : MaintenanceWindow !! This server has rebooted $LastRebootTime."
                } Else {
                $Configuration.prtg.error = '0'
                $Output_Message = "MaintenanceWindow !! This server has not yet rebooted. Deadline $($MWindow_object.EndTime)"
                Write-Verbose     "$TimeStamp : LOG   : Detected maintenancewindow and server has not yet rebooted. Warning."
                Write-Verbose     "$TimeStamp : OUT 1 : MaintenanceWindow !! This server has not yet rebooted. Deadline $($MWindow_object.EndTime)"
            }
        ##Checking for situation 3: NextMaintenanceWindow is later than patchtuesday, so we are waiting for patchtuesday. Reboot could not have occured.
        } ElseIf ($NMW -gt $NPT) {
            Write-Verbose     "$TimeStamp : LOG   : Waiting for patchtuesday. Error is possible."
            If ($LRT -gt $PPT) {
                $Configuration.prtg.error = '0'
                $Output_Message = "MaintenanceWindow $($MWindow_object.StartTime) / Patchtuesday $NPT / Last reboot $LastRebootTime."
                Write-Verbose     "$TimeStamp : LOG   : Last reboot was after Previous Patch Tuesday. No error."
                Write-Verbose     "$TimeStamp : OUT 0 : MaintenanceWindow $($MWindow_object.StartTime) / Patchtuesday $NPT / Last reboot $LastRebootTime."
            } Else {
                ## So last reboot was before previous patchtuesday, and we are waiting for a new patchtuesday? Sounds like we mist a window. ERROR.
                $Configuration.prtg.error = '2'
                $Output_Message = "Last reboot too long ago: $LastRebootTime."
                Write-Verbose     "$TimeStamp : ERROR : Last reboot was after Previous Patch Tuesday."
                Write-Verbose     "$TimeStamp : OUT 2 : Last reboot too long ago: $LastRebootTime."
            }
        ##Checking for situation 4: NextMaintenanceWindow is sooner than patchtuesday, so we are waiting for a maintenancewindow
        } ElseIf ($NMW -lt $NPT) {
            $Configuration.prtg.error = '0'
            $Output_Message = "MaintenanceWindow $($MWindow_object.StartTime) / Patchtuesday $NPT / Last reboot $LastRebootTime."
            Write-Verbose     "$TimeStamp : LOG   : Waiting for maintenancewindow. No error."
            Write-Verbose     "$TimeStamp : OUT 0 : MaintenanceWindow $($MWindow_object.StartTime) / Patchtuesday $NPT / Last reboot $LastRebootTime."
        }
        If ($Boolean_override -eq $True) {
            $Configuration.prtg.error = '0'
            $Output_Message+= " (OVERRIDE)"
            Write-Verbose     "$TimeStamp : LOG   : Override-switch given, sensor will not show error."
            Write-Verbose     "$TimeStamp : OUT 0 : MaintenanceWindow $($MWindow_object.StartTime) / Patchtuesday $NPT / Last reboot $LastRebootTime."
        }
} Else {
        $Configuration.prtg.error = '2'
        Write-Verbose     "$TimeStamp : LOG   : Errorstatus detected."
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml
##Script end