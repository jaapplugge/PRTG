<#
.SYNOPSIS
PRTG-Sensor for reading usersessions for all usersessions in a DeliveryGroup.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect to the oData service of 
the Citrix Studio / Delivery Controller, and collect the data for the Citrix sessions of
all servers in a DeliveryGroup.

The sensor will collect all userssessions of all servers in a deliverygroup, and read their status:
 - Are sessions active?
 - Disconnected, terminated, nonbrokered etc.

With this session, you can track how many users are logged in at the same time, and how
many errors / bad sessions occure. It will list these for the past 24h and the past 1h 
(in seperate channels)

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

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-CitrixDeliveryGroupSessions_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\Get-CitrixDeliveryGroupSessions_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup "Desktop_with_Office" -Username "sa_prtg@test.local" -Password "Welkom123" '
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
.\Get-CitrixDeliveryGroupSessions_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-CitrixDeliveryGroupSessions_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup "Desktop_with_Office" -Username "sa_prtg@test.local" -Password "Welkom123"

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
    [Parameter(Mandatory=$true,Position=3)][String]$DeliveryGroup,
    [Parameter(Mandatory=$false)][String]$Username,
    [Parameter(Mandatory=$false)][String]$Password
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null
[Array]    $SessionObject_day  = @()
[Array]    $SessionObject_hour = @()
[Array]    $Array_VM = @()
[string]   $GroupID  = $null

[Int] $Int_Unknown_1h             = 0
[Int] $Int_Connected_1h           = 0
[Int] $Int_Disconnected_1h        = 0
[Int] $Int_Terminated_1h          = 0
[Int] $Int_PreparingSession_1h    = 0
[Int] $Int_Active_1h              = 0
[Int] $Int_Reconnecting_1h        = 0
[Int] $Int_NonBrokeredSession_1h  = 0
[Int] $Int_Other_1h               = 0
[Int] $Int_Pending_1h             = 0
[Int] $Int_Total_1h               = 0

[Int] $Int_Unknown_24h            = 0
[Int] $Int_Connected_24h          = 0
[Int] $Int_Disconnected_24h       = 0
[Int] $Int_Terminated_24h         = 0
[Int] $Int_PreparingSession_24h   = 0
[Int] $Int_Active_24h             = 0
[Int] $Int_Reconnecting_24h       = 0
[Int] $Int_NonBrokeredSession_24h = 0
[Int] $Int_Other_24h              = 0
[Int] $Int_Pending_24h            = 0
[Int] $Int_Total_24h              = 0

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
$SecureString = $null

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

## Collecting sessionInfo per server
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Foreach ($VM in $Array_VM) {
        Try {
            $SessionObject_day  = @()
            $SessionObject_hour = @()
            $SessionObject_day  = Get-PRTGCTXSessionInfo -Server $DeliveryController -Credential $Credential -CitrixServerID $($VM.Id)
            Write-Verbose    "$Timestamp : LOG   : Collected sessions from Citrixserver $($VM.Name) in the last 24h"
            $SessionObject_hour = Get-PRTGCTXSessionInfo -Server $DeliveryController -Credential $Credential -CitrixServerID $($VM.Id) -TimeSpan 1
            Write-Verbose    "$Timestamp : LOG   : Collected sessions from Citrixserver $($VM.Name) in the last 1h"
            $Int_Unknown_1h             += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 0}).count)
            $Int_Connected_1h           += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 1}).count)
            $Int_Disconnected_1h        += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 2}).count)
            $Int_Terminated_1h          += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 3}).count)
            $Int_PreparingSession_1h    += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 4}).count)
            $Int_Active_1h              += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 5}).count)
            $Int_Reconnecting_1h        += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 6}).count)
            $Int_NonBrokeredSession_1h  += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 7}).count)
            $Int_Other_1h               += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 8}).count)
            $Int_Pending_1h             += $( ($SessionObject_hour | Where-Object -FilterScript {$_.ConnectionState -eq 9}).count)
            $Int_Total_1h               += $($SessionObject_hour.count)
            
            $Int_Unknown_24h            += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 0}).count)
            $Int_Connected_24h          += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 1}).count)
            $Int_Disconnected_24h       += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 2}).count)
            $Int_Terminated_24h         += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 3}).count)
            $Int_PreparingSession_24h   += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 4}).count)
            $Int_Active_24h             += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 5}).count)
            $Int_Reconnecting_24h       += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 6}).count)
            $Int_NonBrokeredSession_24h += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 7}).count)
            $Int_Other_24h              += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 8}).count)
            $Int_Pending_24h            += $( ($SessionObject_day | Where-Object -FilterScript {$_.ConnectionState -eq 9}).count)
            $Int_Total_24h              += $($SessionObject_day.count)
        } Catch {
            Write-Error "$Timestamp : ERROR : Error collecting CitrixSessions from deliveryController."
            Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
            $Output_Message = "Error collecting CitrixSessions from deliveryController."
            $Boolean_Exit  = $True
        }
    }
}

## Writing values to PRTG - 24h
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status unknown (24h)' -Value $Int_Unknown_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Unknown_24h to channel 'Status unknown (24h)'"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status connected (24h)' -Value $Int_Connected_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Connected_24h to channel 'Status connected (24h)'"        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status disconnected (24h)' -Value $Int_DisConnected_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_DisConnected_24h to channel 'Status disconnected (24h)'"                        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status terminated (24h)' -Value $Int_Terminated_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Terminated_24h to channel 'Status terminated (24h)'"                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status PreparingSession (24h)' -Value $Int_PreparingSession_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_PreparingSession_24h to channel 'Status PreparingSession (24h)'"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Active (24h)' -Value $Int_Active_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Active_24h to channel 'Status Active (24h)'"                                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Reconnecting (24h)' -Value $Int_Reconnecting_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Reconnecting_24h to channel 'Status Reconnecting (24h)'"  
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status NonBrokeredSession (24h)' -Value $Int_NonBrokeredSession_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_NonBrokeredSession_24h to channel 'Status NonBrokeredSession (24h)'"  
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Other (24h)' -Value $Int_Other_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Other_24h to channel 'Status Other (24h)'"                                                                        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Pending (24h)' -Value $Int_Pending_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Pending_24h to channel 'Status Pending (24h)'"                                                                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Total sessions (24h)' -Value $Int_Total_24h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Total_24h to channel 'Total sessions (24h)'"                                                                                        
    } Catch {
        Write-Error "$Timestamp : ERROR : Error writing Usersessions to PRTG (24h)"
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error writing Usersessions to PRTG (24h)"
        $Boolean_Exit  = $True
    }
}

## Writing values to PRTG - 1h
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status unknown (1h)' -Value $Int_Unknown_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Unknown_1h to channel 'Status unknown (1h)'"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status connected (1h)' -Value $Int_Connected_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Connected_1h to channel 'Status connected (1h)'"        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status disconnected (1h)' -Value $Int_DisConnected_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_DisConnected_1h to channel 'Status disconnected (1h)'"                        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status terminated (1h)' -Value $Int_Terminated_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Terminated_1h to channel 'Status terminated (1h)'"                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status PreparingSession (1h)' -Value $Int_PreparingSession_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_PreparingSession_1h to channel 'Status PreparingSession (1h)'"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Active (1h)' -Value $Int_Active_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Active_1h to channel 'Status Active (1h)'"                                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Reconnecting (1h)' -Value $Int_Reconnecting_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Reconnecting_1h to channel 'Status Reconnecting (1h)'"  
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status NonBrokeredSession (1h)' -Value $Int_NonBrokeredSession_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_NonBrokeredSession_1h to channel 'Status NonBrokeredSession (1h)'"  
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Other (1h)' -Value $Int_Other_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Other_1h to channel 'Status Other (1h)'"                                                                        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Status Pending (1h)' -Value $Int_Pending_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Pending_1h to channel 'Status Pending (1h)'"                                                                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Total sessions (1h)' -Value $Int_Total_1h
        Write-Verbose "$TimeStamp : LOG   : Written value $Int_Total_1h to channel 'Total sessions (1h)'"                                                                                        
    } Catch {
        Write-Error "$Timestamp : ERROR : Error writing Usersessions to PRTG (1h)"
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error writing Usersessions to PRTG (1h)"
        $Boolean_Exit  = $True
    }
}

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

If ($Boolean_Exit -eq $False) { $Output_Message = "$Int_Total_24h usersessions in the last 24h"}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml