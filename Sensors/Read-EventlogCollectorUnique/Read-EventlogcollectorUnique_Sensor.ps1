<#
.SYNOPSIS
PRTG-Sensor for reading Eventlogs.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will read the eventlog on a remote
Eventlog Collector server. The number of events found with the query in the configuration-file are 
written in each channel. Warning- and Errorvalues can be given with the 
<LimitMaxWarning> and <LimitMaxError> tags in the XML.

This sensor will not return the number of certain events in the Forwarded Events eventlog. Instead, it will
return the number of specific computers where an event has taken place. (this is the difference between this
sensor and the Read-EventlogCollector_sensor)

The script can be configured to check for multiple events, each in their own channel, 
It will generate one alert-line; the first one occurring. 

So place more important events higher on the list within the XML.

This sensor uses an Invoke-Command, and is not ment to query the local server the probe
is running on. Credentials for a server in a remote domain can be give.

.PARAMETER Filename
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER Server
Mandatory parameter for defing the computer to read the eventlog from.

.PARAMETER Username
Optional parameter, for defining the name of the useraccount to use for connecting. Can be used if the server
is in another domain as the probeserver. Expects a string in a domain\accountname format.

.PARAMETER Password
Optional parameter, for defining the password of the useraccount to use for connecting. Can be used if the server
is in another domain as the probeserver. Expects a string value, ment to be used with %windowspassword (PRTG variable).

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       read-eventlogcollectorUnique_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\read-eventlogcollectorUnique_ChannelConfiguration.xml" -Computer "plugge-fs01.plugge-d.local" '
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
.\Read-EventlogcollectorUnique_sensor.ps1 -Filename "\\Server.domain.local\share\folder\read-eventlogcollectorUnique_ChannelConfiguration.xml" -Computer "plugge-fs01.plugge-d.local"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 25.11.2018: Initial upload 
Version 1.2 / 14.11.2021: Moved functions to PRTG Module
Version 2.1 / 10.07.2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Server,
        [Parameter(Mandatory=$True ,Position=3)] [String]  $Filename,
        [Parameter(Mandatory=$False,Position=4)] [String]  $Username = $null,
        [Parameter(Mandatory=$False,Position=5)] [String]  $Password = $null
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Skip    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $Channelname     = $null
[String]   $Query           = $null
[String]   $Eventlog        = $null
[Int]      $WarningValue    = 0
[Int]      $ErrorValue      = 0
[Int]      $ReturnValue     = 0

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
$Username     = $null
$Password     = $null
$SecureString = $null

## Importing configuration-file
[String] $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration          = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $ChannelConfiguration   = $Configuration.prtg.result
        Write-Verbose             "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

## Looping through channels
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Looping through ChannelConfiguration."
    Foreach ($Channel in $ChannelConfiguration) {
        [String]  $Channelname  = $null
        [String]  $Query        = $null
        [String]  $Eventlog     = $null
        [Int]     $WarningValue = 0
        [Int]     $ErrorValue   = 0
        [Int]     $ReturnValue  = 0
        [Boolean] $Boolean_Skip = $False

        ##Collecting variables
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        Try {
            $Channelname  = $Channel.Channel
            $Query        = $Channel.Custom.Query
            $Eventlog     = $Channel.Custom.Eventlog
            $WarningValue = $Channel.LimitMaxWarning
            $ErrorValue   = $Channel.LimitMaxError
            Write-Verbose   "$Timestamp : LOG   : Collected values from XML Channelconfiguration."
            Write-Verbose   "$Timestamp : LOG   : Channelname : $ChannelName"
            Write-Verbose   "$Timestamp : LOG   : Query       : $Query"
            Write-Verbose   "$Timestamp : LOG   : Eventlog    : $Eventlog"
            Write-Verbose   "$Timestamp : LOG   : LimitMaxWarning : $LimitMaxWarning"
            Write-Verbose   "$Timestamp : LOG   : LimitMaxError   : $LimitMaxError"
        } Catch {
            $Boolean_Skip = $True
            $Boolean_Exit = $True
            Write-Error     "$Timestamp : ERROR : Could not collect values from XML."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect values from XML."
        }


        ##Query remote computer
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $False) {
            If ($Boolean_Cred -eq $False) {
                Try {
                    $EventObj = Get-PRTGClientEventlog -Computer $Server -Query $Query -Eventlog $Eventlog
                    $ReturnValue = ($EventObj.Events | Select-Object -Unique -Property MachineName).Count
                    Write-Verbose "$Timestamp : LOG   : Queried remote eventlog. (Return: $ReturnValue)"
                } Catch {
                    Write-Error     "$TimeStamp : ERROR : Could not Query remote eventlog."
                    Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $Output_Message = "Could not Query remote eventlog."
                    $Boolean_Skip = $True
                    $Boolean_Exit = $True
                }
            } Else {
                Try {
                    $EventObj = Get-PRTGClientEventlog -Computer $Server -Query $Query -Eventlog $Eventlog -Credential $Credential
                    $ReturnValue = ($EventObj.Events | Select-Object -Unique -Property MachineName).Count
                    Write-Verbose "$Timestamp : LOG   : Queried remote eventlog w\ cred. (Return: $ReturnValue)"
                } Catch {
                    Write-Error     "$TimeStamp : ERROR : Could not Query remote eventlog w\ cred."
                    Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $Output_Message = "Could not Query remote eventlog w\ cred."
                    $Boolean_Skip = $True
                    $Boolean_Exit = $True
                }
            }
        }

        ##Writing to PRTG
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $False) {
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Channelname -Value $ReturnValue
                Write-Verbose    "$Timestamp : LOG   : Written result $ReturnValue to PRTG XML for Channel $Channelname"
            } Catch {
                Write-Error     "$TimeStamp : ERROR : Could not write results to PRTG XML."
                Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Output_Message = "Could not write results to PRTG XML."
                $Boolean_Skip = $True
                $Boolean_Exit = $True
            }
        }

        ##Determining WarningStatus
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Skip    -eq $False) -and ($Boolean_Warning -eq $False) -and ($Boolean_Error   -eq $False) ) {
            If ( ($ReturnValue -gt $WarningValue) -and ($WarningValue -ne 0) ) {
                $Boolean_Warning = $True
                Write-verbose      "$Timestamp : LOG   : Detected WARNING in query."
                $Output_Message  = "Warning : Too many events found ($Returnvalue). Please investigate"
            }
        }
                        
        ##Determining ERRORStatus
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Skip    -eq $False) -and ($Boolean_Error   -eq $False) ) {
            If ( ($ReturnValue -gt $ErrorValue) -and ($ErrorValue -ne 0) ) {
                $Boolean_Warning = $True
                $Boolean_Error   = $True
                Write-verbose      "$Timestamp : LOG   : Detected Error in query."
                $Output_Message  = "ERROR : Too many events found ($Returnvalue). Please investigate"
            }
        }              
    }
}        

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml