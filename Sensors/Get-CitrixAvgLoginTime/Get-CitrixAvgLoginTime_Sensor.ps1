<#
.SYNOPSIS
PRTG-Sensor for reading the average logintime for a DeliveryGroup.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect to the oData service of 
the Citrix Studio / Delivery Controller, and collect the data for the Citrix sessions of
all servers in a DeliveryGroup.

The sensor will calculate average logintime for all sessions active in the last hour. It
will also write the longest login-duration for any usersession in the deliveryGroup.

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER DeliveryController
Mandatory parameter for defining the deliveryController to read from.

.PARAMETER DeliveryGroup
Mandatory parameter for defining the deliveryGroup the servers are member of.

.PARAMETER Username
Mandatory parameter for defining the username of the account to be used.

.PARAMETER Password
Mandatory parameter for defining the password of this username.

.PARAMETER Interval
Optional parameter for defining the interval (hours) to check for; by default sensor will read all sessions in the last 1 hour. 
So default value is 1.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-CitrixAvgLoginTime_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\Get-CitrixAvgLoginTime_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup "Desktop_with_Office" -Username "sa_prtg@test.local" -Password "Welkom123" '
- Enviroment:       personal preference
- Security context: personal preference
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. Since default interval is 1h, it makes sense to set it to 1 hour.

Script can be run locally for test-purposes via
.\Get-CitrixAvgLoginTime_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-CitrixAvgLoginTime_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup "Desktop_with_Office" -Username "sa_prtg@test.local" -Password "Welkom123"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 23.07.2022: Initial upload 

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$true,Position=1)][String]$Filename,
        [Parameter(Mandatory=$true,Position=2)][String]$DeliveryController,
        [Parameter(Mandatory=$true,Position=2)][String]$DeliveryGroup,
        [Parameter(Mandatory=$false)][String]$Username,
        [Parameter(Mandatory=$false)][String]$Password,
        [Parameter(Mandatory=$false)][int] $Interval = 1
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Skip    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[Boolean]  $Boolean_Info    = $False

[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = $null
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null

[String]   $GroupID = $null
[PSObject] $Channel = $null
[int]    $TotalSessions  = 0
[int]    $Avg_duration   = 0
[int]    $TotalDuration  = 0
[int]    $ServerDuration = 0
[Array]    $DurationArray  = @()

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

## Building credentialObject
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try {
        Write-Verbose   "$TimeStamp : LOG   : Creds provided, building credential object"
        $SecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $Credential   = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecureString
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
        $ChannelConfiguration = $Configuration.prtg.result
        Write-Verbose    "$Timestamp : LOG   : Imported Channel configuration from XML."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not import configuration from XML."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not build credential object."
        $Boolean_Exit  = $True
    }
}

## Collecting desktopGroup ID
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $GroupID = (Get-PRTGCTXDeliveryGroupID -Server $DeliveryController -Credential $Credential -GroupName $DeliveryGroup).Id
        Write-Verbose    "$Timestamp : LOG   : Collected GroupID $GroupID."
        If (!($GroupID)) {
            Write-Error "$Timestamp : ERROR : Could not find matching GroupID."
            $Output_Message = "Could not find matching GroupID"
            $Boolean_Exit = $true
        }
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting GroupID from $DeliveryGroup."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting GroupID from $DeliveryGroup."
        $Boolean_Exit  = $True
    }
}

## Collecting VM's in DesktopGroup
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Array_VM = Get-PRTGCTXVMinDeliveryGroup -Server $DeliveryController -Credential $Credential -GroupID $GroupID
        Write-Verbose    "$Timestamp : LOG   : Collected all VM's in deliveryGroup ($($Array_VM.Count) VM's)."
        If ($($Array_VM.Count) -eq 0) {
            Write-Error "$Timestamp : ERROR : No VM's found in deliveryGroup $DeliveryGroup."
            $Output_Message = "No VM's found in deliveryGroup $DeliveryGroup."
            $Boolean_Exit = $true
        }
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting VM's from $DeliveryGroup."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting VM's from $DeliveryGroup."
        $Boolean_Exit  = $True
    }
}

## Looping through the VM's to collect LoginTime
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Looping through VMArray."
    Foreach ($VM in $Array_VM) {
        [Boolean] $Boolean_Skip   = $False
        [int]   $Avg_duration   = 0
        [int]   $ServerDuration = 0

        [Array] $DurationArray = @()
        If ($VM.HostedMachineName) {
            Write-Verbose "$TimeStamp : LOG   : Using VM $($VM.HostedMachineName)."
        } else {
            Write-Verbose "$TimeStamp : LOG   : No HostedMachineName found, skipping.."
            $Boolean_skip -eq $true
        }

        ## Collecting LogonDuration
        If ($Boolean_Skip -eq $false) {
            Try {
                $DurationArray = Get-PRTGCTXLogonDuration -Server $DeliveryController -Credential $Credential -CitrixServerID $($VM.Id) -TimeSpan $Interval | Sort-Object -Property LogonDuration
                Write-Verbose "$TimeStamp : LOG   : Collected logonDuration for sessions on server $($VM.HostedMachineName) ($($DurationArray.Count))"
                $TotalSessions += $($DurationArray.Count)
                Foreach ($Item in $DurationArray.LogOnDuration) { 
                    $ServerDuration += $Item
                    If ($Item -gt $MaxDuration) {
                        $MaxDuration = $Item
                        $MaxDurationVM = $($VM.HostedMachineName)
                        Write-Verbose "$TimeStamp : LOG   : Set max session to $MaxDuration on VM $MaxDurationVM"
                    }
                }
                $TotalDuration += $ServerDuration
                $Avg_duration = $(If ($DurationArray.Count -gt 0) { ($ServerDuration / $($DurationArray.count))/1000 } Else { 0 })
                Write-Verbose "$TimeStamp : LOG   : Setting avg duration to $avg_duration"
            } Catch {
                Write-Error "$Timestamp : ERROR : Error collecting logonDuration for sessions on VM $($VM.HostedMachineName)."
                Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
                $Output_Message  = "Error collecting logonDuration for sessions on VM $($VM.HostedMachineName)."
                $Boolean_Info    = $True
                $Boolean_Skip    = $True
                $Boolean_Error   = $true
                $Boolean_Warning = $true
            }
        }

        ## Writing to channel
        If ($Boolean_skip -eq $false) {
            [PSObject] $Channel = $null
            $Channel = $ChannelConfiguration | Where-Object -FilterScript { $_.channel -eq $($VM.HostedMachineName) }
            If ($Channel) {
                Write-Verbose "$TimeStamp : LOG   : Collected matching channelObj; writing to PRTG"
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($VM.HostedMachineName) -Value $Avg_duration
                Write-Verbose "$Timestamp : LOG   : Writing resultcount  $Avg_duration to Channel $($VM.HostedMachineName)."
            } ElseIf ($VM.HostedMachineName) {
                Write-Verbose "$TimeStamp : LOG   : Found unknown server $($VM.HostedMachineName)"
                $Output_Message = "Found unknown server $($VM.HostedMachineName), please add to channelConfiguration"
                $Boolean_Info = $true
                $Boolean_Skip = $true
            }
        }

        ##Determining WarningStatus
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ( 
            $($Channel.LimitMaxWarning) -and    
            ( $Boolean_Skip    -eq $False ) -and 
            ( $Boolean_Warning -eq $False ) -and 
            ( $Boolean_Error   -eq $False ) -and
            ( $Avg_duration    -gt $($Channel.LimitMaxWarning) ) 
        ) {
            $Boolean_Warning = $True
            Write-verbose      "$Timestamp : LOG   : Detected WARNING for channel $($channel.channel)."
            $Output_Message  = $($VM.Name + ': ' + $Channel.config.warningmessage)
        }

        ##Determining ERRORStatus
        [String]  $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ( 
            $($Channel.LimitMaxError) -and
            ( $Boolean_Skip  -eq $False ) -and 
            ( $Boolean_Error -eq $False ) -and
            ( $Avg_duration  -gt $($Channel.LimitMaxError) )
        ) {
            $Boolean_Error   = $True
            Write-verbose      "$Timestamp : LOG   : Detected ERROR in channel $($Channel.Channel)."
            $Output_Message  = $($VM.Name + ': ' + $Channel.config.Errormessage)
        }        
    }
}

##Calculating Average value
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($TotalSessions -gt 0) { $Avg_Return = ($TotalDuration / $TotalSessions)/1000 } Else { $Avg_Return = 0 }
    $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Average LoginDuration' -Value $Avg_Return
    $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Total no of sessions' -Value $TotalSessions
    Write-verbose      "$Timestamp : LOG   : Writing $Avg_return to channel 'Average LoginDuration'."
}

##Setting infomessage is Error nor Warning
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_error -eq $false) -and ($Boolean_Warning -eq $false) -and ($Boolean_info -eq $false) ) {
        $Output_Message = "Longest login: $($MaxDuration/1000) sec on server $MaxDurationVM"
        Write-Verbose "$TimeStamp : LOG   : Setting infomessage $Output_message"
}

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml