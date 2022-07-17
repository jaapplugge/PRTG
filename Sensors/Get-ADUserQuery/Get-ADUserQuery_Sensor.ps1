<#
.SYNOPSIS
PRTG-Sensor for checking an Active Directory domain. This sensor will run a number of queries based on Get-ADUser. 

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It loads the ActiveDirectory module, and runs queries to ADDS using
the Get-ADUser CMDLet. It can either use a filter, an LDAP filter, or a Where-Object statement through a pipeline.

It will return the resultcount to the channel in PRTG. If an error- or warningweight is given to a channel, it will
return the username of the first result as outputmessage.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER JsonFile
Mandatory parameter to the path of the json formatted configuration file providing the queries for the 
channels.

.PARAMETER Server
Optional parameter, for defining the servername of the server this script is ran against. If not used, script will use the domaincontroller 
it is connected to itself (so the same domain). Can be used if probe is in different domain than the AD/DS directory to query.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-ADUserQuery_Sensor.ps1
- Parameters:       -Filename 'C:\Scripting\Configurations\Get-ADUserQuery_Configuration.xml' -JsonFile 'C:\Scripting\Configurations\Get-ADUserQuery_Configuration.json'
- Enviroment:       personal preference
- Security context: 
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. Running this sensor every hour will be more than enough.

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.1 / 10-02-2019. 
Version 2.0 / 14-11-2021: Moved functions to PRTG Module

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True,Position=1 )] [String] $Filename,
        [Parameter(Mandatory=$True,Position=2 )] [String] $JsonFile,
        [Parameter(Mandatory=$False,Position=3)] [String] $Server
)

## Variables
[Boolean] $Boolean_Exit    = $False
[Boolean] $Boolean_Error   = $False
[Boolean] $Boolean_Warning = $False
[Boolean] $Boolean_Skip    = $False
[Boolean] $Boolean_Server  = $False

If ($Server) { $Boolean_Server = $True }
  
[String]  $Command         = $MyInvocation.MyCommand.Name
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]  $Output_Message  = "OK"

$ChannelConfiguration = $null
$FilterConfiguration  = $null

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

## Importing configuration-files
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
Try {
    [XML] $Configuration    = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
    $ChannelConfiguration   = $Configuration.prtg.result
    Write-Verbose "$Timestamp : LOG   : Imported Channel configuration from XML."
    $FilterConfiguration    = Import-PRTGConfigFile -FilePath $JsonFile -FileType 'Json'
    Write-Verbose "$Timestamp : LOG   : Imported Queries Json."
    $Count_max = ($FilterConfiguration.Configuration | Get-Member -MemberType NoteProperty | Where-Object -FilterScript {$_.Name -like "Configuration_*"}).Count
    Write-Verbose "$Timestamp : LOG   : Counted $Count_Max different configurations."
} Catch {
    Write-Error "$Timestamp : ERROR : Could not import Channelconfiguration or QueryConfiguration."
    Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
    $Boolean_Exit = $True
}

## Import the ActiveDirectory module
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_Exit -eq $False) -and !(Get-Module -Name ActiveDirectory) ) {
    Write-Verbose "$TimeStamp : LOG   : Trying to import the ActiveDirectory module."
    Try {
        Import-Module -Name ActiveDirectory
        Write-Verbose "$Timestamp : LOG   : Import-Module -Name ActiveDirectory succesfull."
    } Catch {
        Write-Error "$Timestamp : ERROR : Import-Module -Name ActiveDirectory NOT succesfull."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Boolean_Exit   = $True      
    }
}

## Collecting domaincontroller
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Server -eq $True) {
        Write-Verbose "$TimeStamp : LOG   : Using server $Server, explicit via parameter."
    } Else {
        Try {
            $Server = (Get-ADDomainController -Discover).hostname
            Write-Verbose "$TimeStamp : LOG   : Using server $server, discovered."
        } Catch {
            Write-Error "$Timestamp : ERROR : Could not collect domaincontroller."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Exit   = $True  
        }
    }
}


##Looping through the configurations
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($Channel in $ChannelConfiguration) {
        [Boolean] $Boolean_Skip = $False
        [Boolean] $Boolean_CustomError   = $False
        [Boolean] $Boolean_CustomWarning = $False
        [Int]    $count = 0
        [String] $Setting = $Null
        [String] $CustomWarningMessage = $null
        [String] $CustomErrorMessage = $null
        ##Looping through .Json for channel to use
        While ($count -lt $count_max) {
            $Boolean_Skip = $True
            $count++
            $Setting     = 'Configuration_' + "{0:D2}" -f $count
            Write-Verbose "$Timestamp : LOG   : Using setting $Setting to determine match with channelname $($Channel.Channel)."
            If ( ($FilterConfiguration.Configuration.$Setting.name) -eq ($Channel.Channel) ) {
                Write-Verbose "$Timestamp : LOG   : Setting $Setting is a match with channelname $($Channel.Channel).Using."
                $Count = $Count_max
                $Boolean_Skip = $False
            }
        }
        ##Collecting configuration fields from .Json
        If ($Boolean_Skip -eq $False) {
            [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
            Try {
                [Array]  $Results     = @()
                [Int]    $ResultCount = 0
                [String] $Query_Type  = $null
                [String] $Query       = $null
                [String] $OU          = $null
                [String] $SearchScope = $null
                [Array]  $Properties  = @()
                [String] $Query_Type  = $FilterConfiguration.Configuration.$Setting.Querytype
                [String] $OU          = $FilterConfiguration.Configuration.$Setting.OU
                [String] $SearchScope = $FilterConfiguration.Configuration.$Setting.SearchScope
                [Array]  $Properties  = $FilterConfiguration.Configuration.$Setting.Properties
                [String] $Query       = $FilterConfiguration.Configuration.$Setting.Query
                [String] $CustomWarningMessage = $FilterConfiguration.Configuration.$Setting.WarningMessage
                [String] $CustomErrorMessage   = $FilterConfiguration.Configuration.$Setting.ErrorMessage
                If (!( ($CustomWarningMessage -eq "") -or ($null -eq $CustomWarningMessage) ) ) {
                    $Boolean_CustomWarning = $True
                    Write-Verbose "$Timestamp : LOG   : Custom warningmessage detected."
                }
                If (!( ($CustomErrorMessage -eq "") -or ($null -eq $CustomErrorMessage) ) ) {
                    $Boolean_CustomError = $True
                    Write-Verbose "$Timestamp : LOG   : Custom Errormessage detected."
                }
                Write-Verbose "$Timestamp : LOG   : Import of variables successfull."
            } Catch {
                $Boolean_Skip = $Tue
                Write-Error "$Timestamp : ERROR : Import of variables not successfull."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
            }
        }
        
        ##Collecting OU to use for Searchbase
        If ($Boolean_Skip -eq $False) {
            [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
            Try {
                [String] $Searchbase  = (Get-ADOrganizationalUnit -server $server -Filter {Name -eq $OU}).DistinguishedName
                Write-Verbose "$Timestamp : LOG   : Collected OU $OU as $Searchbase."
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not collect OU $OU."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Skip = $True
            }
        }
        ##Running query against ADDS
        If ( ($Query_Type -eq "Filter") -and ($Boolean_Skip -eq $False) ) {
            [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
            Write-Verbose "$Timestamp : Using Querytype $Query_Type."
            Try {
                Write-Verbose "$Timestamp : LOG   : Using Querytype $Query_Type.`n"
                Write-Verbose "$Timestamp : LOG   : Searching users based on: `n"
                Write-Verbose "$Timestamp : LOG   : - Properties  : $Properties `n"
                Write-Verbose "$Timestamp : LOG   : - Searchbase  : $Searchbase `n"
                Write-Verbose "$Timestamp : LOG   : - Searchscope : $SearchScope `n"
                Write-Verbose "$Timestamp : LOG   : - Server      : $Server `n"
                Write-Verbose "$Timestamp : LOG   : - Filter      : $Query `n"
                [Hashtable] $QuerySplat = @{
                    Properties  = $Properties
                    Searchbase  = $Searchbase
                    Filter      = $Query
                    Server      = $Server
                    SearchScope = $SearchScope
                }                
                $Results = Get-ADUser @QuerySplat
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not execute query $Query using QueryType $Query_Type."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Skip = $True
            }
        } ElseIf ( ($Query_Type -eq "LDAPFilter") -and ($Boolean_Skip -eq $False) ) {
            [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
            Write-Verbose "$Timestamp : Using Querytype $Query_Type."                        
            Try {
                Write-Verbose "$Timestamp : LOG   : Searching users based on:"
                Write-Verbose "$Timestamp : LOG   : - Properties  : $Properties"
                Write-Verbose "$Timestamp : LOG   : - Searchbase  : $Searchbase"
                Write-Verbose "$Timestamp : LOG   : - Searchscope : $SearchScope"
                Write-Verbose "$Timestamp : LOG   : - Server      : $Server"
                Write-Verbose "$Timestamp : LOG   : - Filter      : $Query"
                [Hashtable] $QuerySplat = @{
                    Properties  = $Properties
                    Searchbase  = $Searchbase
                    LDAPFilter  = $Query
                    Server      = $Server
                    SearchScope = $SearchScope
                }                    
                $Results = Get-ADUser @QuerySplat | Select-Object -Property $Properties
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not execute query $Query using QueryType $Query_Type."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Skip = $True
            }
        } ElseIf ( ($Query_Type -eq "ExtendedFilter") -and ($Boolean_Skip -eq $False) ) {
            [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
            Write-Verbose "$Timestamp : LOG   : Using Querytype $Query_Type."
            Try {
                Write-Verbose "$Timestamp : LOG   : First, creating a scriptblock to pass through."
                [Scriptblock] $Scriptblock  = [Scriptblock]::Create($($FilterConfiguration.Configuration.$Setting.Query))
                Write-Verbose "$Timestamp : LOG   : Now run the scriptblock in a where statement."
                Write-Verbose "$Timestamp : LOG   : Searching users based on:"
                Write-Verbose "$Timestamp : LOG   : - Properties  : $Properties"
                Write-Verbose "$Timestamp : LOG   : - Searchbase  : $Searchbase"
                Write-Verbose "$Timestamp : LOG   : - Searchscope : $SearchScope"
                Write-Verbose "$Timestamp : LOG   : - Server      : $Server"
                Write-Verbose "$Timestamp : LOG   : - Filter      : $Query"
                Write-Verbose "$Timestamp : LOG   : - Scriptblock : $Scriptblock"
                [Hashtable] $QuerySplat = @{
                    Properties  = $Properties
                    Searchbase  = $Searchbase
                    Filter      = "*"
                    Server      = $Server
                    SearchScope = $SearchScope
                }
                $Results = Get-ADUser @QuerySplat | Where-Object -FilterScript $Scriptblock | Select-Object -Property $Properties
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not execute query $Query using QueryType $Query_Type."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Skip = $True
            }
        }
        
        ##Summarizing
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Skip -eq $False) -and ($($Results.Count) -gt 0) ) {
            $ResultCount           = $Results.Count
            $Username_first_result = $Results[0].name
            Write-Verbose "$Timestamp : LOG   : Collected $ResultCount users."
            Write-Verbose "$Timestamp : LOG   : First username : $Username_first_result."
        }

        ##Accounting for Boolean_Skip
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $True) {
            $ResultCount     = 0
            $Boolean_Error   = $True
            $Boolean_Warning = $True
            $Boolean_Exit    = $True
            Write-Verbose "$Timestamp : LOG   : Hit `$Boolean_Skip -eq `$True."
            Write-Verbose "$Timestamp : LOG   : Setting `$Boolean_Error and `$Resultcount 0."
        }
        ##Writing result to PRTG
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        Try {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($Channel.Channel) -Value $ResultCount
            Write-Verbose "$Timestamp : LOG   : Writing resultcount $ResultCount to Channel $($Channel.Channel)."
        } Catch {
            $Boolean_Error = $True
            Write-Error "$Timestamp : ERROR : Could not write resultcount $ResultCount to Channel $($Channel.Name)."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        }
        ##Determining ErrorStatus
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Error -eq $False) {
            If (
                ( ($ResultCount -gt $Channel.LimitMaxError) -and ($null -ne $Channel.LimitMaxError) ) -or 
                ( ($ResultCount -lt $Channel.LimitMinError) -and ($null -ne $Channel.LimitMinError) )
            ) {
                    $Boolean_Error   = $True
                    $Boolean_Warning = $True
                    Write-verbose "$Timestamp : LOG   : Detected ERROR in query $Query."
                    Write-verbose "$Timestamp : LOG   : Determining to use custom error message."
                    If ($Boolean_CustomError -eq $True) {
                        $Output_Message   = "$CustomErrorMessage : $Username_first_result ($ResultCount)"
                    } Else {
                        $Output_Message   = "User: $Username_first_result returned in `"$($Channel.channel)`" ($ResultCount)"
                    }
            }
        } 
        If ($Boolean_Warning -eq $False) {
            If (
                ( ($ResultCount -gt $Channel.LimitMaxWarning) -and ($null -ne $Channel.LimitMaxWarning) ) -or 
                ( ($ResultCount -lt $Channel.LimitMinWarning) -and ($null -ne $Channel.LimitMinWarning) )
            ) {
                $Boolean_Warning = $True
                Write-verbose "$Timestamp : LOG   : Detected WARNING in query $Query."
                If ($Boolean_CustomWarning -eq $True) {
                    $Output_Message   = "$CustomWarningMessage : $Username_first_result ($ResultCount)"
                } Else {
                    $Output_Message   = "User: $Username_first_result returned in `"$($Channel.Channel)`" ($ResultCount)"
                }
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