<#
.SYNOPSIS
PRTG-Sensor for reading ScheduledTaskResults.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will create a CimSession to a 
remote computer, and collect the last result for the scheduled tasks listed in 
the channelconfiguration. It will compaire these results to a json-file listing
returncodes and the weight of these codes (Informational: 0, Warning: 1, Error: 2).
These will be returned to PRTG.

The script can be configured to check for multiple scheduled tasks on a server, 
each in their own channel, it will generate one alert-line; the first one occurring. 

So place more important events higher on the list within the XML.

This sensor uses an CimSession, and is not ment to query the local server the probe
is running on. Credentials for a server in a remote domain can be give.

.PARAMETER Filename
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER Server
Mandatory parameter for defing the computer to read the eventlog from.

.PARAMETER ErrorCode
Optional parameter for defing the path of the jsonfile containing errorcodes. Default
value is '.\Read-ScheduledTaskResult_Errorcodes.json'.

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
- EXE/Script:       Read-ScheduledTaskResult_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\read-scheduledTaskResult_ChannelConfiguration.xml" -Server "plugge-fs01.plugge-d.local" '
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
.\Read-ScheduledTaskResult_sensor.ps1 -Filename "\\Server.domain.local\share\folder\read-scheduledTaskResult_ChannelConfiguration.xml" -Server "plugge-fs01.plugge-d.local"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 09.06.2019: Initial upload 
Version 1.2 / 14.11.2021: Moved functions to PRTG Module
Version 2.1 / 10.07.2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Server,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $Filename,
        [Parameter(Mandatory=$False,Position=3)] [String]  $ErrorCodes = 'C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\Read-ScheduledTaskResult_Errorcodes.json',
        [Parameter(Mandatory=$False,Position=4)] [String]  $Username = $null,
        [Parameter(Mandatory=$False,Position=5)] [String]  $Password = $null
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[Boolean]  $Boolean_Unknown = $False
[Boolean]  $Boolean_Cred    = $False

[PSObject] $ErrorCodes_Object    = $null
[PSObject] $ChannelConfiguration = $null
[CimSession] $Session = $null

[Array]    $PropertyArray   = @()
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $Channelname     = $null
[String]   $JsonMessage     = $null
[Int]      $JsonWeight      = 0
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
        $ErrorCodes_Object      = (Import-PRTGConfigFile -FilePath $ErrorCodes -FileType 'Json').Configuration.Errorcodes
        Write-Verbose             "$Timestamp : LOG   : Imported errorobjects."
        $PropertyArray          = $ErrorCodes_Object | Get-member -MemberType NoteProperty |  Where-Object -FilterScript {$_.Name -like "Code_*"}
        Write-Verbose             "$Timestamp : LOG   : Collected properties from errorobject ($($PropertyArray.Count))."
        $Configuration          = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $ChannelConfiguration   = $Configuration.prtg.result
        Write-Verbose             "$Timestamp : LOG   : Imported channelconfiguration."
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

##Build session to remote computer
[String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $False) {
        Try {
            $Session      = New-CimSession -ComputerName $Server -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            Write-Verbose   "$Timestamp : LOG   : Set up session to remote computer to query scheduled tasks."
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not set up session to remote computer."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from XML."
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Session = New-CimSession -ComputerName $Server -Credential $Credential -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            Write-Verbose "$Timestamp : LOG   : Set up session to remote computer to query scheduled tasks w\ cred."
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not set up session to remote computer w\ cred."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not set up session to remote computer w\ cred."
            $Boolean_Exit = $True
        }
    }
    If ($null -eq $Session) {
        Write-Error "$TimeStamp : ERROR : PSSession not verified. Stopping.."
        $Output_Message = "PSSession not verified. Stopping.."
        $Boolean_Exit = $True  
    }
}

## Looping through channels
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Looping through ChannelConfiguration."
    Foreach ($Channel in $ChannelConfiguration) {
        [String]  $Channelname  = $Channel.Channel
        [String]  $JsonMessage  = $null
        [Int]     $JsonWeight   = 0
        [Int]     $LastResult   = 0
        [Boolean] $Boolean_Unknown = $True

        ##Querying the remote server for the Scheduled Task
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) {
            Try {
                $LastResult   = (Get-ScheduledTask -CimSession $Session -TaskName $Channelname | Get-ScheduledTaskInfo).LastTaskResult
                Write-Verbose   "$Timestamp : LOG   : Collected last result of task ($LastResult)."
            } Catch {
                Write-Error "$TimeStamp : ERROR : Could not collect last result for task."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Output_Message = "Could not collect last result for task."
                $Boolean_Exit = $True
            }
        }

        ##Checking if in Errorcodes-object
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) {
            [Int] $Count = 0
            ForEach ($Item in $PropertyArray) {
                $Setting = "Code_" + "{0:D2}" -f $Count
                Write-Verbose "$Timestamp : LOG   : Using Setting $Setting."
                Write-Verbose "$TimeStamp : LOG   : Code_Hex : $($ErrorCodes_Object.$Setting.Code_Hex)"
                Write-Verbose "$TimeStamp : LOG   : Code_Dec : $($ErrorCodes_Object.$Setting.Code_Dec)"
                Write-Verbose "$TimeStamp : LOG   : Weight   : $($ErrorCodes_Object.$Setting.Weight)"
                Write-Verbose "$TimeStamp : LOG   : Message  : $($ErrorCodes_Object.$Setting.Message)"
                If ($($ErrorCodes_Object.$Setting.Code_Dec) -eq $LastResult) {
                    Write-Verbose   "$Timestamp : LOG   : Found matching  ($LastResult  = $($ErrorCodes_Object.$Setting.Code_Dec))."
                    
                    $JsonMessage     = $($ErrorCodes_Object.$Setting.Message) + " (" + $($ErrorCodes_Object.$Setting.Code_Hex) + ")"
                    $JsonWeight      = $($ErrorCodes_Object.$Setting.Weight)
                    $Boolean_Unknown = $False

                    ##Writing to PRTG
                    [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
                    If ($Boolean_Exit -eq $False) {
                        Try {
                            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Channelname -Value $JsonWeight
                            Write-Verbose    "$Timestamp : LOG   : Written result $JsonWeight to PRTG XML for Channel $Channelname"
                        } Catch {
                            Write-Error "$TimeStamp : ERROR : Could not write results to PRTG XML."
                            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                            $Output_Message = "Could not write results to PRTG XML."
                            $Boolean_Exit = $True
                        }
                    }

                    ##Determining WarningStatus
                    [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
                    If ( 
                        ($Boolean_Exit    -eq $False) -and 
                        ($Boolean_Warning -eq $False) -and 
                        ($Boolean_Error   -eq $False) 
                    ) {
                        If ( ($JsonWeight -gt $WarningValue) -and ($WarningValue -ne 0) ) {
                            $Boolean_Warning = $True
                            Write-verbose      "$Timestamp : LOG   : Detected WARNING in query."
                            $Output_Message  = "Warning : $JsonMessage"
                        }
                    }
                                
                    ##Determining ERRORStatus
                    [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
                    If ( 
                        ($Boolean_Exit    -eq $False) -and 
                        ($Boolean_Error   -eq $False) 
                    ) {
                        If ( ($JsonWeight -gt $ErrorValue) -and ($ErrorValue -ne 0) ) {
                            $Boolean_Warning = $True
                            $Boolean_Error   = $True
                            Write-verbose      "$Timestamp : LOG   : Detected Error in query."
                            $Output_Message  = "ERROR : Too many events found ($Returnvalue). Please investigate."
                        }
                    }
                }
                $Count++
            }
            
            ## Catch unknown errors
            [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
            Write-Verbose   "$Timestamp : LOG   : Finished loop for ErrorCode $LastResult. Checking for unknown result."
            If ( 
                ($Boolean_Exit    -eq $False) -and 
                ($Boolean_Unknown -eq $True) 
            ) {
                Write-verbose      "$Timestamp : LOG   : Detected unknown returncode."
                $Configuration   = Write-PRTGresult -Configuration $Configuration -Channel $Channelname -Value $ErrorValue
                Write-verbose      "$Timestamp : LOG   : Writing ERRORValue $ErrorValue in Channel $Channelname."
                If ($Boolean_Error -eq $False) {
                    $Boolean_Warning = $True
                    $Boolean_Error   = $True
                    $Output_Message  = "ERROR : Unknown returncode detected. Please investigate.($ChannelName : $LastResult)"                
                    Write-verbose      "$Timestamp : LOG   : Setting errorstatus on channel $Channelname."
                }
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