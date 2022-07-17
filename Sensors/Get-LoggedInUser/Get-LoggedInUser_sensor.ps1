<#
.SYNOPSIS
PRTG-Sensor for checking if a specific user is logged in on a series of computers.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will check if a certain user is logged in on one or more computers.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Username
Optional parameter, for defining the name of the useraccount to use for connecting. Can be used if the server to check
is in another domain as the probeserver. Expects a string in a domain\accountname format.

.PARAMETER Password
Optional parameter, for defining the password of the useraccount to use for connecting. Can be used if the server to check
is in another domain as the probeserver. Expects a string value, ment to be used with %windowspassword (PRTG variable).

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-LoggedInUser_sensor.ps1
- Parameters:       -Filename 'C:\Scripting\Configurations\Get-LoggedInUser_channelConfiguration.xml' -username "%Windowsuser" -password "%windowspassword"
- Enviroment:       personal preference
- Security context: a serviceaccount with remote control rights on the receiving client
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. 
                    This sensor is not ment to be ran frequently; try to limit its use to a couple of times a day.

Script can be run locally for test-purposes via
.\Get-LoggedInUser_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-LoggedInUser_channelconfiguration.xml" -Username "adm_plugge" -Password 'Welkom123'                    

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 11.08.2019: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True, Position=1 )] [String] $Filename,
        [Parameter(Mandatory=$False,Position=2)] [String]  $Username = $null,
        [Parameter(Mandatory=$False,Position=3)] [String]  $Password = $null 
)

## Variables
[Boolean]   $Boolean_Exit    = $False
[Boolean]   $Boolean_Error   = $False
[Boolean]   $Boolean_Cred    = $False
[String]    $Output_Message  = 'OK'
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[Array]     $Servers         = @()

## Query
[String] $Query_p  = "SELECT Name FROM Win32_Process WHERE Name = 'LogonUI.exe'"

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
        $Boolean_Exit  = $True
    }
}

##Checking if Creds are given
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ( ($Username -eq "") -or ($null -eq $Username) ) {
        Write-Verbose "$TimeStamp : LOG   : Using context creds."
        $Boolean_Cred = $False
    } Else {
        $Boolean_Cred = $True
        Write-Verbose "$TimeStamp : LOG   : Creds provided, using.."
        ##Building credential-object
        Try {
            $SecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $Credential   = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecureString
            Write-Verbose   "$Timestamp : LOG   : Credentialobject build on username $Username."
        } Catch {
            Write-Error     "$Timestamp : ERROR : Could not build credential object."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Exit = $True 
        }
    }
}
$SecureString = $null
$Username     = $null
$Password     = $null

##Running both queries against a computer
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($Server in $Servers) {
        ##Variable
        [String] $Currentuser = $null
        [Int]    $ReturnValue = $null
        [String] $Account     = $null

        Write-verbose "$TimeStamp : LOG   : Using server $Server"

        ##Collecting account from ChannelConfiguration
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        Try {
            $Account     = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $Server}).Account
            $Query_cu    = "SELECT Username FROM Win32_ComputerSystem WHERE Username LIKE '%$Account'"
            Write-Verbose "$TimeStamp : LOG   : Collected username $Account from ConfigurationFile."
            Write-Verbose "$TimeStamp : LOG   : Query : $Query_CU."
        } Catch {
            $Boolean_Exit = $True
            Write-Error     "$TimeStamp : ERROR : Not successfull in collecting $Account."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
        }

        ##Running Queries
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Exit -eq $False) -and ($Boolean_Cred -eq $True) ) {
            Try {
                Write-verbose   "$TimeStamp : LOG   : Running query $Query_CU against server $server w/ cred."
                $Currentuser  = (get-wmiobject -ComputerName $Server -query $Query_CU -Credential $Credential -erroraction silentlycontinue -WarningAction SilentlyContinue).Username
                Write-Verbose   "$timeStamp : LOG   : Result : $CurrentUser"
            } Catch {
                $Boolean_Exit = $True
                Write-Error     "$TimeStamp : ERROR : Not successfull in querying server $Server w/ cred."
                Write-Error     "$TimeStamp : ERROR : Query : $Query_CU."
                Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
            }
            Try {
                Write-verbose   "$TimeStamp : LOG   : Running query $Query_p against server $server w/ cred."
                $Process      = (get-wmiobject -ComputerName $Server -query $Query_p -Credential $Credential -erroraction silentlycontinue -WarningAction SilentlyContinue).Name
                Write-Verbose   "$timeStamp : LOG   : Result : $Process"
            } Catch {
                $Boolean_Exit = $True
                Write-Error     "$TimeStamp : ERROR : Not successfull in querying server $Server w/ cred."
                Write-Error     "$TimeStamp : ERROR : Query : $Query_P."
                Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."                              
            }
        } Elseif ($Boolean_Exit -eq $False) {
            Try {
                Write-verbose   "$TimeStamp : LOG   : Running query $Query_CU against server $server"
                $Currentuser  = (get-wmiobject -ComputerName $Server -query $Query_CU -erroraction silentlycontinue -WarningAction SilentlyContinue).Username
                Write-Verbose   "$timeStamp : LOG   : Result : $CurrentUser"
            } Catch {
                $Boolean_Exit = $True
                Write-Error     "$TimeStamp : ERROR : Not successfull in querying server $Server."
                Write-Error     "$TimeStamp : ERROR : Query : $Query_CU."
                Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
            }
            Try {
                Write-verbose   "$TimeStamp : LOG   : Running query $Query_p against server $server"
                $Process      = (get-wmiobject -ComputerName $Server -query $Query_p -erroraction silentlycontinue -WarningAction SilentlyContinue).Name
                Write-Verbose   "$timeStamp : LOG   : Result : $Process"
            } Catch {
                $Boolean_Exit = $True
                Write-Error     "$TimeStamp : ERROR : Not successfull in querying server $Server."
                Write-Error     "$TimeStamp : ERROR : Query : $Query_P."
                Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."                              
            }                              
        }

        ##Evaluating
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) {
            If ( ($Currentuser -eq "") -or ($null -eq $Currentuser) ) {
                $ReturnValue    = 1
                Write-verbose    "$TimeStamp : LOG   : Writing value 1"
                If ($Boolean_Error -eq $False) {
                    $Output_Message  = "Account $Account not logged in on pc $Server, Please investigate!"
                    $Boolean_Error  = $True
                    Write-Verbose    "$TimeStamp : LOG   : Detected 'No user logged in on pc $Server, Please investigate!'"
                }
            } ElseIf ( !(($Process -eq "") -or ($null -eq $Process)) ) {
                $ReturnValue    = 2
                Write-verbose    "$TimeStamp : LOG   : Writing value 2" 
                If ($Boolean_Error -eq $False) {
                    $Output_Message = "No user has interactive session, Please investigate!"
                    $Boolean_Error  = $True
                    Write-Verbose    "$TimeStamp : LOG   : Detected 'No user has interactive session, Please investigate!'"
                }
            }
        }

        ##Writing to Channel with the same name in PRTG-XML
        If ($Boolean_Exit -eq $False) {
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Server -Value $ReturnValue
                Write-Verbose    "$TimeStamp : LOG   : Written result to Configuration ($Server / $ReturnValue)"
            } Catch {
                $Boolean_Exit    = $True
                $Boolean_Error   = $True
                Write-Verbose    "$TimeStamp : ERROR : Could not write result to Configuration ($Server / $ReturnValue)"
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