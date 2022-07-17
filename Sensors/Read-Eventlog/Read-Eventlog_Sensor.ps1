<#
.SYNOPSIS
PRTG-Sensor for reading Eventlogs.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will read the eventlog on a remote
computer. If events listed in the configuration-file are found within given timeframe, 
it will alert.

The script can be configured to check for multiple events. It will generate one alert-
line; the first one occurring. So place more important events higher on the list 
within the XML.

This sensor uses an Invoke-Command, and is not ment to query the local server the probe
is running on. 

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER Computer
Mandatory parameter for defing the computer to read the eventlog from.

.PARAMETER Username
Optional parameter for defining the username of the account to be used, if server is not
in the same domain as the PRTG Probe

.PARAMETER Password
Optional parameter for defining the password of this username. Can be used with the 
%windowspassword PRTG parameter.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       read-eventlog_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\read-eventlog_ChannelConfiguration.xml" -Computer "plugge-fs01.plugge-d.local" '
- Enviroment:       personal preference
- Security context: personal preference
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much.

Script can be run locally for test-purposes via
.\Read-Eventlog_sensor.ps1 -Filename "\\Server.domain.local\share\folder\read-eventlog_ChannelConfiguration.xml" -Computer "plugge-fs01.plugge-d.local"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 03.08.2020: Initial upload 
Version 1.2 / 14.11.2021: Moved functions to PRTG Module
Version 2.1 / 10.07.2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$true,Position=1)][String]$Filename,
        [Parameter(Mandatory=$true,Position=2)][String]$Computer,
        [Parameter(Mandatory=$false,Position=3)][String]$Username,
        [Parameter(Mandatory=$false,Position=4)][String]$Password
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Skip    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[Boolean]  $Boolean_Cred    = $False

[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null
[PSObject] $Events_Object   = $null

Write-Verbose     "SENSOR:$Command"
Write-Verbose     "---------------------"
Write-Verbose     "$Timestamp : LOG   : Username: $env:username"
Write-Verbose     "$Timestamp : LOG   : Computer: $LocalComputer"
Write-Verbose     "$Timestamp : LOG   : Session : $( ([System.IntPtr]::Size)*8 )bit Session"

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

## Checking if Creds are given
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Username -eq "") -or ($Username -eq $null) ) {
        Write-Verbose   "$TimeStamp : LOG   : Using context creds."
        $Boolean_Cred = $False
} Else {
    Try {
        Write-Verbose   "$TimeStamp : LOG   : Creds provided, building credential object"
        $SecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $Credential   = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecureString
        $Boolean_Cred = $True
        Write-Verbose   "$Timestamp : LOG   : Credentialobject build on username $Username."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not build credential object."
        $Boolean_Exit = $True 
    }
}
$Username = $null
$Password = $null

## Importing configuration-files
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose    "$Timestamp : LOG   : Imported Channel configuration from XML."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not import configuration from XML."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not build credential object."
        $Boolean_Exit  = $True
    }
}

## Looping through channels to collect eventID's
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Looping through ChannelConfiguration."
    Foreach ($Channel in $($Configuration.prtg.result)) {
        [Boolean]   $Boolean_Skip   = $False
        [PSObject]  $Events_Object  = $null
        [Hashtable] $Eventlog_splat = @{}

        Write-Verbose "$TimeStamp : LOG   : Using channel $($Channel.Channel)."

        ## Creating splat for collecting events for remote computer
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $False) {
            Try {
                $Eventlog_splat = @{
                    "Session"    = [PSObject] $RemoteSession
                    "Eventlog"   = [String]   $Channel.config.eventlog.eventlog
                    "Source"     = [String]   $Channel.config.eventlog.source
                    "EventID"    = [Int]      $Channel.config.eventlog.eventid
                    "TimeFrame"  = [String]   $((Get-date).AddMinutes(-1 * $( [timespan]::parse( $($Channel.config.timeframe) ).totalMinutes)) ).toString('yyyy-MM-ddThh:mm:ss.000Z')
                    "Computer"   = [String]   $Computer
                }
                Write-Verbose   "$TimeStamp : LOG   : Created splat for passing to Query-function."
                If ($Boolean_Cred -eq $True) { 
                    $Eventlog_splat.add("Credential", $Credential)
                    Write-Verbose "$TimeStamp : LOG   : Passing credentials in splat."
                }
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not build splat to pass to remote computer."
                Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
                $Output_Message = "Could not build splat to pass to remote computer."
                $Boolean_Skip = $True
            }
        }

        ##collecting events from remote computer
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $False) {
            Try {
                $Events_Object = Get-PRTGClientEventlog @Eventlog_splat
                Write-Verbose    "$TimeStamp : LOG   : Collected $($Events_Object.Count) events from computer $Computer."
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not collect events for channel $($Channel.Channel)."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Output_Message = "Could not collect events for channel $($Channel.Channel)."
                $Boolean_Skip  = $True
            }
        }

        ##Writing value to PRTG-Channel
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( $Boolean_Skip -eq $False ) {
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($Channel.Channel)  -Value $($Events_Object.Count)
                Write-Verbose    "$Timestamp : LOG   : Written value $($Channel.Channel) to Channel $($Events_Object.Count)."
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not write to channel $($Channel.Channel)."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Output_Message = "Could not collect events for channel $($Channel.Channel)."
                $Boolean_Skip  = $True
            }
        }

        ##Determining WarningStatus
        [String] $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( 
            $($Channel.LimitMaxWarning) -and    
            ( $Boolean_Skip    -eq $False ) -and 
            ( $Boolean_Warning -eq $False ) -and 
            ( $Boolean_Error   -eq $False ) -and
            ( $($Events_Object.Count) -gt $($Channel.LimitMaxWarning) ) 
        ) {
            $Boolean_Warning = $True
            Write-verbose      "$Timestamp : LOG   : Detected WARNING for channel $($channel.channel)."
            $Output_Message  = $($Channel.config.warningmessage)
        }
                        
        ##Determining ERRORStatus
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( 
            $($Channel.LimitMaxError) -and
            ( $Boolean_Skip  -eq $False ) -and 
            ( $Boolean_Error -eq $False ) -and
            ( $($Events_Object.Count) -gt $($Channel.LimitMaxError) )
        ) {
            $Boolean_Error   = $True
            Write-verbose      "$Timestamp : LOG   : Detected ERROR in channel $($Channel.Channel)."
            $Output_Message  = $($Channel.config.Errormessage)
        }

        If ($Boolean_Skip -eq $True) { $Boolean_Exit -eq $True }
    }
}        

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml