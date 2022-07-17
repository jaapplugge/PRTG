<#
.SYNOPSIS
PRTG-Sensor for reading registry-items for a McAfee ePO installation

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will connect via WMI to a remote
computer, and read the registry for 
 - Last definition update
 - Last quick scan (in developement)
 - Last full scan (in developement)
 - and the versions of application, coresystem, definitions and agent.

Since this script collects events for x86 application and x64, it needs to be ran in 
a x64 powershell session. A runner-script is added for this.

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER Computer
Mandatory parameter for defining the computer to read the eventlog from.

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
- EXE/Script:       get-mcAfeeStatus_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\filename.xml" -Computer "plugge-fs01.plugge-d.local" '
- Enviroment:       personal preference
- Security context: personal preference
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. Every 12 hours will be fine.

Script can be run locally for test-purposes via
.\Get-McAfeeStatus_sensor.ps1 -Filename "\\Server.domain.local\share\folder\filename.xml" -Computer "plugge-fs01.plugge-d.local" -username "plugge-d\jaap" -password "Welkom123"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 03.08.2020: Initial upload 
Version 1.1 / 14-11-2021: Moved functions to PRTG Module
Version 2.0 / 10-07-2022: Moved to Github

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
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[Boolean]  $Boolean_Cred    = $False

[Hashtable] $Splat_ApplicationVersion   = @{}
[Hashtable] $Splat_AgentVersion         = @{}
[Hashtable] $Splat_DefinitionVersion    = @{}
[Hashtable] $Splat_SystemCoreVersion    = @{}
[Hashtable] $Splat_LastDefinitionUpdate = @{}

[String]    $Date_LastQuickScan         = $null
[String]    $Date_LastQuickScan         = $null
[String]    $Date_LastDefinitionUpdate  = $Null
[String]    $AgentVersion       = $null

[String]    $Applicationversion = $null
[String]    $SystemCoreVersion  = $null
[String]    $Name_1 = $null
[String]    $Name_2 = $null
[float]  $Return_AgentVersion       = 0
[float]  $Return_ApplicationVersion = 0
[float]  $Return_SystemCoreVersion  = 0
[UInt32] $DefinitionVersion         = 0
[float]  $Hours_Definitionupdate    = 0

[String]    $Command        = $MyInvocation.MyCommand.Name
[String]    $Timestamp      = Get-Date -format yyyy.MM.dd_hh:mm
[String]    $Output_Message = "OK"
[String]    $LocalComputer  = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[XML]       $Configuration  = $null

Write-Verbose "SENSOR:$Command"
Write-Verbose $("_" * 120)
Write-Verbose "$Timestamp : LOG   : Username: $env:username"
Write-Verbose "$Timestamp : LOG   : Computer: $LocalComputer"
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

## Checking if Creds are given
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Username -eq "") -or !($Username) ) {
        Write-Verbose   "$TimeStamp : LOG   : Using context creds."
        $Boolean_Cred = $False
} Else {
    Try {
        Write-Verbose   "$TimeStamp : LOG   : Creds provided, building credential object"
        $SecureString = ConvertTo-SecureString -String "$Password" -AsPlainText -Force
        $Credential   = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecureString
        $Boolean_Cred = $True
        Write-Verbose   "$Timestamp : LOG   : Credentialobject build on username $Username / $($Credential.Username)."
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
        $Output_Message = "Could not import configfile."
        $Boolean_Exit  = $True
    }
}

## Collecting Days since last definition update
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Splat_LastDefinitionUpdate = @{
            "Registryhyve" = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Hours since last definition update'}).config.registryhyve
            "Registry"     = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Hours since last definition update'}).config.registrypath
            "DataType"     = [String] "String"
            "Computer"     = [String] $Computer
        }
        $Name_1 = ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Hours since last definition update'}).config.registrykey.key1
        $Name_2 = ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Hours since last definition update'}).config.registrykey.key2
        Write-Verbose "$TimeStamp : LOG   : Collected regkey 1: $Name_1"
        Write-Verbose "$TimeStamp : LOG   : Collected regkey 2: $Name_2"
        Write-Verbose "$TimeStamp : LOG   : Created splat for connecting to the remote registry ($($Splat_LastDefinitionUpdate.Computer))"
        If ($Boolean_Cred -eq $True) { 
            $Splat_LastDefinitionUpdate.Add("Credential", $Credential)
            Write-Verbose "$TimeStamp : LOG   : Passing credentials in splat ($($Credential.Username))"
        }
        $Date_LastDefinitionUpdate = $(Get-PRTGClientRegistryValue @Splat_LastDefinitionUpdate -Name $Name_1) + ' ' + $(Get-PRTGClientRegistryValue @Splat_LastDefinitionUpdate -Name $Name_2)
        Write-verbose "$TimeStamp : LOG   : Collected last definition update date $Date_LastDefinitionUpdate"
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not collect date for Last Definition Update."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not collect date for Last Definition Update."
        $Boolean_Exit  = $True
    }
}

## Collecting versions - applicationVersion
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        Write-Verbose "$TimeStamp : LOG   : Collecting application version" 
        $Splat_ApplicationVersion = @{
            "Registryhyve" = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Application Version'}).config.registryhyve
            "Registry"     = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Application Version'}).config.registrypath
            "Name"         = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Application Version'}).config.registrykey
            "Computer"     = [String] $Computer
            "DataType"     = [String] "String"
        }
        Write-Verbose "$TimeStamp : LOG   : Created splat for connecting to the remote registry"
        If ($Boolean_Cred -eq $True) { 
            $Splat_ApplicationVersion.Add("Credential", $Credential)
            Write-Verbose "$TimeStamp : LOG   : Passing credentials in splat."
        }
        $ApplicationVersion = Get-PRTGClientRegistryValue @Splat_ApplicationVersion
        Write-verbose "$TimeStamp : LOG   : Collected application version $Applicationversion"
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not collect ApplicationVersion."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not collect ApplicationVersion."
        $Boolean_Exit  = $True       
    }
}

## Writing to PRTG - ApplicationVersion
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Return_ApplicationVersion = [int]$ApplicationVersion.split('.')[0] + 0.1*[Int]$ApplicationVersion.Split('.')[1]
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Application Version' -Value $Return_ApplicationVersion
        Write-Verbose    "$Timestamp : LOG   : Written value $Return_ApplicationVersion to Channel 'Application Version'."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not write to channel 'Application Version'."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to channel 'Application Version'."
        $Boolean_Exit  = $True
    }
}

## Collecting versions - SystemCoreVersion
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {    
    Try {
        Write-Verbose "$TimeStamp : LOG   : Collecting System Core version" 
        $Splat_SystemCoreVersion = @{
            "Registryhyve" = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'SystemCore Version'}).config.registryhyve
            "Registry"     = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'SystemCore Version'}).config.registrypath
            "Name"         = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'SystemCore Version'}).config.registrykey
            "DataType"     = [String] "String"
            "Computer"     = [String] $Computer
        }
        Write-Verbose "$TimeStamp : LOG   : Created splat for connecting to the remote registry"
        If ($Boolean_Cred -eq $True) { 
            $Splat_SystemCoreVersion.Add("Credential", $Credential)
            Write-Verbose "$TimeStamp : LOG   : Passing credentials in splat."
        }
        $SystemCoreVersion = Get-PRTGClientRegistryValue @Splat_SystemCoreVersion
        Write-verbose "$TimeStamp : LOG   : Collected System Core version $SystemCoreVersion"
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not collect SystemCoreVersion."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not collect SystemCoreVersion."
        $Boolean_Exit  = $True
    }
}

## Writing to PRTG - System Core Version
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Return_SystemCoreVersion = [int]$SystemCoreVersion.split('.')[0] + 0.1*[Int]$SystemCoreVersion.Split('.')[1]
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'SystemCore Version' -Value $Return_SystemCoreVersion
        Write-Verbose    "$Timestamp : LOG   : Written value $Return_SystemCoreVersion to Channel 'SystemCore Version'."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not write to channel 'SystemCore Version'."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to channel 'SystemCore Version'."
        $Boolean_Exit  = $True
    }
}

## Collecting versions - AgentVersion
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        Write-Verbose "$TimeStamp : LOG   : Collecting Agent version" 
        $Splat_AgentVersion = @{
            "Registryhyve" = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Agent Version'}).config.registryhyve
            "Registry"     = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Agent Version'}).config.registrypath
            "Name"         = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Agent Version'}).config.registrykey
            "DataType"     = [String] "String"
            "Computer"     = [String] $Computer
        }
        Write-Verbose "$TimeStamp : LOG   : Created splat for connecting to the remote registry"
        If ($Boolean_Cred -eq $True) { 
            $Splat_AgentVersion.Add("Credential",$Credential)
            Write-Verbose "$TimeStamp : LOG   : Passing credentials in splat."
        }
        $AgentVersion = Get-PRTGClientRegistryValue @Splat_AgentVersion
        Write-verbose "$TimeStamp : LOG   : Collected Agent version $AgentVersion"
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not collect AgentVersion."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not collect AgentVersion."
        $Boolean_Exit  = $True       
    }
}
## Writing to PRTG - Agent Version
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Return_AgentVersion = [int]$AgentVersion.split('.')[0] + 0.1*[Int]$AgentVersion.Split('.')[1]
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Agent Version' -Value $Return_AgentVersion
        Write-Verbose    "$Timestamp : LOG   : Written value $Return_AgentVersion to Channel 'Agent Version'."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not write to channel 'Agent Version'."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to channel 'Agent Version'."
        $Boolean_Exit  = $True
    }    
}

## Collecting versions - DefinitionVersion
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        Write-Verbose "$TimeStamp : LOG   : Collecting Definition version" 
        $Splat_DefinitionVersion = @{
            "Registryhyve" = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).config.registryhyve
            "Registry"     = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).config.registrypath
            "Name"         = [String] ($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).config.registrykey
            "DataType"     = [String] "DWord"
            "Computer"     = [String] $Computer
        }
        Write-Verbose "$TimeStamp : LOG   : Created splat for connecting to the remote registry"
        If ($Boolean_Cred -eq $True) { 
            $Splat_DefinitionVersion.Add("Credential",$Credential)
            Write-Verbose "$TimeStamp : LOG   : Passing credentials in splat."
        }
        $DefinitionVersion = Get-PRTGClientRegistryValue @Splat_DefinitionVersion
        Write-verbose "$TimeStamp : LOG   : Collected Definition version $DefinitionVersion"
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not collect DefinitionVersion."
        Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not collect DefinitionVersion."
        $Boolean_Exit  = $True       
    }
}

## Writing to PRTG - Definition Version
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        #$Return_DefinitionVersion = [int]$DefinitionVersion.split('.')[0] + 0.1*[Int]$DefinitionVersion.Split('.')[1]
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Definition Version' -Value $DefinitionVersion
        Write-Verbose    "$Timestamp : LOG   : Written value $DefinitionVersion to Channel 'Definition Version'."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not write to channel 'Definition Version'."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to channel 'Definition Version'."
        $Boolean_Exit  = $True
    }
}

##Writing value to PRTG-Channel - $Date_LastDefinitionUpdate
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        Write-Verbose    "$TimeStamp : LOG   : Using String $Date_LastDefinitionUpdate"
        $Hours_Definitionupdate = [math]::Round((New-TimeSpan -Start ([datetime]::parseexact($Date_LastDefinitionUpdate, 'yyyy-MM-dd HH:mm:ss', $null) ) -end $(Get-Date )).TotalHours,2)
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel 'Hours since last definition update' -Value $Hours_Definitionupdate
        Write-Verbose    "$Timestamp : LOG   : Written value $Hours_Definitionupdate to Channel 'Hours since last definition update'."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not write to channel 'Hours since last definition update'."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to channel 'Hours since last definition update'."
        $Boolean_Exit  = $True
    }
    ##Determining WarningStatus
    [String] $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    If ( 
        $(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).LimitMaxWarning) -and    
        ( $Boolean_Warning -eq $False ) -and 
        ( $Boolean_Error   -eq $False ) -and
        ( $Hours_Definitionupdate -gt $(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).LimitMaxWarning) ) 
    ) {
        $Boolean_Warning = $True
        Write-verbose      "$Timestamp : LOG   : Detected WARNING in channel $(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).Channel)."
        $Output_Message  = "$(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).config.warningmessage) ($Hours_Definitionupdate Hour)"
    }
    ##Determining ERRORStatus
    [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    If ( 
        $(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).LimitMaxError) -and
        ( $Boolean_Error -eq $False ) -and
        ( $Hours_Definitionupdate -gt $(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).LimitMaxError) ) 
    ) {
        $Boolean_Error   = $True
        Write-verbose      "$Timestamp : LOG   : Detected ERROR in channel $(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).Channel)."
        $Output_Message  = "$(($Configuration.prtg.result | Where-Object -FilterScript {$_.Channel -eq 'Definition Version'}).config.errormessage) ($Hours_Definitionupdate Hour)"
    }
}

##Writing value to PRTG-Channel - $Date_LastQuickScan
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Still missing.."
}

##Writing value to PRTG-Channel - $Date_LastFullScan
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Still missing.."
}

## Setting errormessage if error in sensor
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
    $Output_Message = "ERRORSTATE DETECTED IN SENSOR !! Run sensor in verbose to troubleshoot."
}

If ( ($Boolean_Exit -eq $False) -and ($Boolean_Warning -eq $False) -and ($Boolean_Error -eq $False) ) {
    $Output_Message = "McAfee ePO CoreVersion $SystemCoreVersion / ApplicationVersion $Applicationversion / AgentVersion $AgentVersion / DefinitionVersion $DefinitionVersion (OK)" 
}
## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml