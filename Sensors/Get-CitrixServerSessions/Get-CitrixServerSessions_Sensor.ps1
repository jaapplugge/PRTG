<#
.SYNOPSIS
PRTG-Sensor for reading the usersessions on a single Citrixserver.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect to the oData service of 
the Citrix Studio / Delivery Controller, and collects all sessiondata for a specific 
Citrix-server /host.

It will post, in seperate channels, all different statusses possible for a usersession.
Errorvalues can be set on the individual channels.

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER DeliveryController
Mandatory parameter for defining the deliveryController to read from.

.PARAMETER CitrixServer
Mandatory parameter for defining the Citrixserver to report on.

.PARAMETER Username
Mandatory parameter for defining the username of the account to be used.

.PARAMETER Password
Mandatory parameter for defining the password of this username.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       get-CitrixServerSessions_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\get-CitrixServerSessions_ChannelConfiguration.xml" -CitrixServer "ctx01.plugge-d.local"  -DeliveryController "server01.plugge-d.local" -Username "sa_prtg@test.local" -Password "Welkom123"'
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
.\get-CitrixServerSessions_sensor.ps1 -Filename "\\Server.domain.local\share\folder\get-CitrixServerSessions_ChannelConfiguration.xml" -CitrixServer "ctx01.plugge-d.local" -DeliveryController "server01.plugge-d.local" -Username "sa_prtg@test.local" -Password "Welkom123"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 23.07.2022: Initial upload 

.LINK
https://github.com/jaapplugge/PRTGModule
https://developer-docs.citrix.com/projects/monitor-service-odata-api/en/latest/api-reference/Monitor.Model/#sessionfailurecode-enums

#>

## Parameters
[cmdletbinding()] Param (
    [Parameter(Mandatory=$true,Position=1)][String]$Filename,
    [Parameter(Mandatory=$true,Position=2)][String]$DeliveryController,
    [Parameter(Mandatory=$true,Position=3)][String]$CitrixServer,
    [Parameter(Mandatory=$false)][String]$Username,
    [Parameter(Mandatory=$false)][String]$Password
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[PSObject] $CTXObject       = $null
[Array]    $SessionObject   = @()
[Array]    $Sessions        = @()
[Array]    $Hour_Session    = @()
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null
[Array]    $SelectedSessions = @()

Write-Verbose     "SENSOR:$Command"
Write-Verbose     "---------------------"
Write-Verbose     "$Timestamp : LOG   : Username: $env:username"
Write-Verbose     "$Timestamp : LOG   : Computer: $LocalComputer"
Write-Verbose     "$Timestamp : LOG   : Session : $( ([System.IntPtr]::Size)*8 )bit Session"

##ConnectionState Table
$ConnectionStateArray = @(
    @{
        "Value" = 0
        "Channel" = "Sessions with Status unknown" 
        "Description" = "Default value, unknown"
    },
    @{
        "Value" = 1
        "Channel" = "Sessions with Status Connected"
        "Description" = "Actively connected to desktop"
    },
    @{
        "Value" = 2
        "Channel" = "Sessions with Status Disconnected"
        "Description" = "Disconnected from desktop, but session still exists"        
    },
    @{
        "Value" = 3
        "Channel" = "Sessions with Status Terminated"
        "Description" = "Session has been terminated"        
    },
    @{
        "Value" = 4
        "Channel" = "Sessions with Status PreparingSession"
        "Description" = "Session is in the preparing state"        
    },
    @{
        "Value" = 5
        "Channel" = "Sessions with Status Active"
        "Description" = "Session is active"        
    },
    @{
        "Value" = 6
        "Channel" = "Sessions with Status Reconnecting"
        "Description" = "User is reconnecting to the session"        
    },
    @{
        "Value" = 7
        "Channel" = "Sessions with Status NonBrokeredSession"
        "Description" = "Session is non-brokered"        
    },
    @{
        "Value" = 8
        "Channel" = "Sessions with Status Other"
        "Description" = "Connection state is reported as Other"        
    },
    @{
        "Value" = 9
        "Channel" = "Sessions with Status Pending"
        "Description" = "Connection state is pending"        
    }
)
#https://developer-docs.citrix.com/projects/monitor-service-odata-api/en/latest/api-reference/Monitor.Model/#sessionfailurecode-enums

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

## Collecting serverObject 
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $CTXObject = Get-PRTGCitrixVM -Server $DeliveryController -Credential $Credential -MachineName $CitrixServer
        Write-Verbose    "$Timestamp : LOG   : Collected Citrixserver $($CTXObject.Id)"
        If (!($CTXObject)) {
            Write-Error "$Timestamp : ERROR : Could not find matching CitrixserverObject."
            $Output_Message = "Could not find matching CitrixserverObject"
            $Boolean_Exit = $true
        }
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting CitrixServer from deliveryController."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting CitrixServer from deliveryController."
        $Boolean_Exit  = $True
    }
}

## Collecting sessionInfo
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $SessionObject = Get-PRTGCTXSessionInfo -Server $DeliveryController -Credential $Credential -CitrixServerID $($CTXObject.Id)
        Write-Verbose    "$Timestamp : LOG   : Collected sessions from Citrixserver $($CTXObject.DNSHostName)"
        If (!($SessionObject)) {
            Write-Error "$Timestamp : ERROR : Could not find matching CitrixSessions."
            $Output_Message = "No Citrixsessions found last 24h"
            $Boolean_Exit = $true
        }
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting CitrixSessions from deliveryController."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting CitrixSessions from deliveryController."
        $Boolean_Exit  = $True
    }
}

## Writing values - Last 24h
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {

    ##Sessions last 24 hours
    Try {
        $Sessions = $SessionObject | Sort-Object -Unique -Property UserId
        Write-Verbose "$TimeStamp : LOG   : Sorted out Sessions last 24hours"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Usersessions in the last 24h' -Value $($Sessions.Count)
        Write-Verbose "$TimeStamp : LOG   : Written value $($Sessions.Count) to channel Usersessions in the last 24h"
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting Usersessions in the last 24h."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting Usersessions in the last 24h."
        $Boolean_Exit  = $True
    }

    ##Active sessions
    Try {
        $Sessions = $SessionObject | Where-Object -FilterScript { $null -eq $_.EndDate } | Sort-Object -Unique -Property UserId
        Write-Verbose "$TimeStamp : LOG   : Filtered out ActiveSessions"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Active Usersessions in the last 24h' -Value $($Sessions.Count)
        Write-Verbose "$TimeStamp : LOG   : Written value $($Sessions.Count) to channel Active Usersessions in the last 24h"
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting ActiveSessions."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting ActiveSessions."
        $Boolean_Exit  = $True
    }
}

## Writing values: last hour
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    $Hour_Session = $SessionObject | Where-Object -FilterScript { ($null -eq $_.EndDate) -or ($_.EndDate -gt $((Get-Date).AddHours(-1)))}
    Write-Verbose "$TimeStamp : LOG   : Last hour, $($Hour_Session.Count) sessions where active"
    $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Usersessions in the last 1h' -Value $($Hour_Session.Count)
    Write-Verbose "$TimeStamp : LOG   : Written to PRTG channel Usersessions in the last 1h"
    Foreach ($Channel in $ConnectionStateArray) {
        $SelectedSessions = @()
        $SelectedSessions = $Hour_Session | Where-Object -FilterScript {$_.ConnectionState -eq $($Channel.value)}
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($Channel.channel) -Value $($Channel.value)
        Write-Verbose "$TimeStamp : LOG   : Written value $($Channel.value) to channel $($Channel.channel)"
    }
}

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml