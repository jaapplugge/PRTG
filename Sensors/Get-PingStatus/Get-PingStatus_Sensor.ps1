<#
.SYNOPSIS Get-PingStatus_Sensor
PRTG-Sensor for checking if a set of set of computers respond to ping.

.DESCRIPTION
This script is ment to be used as PRTG-sensor.

.PARAMETER Filename
Mandatory parameter to define the XML Configurationfile to be used for the channelconfiguration

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-PingStatus_Sensor.ps1
- Parameters:       -Filename 'C:\Scripting\Configurations\Get-PingStatus_ChannelConfiguration.xml'
- Enviroment:       personal preference
- Security context: a serviceaccount with remote control rights to the clients
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. 
                    We generally run this sensor every 15-30min.

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 08.08.2019: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>                    

## Parameters
[cmdletbinding()] Param (
    [Parameter(Mandatory=$True,Position=2 )] [String] $Filename
)
## Variables
[Boolean]   $Boolean_Exit    = $False
[Boolean]   $Boolean_Error   = $False
[String]    $Output_Message  = 'OK'
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[Array]     $Servers         = @()

Write-Verbose "SENSOR:$Command"
Write-Verbose $("_" * 120)
Write-Verbose "$Timestamp : LOG   : Username: $env:username"
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

## Import the ChannelConfiguration
# If this step fails, sensor will prompt error:
# 'XML: The returned XML does not match the expected schema. (code: PE233) 
# JSON: The returned JSON does not match the expected structure (Invalid JSON.). (code: PE231)'

## Importing configuration-file
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose    "$Timestamp : LOG   : Imported configuration."
        $Servers       = $Configuration.prtg.result.channel
        Write-Verbose    "$Timestamp : LOG   : Collected different channels ($($Servers.Count))."
    } Catch {
        Write-Error      "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error      "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "ChannelConfiguration could not be loaded"
        $Boolean_Exit  = $True
    }
}

##Running queries against a computer
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($Server in $Servers) {
        [Int] $ReturnValue = 0
        [Int] $ReturnValue = Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Try {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Server -Value $ReturnValue
            Write-Verbose    "$TimeStamp : LOG   : Written result to Configuration ($Server / $ReturnValue)"
        } Catch {
            $Boolean_Exit    = $True
            $Boolean_Error   = $True
            Write-Error    "$TimeStamp : ERROR : Could not write result to Configuration ($Server / $ReturnValue)"
            $Output_Message = "Could not write result to Configuration ($Server / $ReturnValue)"
        }
        If ( ($Boolean_Error -eq $False) -and ($ReturnValue -eq 0) ) {
            $Output_Message = "Computer $Server did not respond to ping, Please investigate!"
            $Boolean_Error  = $True
            Write-Verbose    "$TimeStamp : LOG   : Detected 'Computer $Server did not respond to ping, Please investigate!'"
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