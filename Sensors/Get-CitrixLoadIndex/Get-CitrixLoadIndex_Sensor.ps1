<#
.SYNOPSIS
PRTG-Sensor for reading the Citrix Load Index for a DeliveryGroup.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect to the oData service of 
the Citrix Studio / Delivery Controller, and collect the data for the Citrix LoadIndex.

The loadindex is a number between 0 and 10.000, which helps Citrix decide on what server a user
logging in has to land. It is determind on basis of
- Number of users logged in
- CPU usage
- Ram usage
- Disk i/o
(or a subset of these)

This sensor reads the LoadIndex which is refreshed every hour on the citrix deliverycontroller's
datafeed. It writes the value to each channel for each server

An average is written to a total channel.

If a server is in maintenancemode, it is not calculated.

If servers diverge more than 1000 (default value) from the average, sensor will show warning. If it 
diverges more than 2000 (default value), it will post error, since loadbalancing is apperantly not 
functioning.

If a server is in the deliverygroup (and no other errors occur), a warningmessage is posted.

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

.PARAMETER WarningValue
Optional parameter for defining the warningvalue of servers diverging from the average. Can be between 1 an 10.000. Default is 1000. 
Set to 0 to NOT post warnings.

.PARAMETER ErrorValue
Optional parameter for defining the errorvalue of servers diverging from the average. Can be between 1 an 10.000. Default is 1000. 
Set to 0 to NOT post warnings.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-CitrixLoadIndex_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\Get-CitrixLoadIndex_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup "Desktop_with_Office" -Username "sa_prtg@test.local" -Password "Welkom123" '
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
.\Get-CitrixLoadIndex_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-CitrixLoadIndex_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup "Desktop_with_Office" -Username "sa_prtg@test.local" -Password "Welkom123"

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
        [Parameter(Mandatory=$false)][Int] $Warningvalue = 1000,
        [Parameter(Mandatory=$false)][Int] $Errorvalue = 2000
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Skip    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False

[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $Outmsg_warn     = $null
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null
[String]   $GroupID         = $null
[Array]    $Array_VM        = @()
[int]      $ChannelValue    = 0

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

## Looping through the VM's to collect LoadIndex
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Looping through VMArray."
    Foreach ($VM in $Array_VM) {
        [Boolean]   $Boolean_Skip   = $False
        [int]       $ChannelValue   = 0
        If ($VM.HostedMachineName) {
            Write-Verbose "$TimeStamp : LOG   : Using VM $($VM.HostedMachineName)."
        } else {
            Write-Verbose "$TimeStamp : LOG   : No HostedMachineName found, skipping.."
            $Boolean_skip = $true
        }

        ## Checking if server is unregistered
        If ( ($vm.IsRegistered -eq $true) -and ($Boolean_skip -eq $false) ) {
            Write-Verbose "$TimeStamp : LOG   : Server $($VM.Name) is unRegistered"
            if ($Boolean_info -eq $false) {
                Write-Verbose "$TimeStamp : LOG   : Set warningmessage"
                $Outmsg_warn = "Found server $($VM.Name) unRegistered."
                $Boolean_info = $true
            }
            $Boolean_Skip = $true
        } elseif ($Boolean_Skip -eq $false) {
            Write-Verbose "$TimeStamp : LOG   : Server $($VM.Name) is Registered"
        }

        ## Checking if server is in Maintenancemode
        If ( ($vm.IsInMaintenanceMode -eq $true) -and ($Boolean_skip -eq $false) ) {
            Write-Verbose "$TimeStamp : LOG   : Server $($VM.Name) is in MaintenanceMode"
            if ($Boolean_info -eq $false) {
                Write-Verbose "$TimeStamp : LOG   : Set warningmessage"
                $Outmsg_warn = "Found server $($VM.Name) in maintenanceMode."
                $Boolean_info = $true
            }
            $Boolean_Skip = $true
        } elseif ($Boolean_Skip -eq $false) {
            Write-Verbose "$TimeStamp : LOG   : Server $($VM.Name) is not in maintenanceMode"
        }

        ## Collecting LoadIndex
        If ($Boolean_Skip -eq $false) {
            Try {
                $LoadIndexObj = Get-PRTGCTXVMLoadIndex -Server $DeliveryController -Credential $Credential -MachineID ($VM.ID)
                If (!($LoadIndexObj)) {
                    Write-Verbose "$Timestamp : LOG   : Could not collect LoadIndex for server $($VM.HostedMachineName), skipping"
                    $Boolean_Skip = $true
                } Else {
                    $ChannelValue = $LoadIndexObj.SumLoadIndex
                    Write-Verbose "$TimeStamp : LOG   : Loadindex $($VM.Name) is $ChannelValue"
                }
            } Catch {
                Write-Error "$Timestamp : ERROR : Error collecting LoadIndex from VM $($VM.Name)"
                Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
                $Output_Message = "Error collecting LoadIndex from VM $($VM.Name)"
                $Boolean_Exit  = $True   
                $Boolean_Skip = $true             
            }
        }

        ## Collect matching channel from ChannelConfig
        $Channel = $ChannelConfiguration | Where-Object -FilterScript { $_.channel -eq $($VM.HostedMachineName) }
        If ( ($Channel) -and ($Boolean_Skip -eq $false) ) {
            Write-Verbose "$TimeStamp : LOG   : Collected matching channelObj; writing to PRTG"
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($VM.HostedMachineName) -Value $ChannelValue
            Write-Verbose "$Timestamp : LOG   : Writing resultcount $ChannelValue to Channel $($VM.HostedMachineName)."
        } ElseIf ($Boolean_Skip -eq $false) {
            Write-Verbose "$TimeStamp : LOG   : Found unknown server $($VM.Name)"
            if ($Boolean_info -eq $false) {
                Write-Verbose "$TimeStamp : LOG   : Set warningmessage"
                $Outmsg_warn = "Found server $($VM.Name), plz add to channelConfiguration"
                $Boolean_info = $true
            }
            $Boolean_Skip = $true
        }

        ##Adding to average
        If ($Boolean_Skip -eq $false) {
            $Avg_Count++
            $Avg_value = $Avg_value + $ChannelValue
            Write-Verbose "$TimeStamp : LOG   : Set count to $Avg_count, value is $Avg_Value"
        }

        ##Determining WarningStatus
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ( 
            $($Channel.LimitMaxWarning) -and    
            ( $Boolean_Skip    -eq $False ) -and 
            ( $Boolean_Warning -eq $False ) -and 
            ( $Boolean_Error   -eq $False ) -and
            ( $($Events_Object.Count) -gt $($Channel.LimitMaxWarning) ) 
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
            ( $($Events_Object.Count) -gt $($Channel.LimitMaxError) )
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
    If ($Avg_Count -gt 0) { $Avg_Return = $Avg_value / $Avg_Count } Else { $Avg_Return = 0 }
    $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Average' -Value $Avg_Return
}

##Setting infomessage is Error nor Warning
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_error -eq $false) -and ($Boolean_Warning -eq $fase) -and ($Boolean_info -eq $true) ) {
        $Output_Message = $Outmsg_warn
        Write-Verbose "$TimeStamp : LOG   : setting infomessage $Outmsg_warn"
} elseif ( ($Boolean_error -eq $false) -and ($Boolean_Warning -eq $false) -and ($Boolean_info -eq $true) ) {
    $Output_Message = "Average loadIndex: $Avg_Return over $Avg_Count servers."
    Write-Verbose "$TimeStamp : LOG   : setting infomessage $Output_Message"
}

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml