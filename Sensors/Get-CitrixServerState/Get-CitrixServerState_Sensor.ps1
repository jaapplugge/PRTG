<#
.SYNOPSIS
PRTG-Sensor for reading the basic Citrix data for a single server.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect to the oData service of 
the Citrix Studio / Delivery Controller, and collect the data for a specific Citrix-server /
host.

It will post, in seperate channels:
- Whether or not the server is in maintenancemode
- Whether or not the server is active
- The desktop deliveryGroup
- The number of logged-in users
- The number of disconnected users

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER DeliveryController
Mandatory parameter for defining the deliveryController to read from.

.PARAMETER CitrixServer
Mandatory parameter for defining the server to report on.

.PARAMETER Username
Mandatory parameter for defining the username of the account to be used.

.PARAMETER Password
Mandatory parameter for defining the password of this username.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       get-CitrixServerState_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\Get-CitrixServerState_ChannelConfiguration.xml" -CitrixServer "ctx01.plugge-d.local"  -DeliveryController "server01.plugge-d.local" -Username "sa_prtg@test.local" -Password "Welkom123"'
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
.\get-CitrixServerState_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-CitrixServerState_ChannelConfiguration.xml" -CitrixServer "ctx01.plugge-d.local" -DeliveryController "server01.plugge-d.local" -Username "sa_prtg@test.local" -Password "Welkom123"

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
    [Parameter(Mandatory=$true,Position=3)][String]$CitrixServer,
    [Parameter(Mandatory=$false)][String]$Username,
    [Parameter(Mandatory=$false)][String]$Password
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False

[PSObject] $CTXObject       = $null
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null

If ($CitrixServer -like "*.*" ) { $CitrixServer = ($CitrixServer.split('.'))[0] }

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

## Collecting serverObject 
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $CTXObject = Get-PRTGCitrixVM -Server $DeliveryController -Credential $Credential -MachineName $CitrixServer
        Write-Verbose    "$Timestamp : LOG   : Collected Citrixserver $($CTXObject.Id)"
        If (!($CTXObject)) {
            Write-Error "$Timestamp : ERROR : Could not find matching CitrixserverObject ($CitrixServer)."
            $Output_Message = "Could not find matching CitrixserverObject! ($CitrixServer)"
            $Boolean_Exit = $true
        }
    } Catch {
        Write-Error "$Timestamp : ERROR : Error collecting CitrixServer from deliveryController."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error collecting CitrixServer from deliveryController."
        $Boolean_Exit  = $True
    }
}

## Determining status of the VM - Warnings
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($CTXObject.IsPreparing -eq $true) {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Preparing' -Value 1
        Write-Verbose "$Timestamp : LOG   : Writing 1 to Channel Preparing."        
        $Output_Message  = "Server is Preparing.."
        $Boolean_warning = $true
    } Else {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Preparing' -Value 0
        Write-Verbose "$Timestamp : LOG   : Writing 0 to Channel Preparing."
    } 
    If ($CTXObject.IsPendingUpdate -eq $true) {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'PendingUpdate' -Value 1
        Write-Verbose "$Timestamp : LOG   : Writing 1 to Channel PendingUpdate."        
        $Boolean_warning = $true
        $Output_Message  = "Server is Pending Update"
    } Else {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'PendingUpdate' -Value 0
        Write-Verbose "$Timestamp : LOG   : Writing 0 to Channel PendingUpdate."
    }
    If ($CTXObject.IsInMaintenanceMode -eq $true) {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'MaintenanceMode' -Value 1
        Write-Verbose "$Timestamp : LOG   : Writing 1 to Channel MaintenanceMode."  
        $Boolean_warning = $true      
        $Output_Message  = "Server is in MaintenanceMode"
    } Else {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'MaintenanceMode' -Value 0
        Write-Verbose "$Timestamp : LOG   : Writing 0 to Channel MaintenanceMode."
    }
}

##Determining real error status
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    
    ##Current powerstate; what are the possible values?
    If ($CTXObject.CurrentPowerState -eq 3) {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Powerstate' -Value 1
        Write-Verbose "$Timestamp : LOG   : Writing 1 to Channel PowerState."
    } Else {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'PowerState' -Value 0
        Write-Verbose "$Timestamp : LOG   : Writing 0 to Channel PowerState."  
        $Boolean_warning = $true 
        $Boolean_error   = $true     
        $Output_Message  = "Server is in NOT in correct powerstate ($($CTXObject.CurrentPowerState))"        
    }        

    ##CurrentRegistrationState; what are the possible values?
    If ($CTXObject.CurrentRegistrationState -eq 1) {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'RegistrationState' -Value 1
        Write-Verbose "$Timestamp : LOG   : Writing 1 to Channel RegistrationState."
    } Else {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'RegistrationState' -Value 0
        Write-Verbose "$Timestamp : LOG   : Writing 0 to Channel RegistrationState."  
        $Boolean_warning = $true 
        $Boolean_error   = $true     
        $Output_Message  = "Server is in NOT in correct registrationState ($($CTXObject.CurrentRegistrationState))"        
    }    
}

##Setting infomessage is Error nor Warning
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_error -eq $false) -and ($Boolean_Warning -eq $fase) ) {
        $Output_Message = "Server $($CTXObject.HostedMachineName) is active."
        Write-Verbose "$TimeStamp : LOG   : setting infomessage $Output_Message"
} 

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml