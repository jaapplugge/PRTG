<#
.SYNOPSIS
PRTG-Sensor for reading how many servers are available in a DeliveryGroup, and whether they
are active or not.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect to the oData service of 
the Citrix Studio / Delivery Controller, and collect the data for the Citrix servers in
a DeliveryGroup. 

It will read if all servers are booted, registered and available, and alert if not.

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
- EXE/Script:       Get-CitrixDeliveryGroupServers_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\Get-CitrixDeliveryGroupServers_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup 'Desktop_with_Office' -Username "sa_prtg@test.local" -Password "Welkom123" '
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
.\Get-CitrixDeliveryGroupServers_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-CitrixAvgLoginTime_ChannelConfiguration.xml" -DeliveryController "server01.test.local" -DeliveryGroup 'Desktop_with_Office' -Username "sa_prtg@test.local" -Password "Welkom123"

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
[PSObject] $CTXObject       = $null
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]      $Configuration   = $null
[String]   $GroupID         = $null
[Array]    $Array_VM        = @()

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

## Collecting serverInfo per server
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Foreach ($VM in $Array_VM) {
        [Boolean] $Boolean_ok = $true
        If ($($VM.Name)) {
            Try {
                $CTXObject = Get-PRTGCitrixVM -Server $DeliveryController -Credential $Credential -MachineName $($VM.HostedMachineName)
                Write-Verbose    "$Timestamp : LOG   : Collected Citrixserver $($CTXObject.HostedMachineName)"
                $int_Total++
                If ($CTXObject.isMaintenancemode -eq $true) {$int_MaintenanceMode++; $Boolean_ok = $false}
                If ($CTXObject.IsPendingUpdate   -eq $true) {$int_PendingUpdate++; $Boolean_ok = $false}
                If ($CTXObject.IsPreparing       -eq $true) {$int_Preparing++; $Boolean_ok = $false}
                If ($CTXObject.CurrentPowerState -ne 3)     {$int_PowerState++; $Boolean_ok = $false}
                If ($CTXObject.CurrentRegistrationState -ne 1) {$int_RegistrationState++; $Boolean_ok = $false}
                If ($Boolean_ok -eq $true) {$int_Working++}
            } Catch {
                Write-Error "$Timestamp : ERROR : Error collecting CitrixSessions from deliveryController."
                Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
                $Output_Message = "Error collecting CitrixSessions from deliveryController."
                $Boolean_Exit  = $True
            }
        }
    }
}

## Writing values to PRTG - 24h
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers in MaintenanceMode' -Value $int_MaintenanceMode
        Write-Verbose "$TimeStamp : LOG   : Written value $int_MaintenanceMode to channel 'Servers in MaintenanceMode'"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers pending update' -Value $int_PendingUpdate
        Write-Verbose "$TimeStamp : LOG   : Written value $int_PendingUpdate to channel 'Servers pending update'"        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers preparing..' -Value $int_Preparing
        Write-Verbose "$TimeStamp : LOG   : Written value $int_Preparing to channel 'Servers preparing..'"                        
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers powered off' -Value $int_PowerState
        Write-Verbose "$TimeStamp : LOG   : Written value $int_PowerState to channel 'Servers powered off'"                                
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers unregistered' -Value $int_RegistrationState
        Write-Verbose "$TimeStamp : LOG   : Written value $int_RegistrationState to channel 'Servers unregistered'"
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers working' -Value $int_Working
        Write-Verbose "$TimeStamp : LOG   : Written value $int_Working to channel 'Servers working'" 
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Servers total' -Value $int_Total
        Write-Verbose "$TimeStamp : LOG   : Written value $int_Working to channel 'Servers total'"                                                        
    } Catch {
        Write-Error "$Timestamp : ERROR : Error writing Servers to PRTG"
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Error writing Servers to PRTG"
        $Boolean_Exit  = $True
    }
}

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml