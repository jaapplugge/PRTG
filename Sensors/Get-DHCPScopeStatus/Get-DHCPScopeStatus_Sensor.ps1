<#
.SYNOPSIS
PRTG-Sensor for Collecting use and percentage free for all active scopes on a DHCP Server

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will create a CimSession to a 
remote DHCP server, and collect scopestatistics for the DHCP scopes in the channel-
configuration. It will compare these agains error- and warningvalues in this config,
and will alert if use is above these values.

This sensor uses an CimSession, and is not ment to query the local server the probe
is running on. Credentials for a server in a remote domain can be given.

.PARAMETER Server
Mandatory parameter for defing the remote DHCP-server.

.PARAMETER Filename
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

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
- EXE/Script:       Get-DHCPScopeStatus_Sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\filename.xml" -Server "dhcp01.plugge-d.local" '
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
.\Get-DHCPScopeStatus_Sensor.ps1 -Filename "\\Server.domain.local\share\folder\filename.xml" -Server "dhcp01.plugge-d.local"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten
Version 1.0 / 09-06-2019: Initial upload
Version 2.0 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Server,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $Filename,
        [Parameter(Mandatory=$False,Position=3)] [String]  $Username,
        [Parameter(Mandatory=$False,Position=4)] [String]  $Password
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Cred    = $True
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False

[Array]    $ScopeStatus     = @()

[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $Channelname     = $null
[Int]      $WarningValue    = 0
[Int]      $ErrorValue      = 0

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
        Write-Verbose "$Timestamp : ERROR : Could not build credential object."
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
        $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $ChannelConfiguration = $Configuration.prtg.result
        Write-Verbose "$Timestamp : LOG   : Imported channelconfiguration."
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Boolean_Exit = $True
    }
}

##Collecting Scopes from DHCP servers
[String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $False) {
        Try {
            Write-Verbose   "$Timestamp : LOG   : Collected statistics for Active Scopes."
            $ScopeStatus  = Get-PRTGDHCPScopeStatistics -Server $Server
            Write-Verbose   "$Timestamp : LOG   : Collected $($ScopeStatus.Count) ScopeStatistics."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect scopestatistics for server $Server."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            Write-Verbose   "$Timestamp : LOG   : Collected statistics for Active Scopes w/ creds."
            $ScopeStatus  = Get-PRTGDHCPScopeStatistics -Server $Server -Credential $Credential
            Write-Verbose   "$Timestamp : LOG   : Collected $($ScopeStatus.Count) ScopeStatistics w/ creds."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect scopestatistics for server $Server w/ creds."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Exit = $True
        }
    }
}

## Looping through channels
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Write-Verbose "$TimeStamp : LOG   : Looping through ChannelConfiguration."
    Foreach ($Channel in $ChannelConfiguration) {
        [String]  $Channelname  = $Channel.Channel
        [Int]     $ErrorValue   = $Channel.LimitMaxError
        [Int]     $WarningValue = $Channel.LimitMaxWarning
        [Int]     $Count        = 0

        ##Matching ChannelName to Name in ResultArray
        [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) {
            Write-Verbose "$TimeStamp : LOG   : Looping through ResultArray to match on LongName."
            ForEach ($Scope in $ScopeStatus) {
                If ($Channelname -eq $($ScopeStatus[$Count].LongName) ) {
                    Write-Verbose    "$TimeStamp : LOG   : Selected $($ScopeStatus[$Count].LongName). Writing PRTG result."
                    Try {
                        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Channelname -Value $($ScopeStatus[$Count].PercentageInUse)
                        Write-Verbose    "$TimeStamp : LOG   : Written $($ScopeStatus[$Count].PercentageInUse) to Channel $ChannelName."
                    } Catch {
                        Write-Error     "$TimeStamp : ERROR : Could not write to PRTG."
                        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
                        $Boolean_Exit = $True
                    }
                   
                    ##Determining WarningStatus
                    [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
                    If ( 
                        ($Boolean_Exit    -eq $False) -and 
                        ($Boolean_Warning -eq $False) -and 
                        ($Boolean_Error   -eq $False) 
                    ) {
                        If ( ($($ScopeStatus[$Count].PercentageInUse) -gt $WarningValue) -and ($WarningValue -ne 0) ) {
                            $Boolean_Warning = $True
                            Write-verbose      "$Timestamp : LOG   : Detected WARNING-value."
                            $Output_Message  = "Scope $($ScopeStatus[$Count].LongName) only has $($ScopeStatus[$Count].Free) addresses available."
                            Write-verbose      "$Timestamp : LOG   : '$Output_Message' written."
                        }
                    }
                                
                    ##Determining ERRORStatus
                    [String]  $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm
                    If ( 
                        ($Boolean_Exit    -eq $False) -and 
                        ($Boolean_Error   -eq $False) 
                    ) {
                        If ( ($($ScopeStatus[$Count].PercentageInUse) -gt $ErrorValue) -and ($ErrorValue -ne 0) ) {
                            $Boolean_Warning = $True
                            $Boolean_Error   = $True
                            Write-verbose      "$Timestamp : LOG   : Detected ERROR-value."
                            $Output_Message  = "Scope $($ScopeStatus[$Count].LongName) only has $($ScopeStatus[$Count].Free) addresses available. `n"
                            Write-verbose      "$Timestamp : LOG   : '$Output_Message' written."
                        }
                    }
                } 
                $Count++
            }
        }
    }
}

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
    $Output_Message = "ERRORSTATE DETECTED IN SENSOR !! Run sensor in verbose to troubleshoot."
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml