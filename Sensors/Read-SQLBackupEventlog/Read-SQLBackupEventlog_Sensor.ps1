<#
.SYNOPSIS 
PRTG-Sensor for reading Eventlogs for the backupstatus of a SQL backup.

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will read the eventlog on a remote
SQL Server, with a query asking for the Events concerning the backup of databases. It
will return for each DB listed in the configuration-XML whether the backup was successfull.

For this, it will return the following values:
0 - No backup found (Warning state)
1 - Last event detected was Log Backup Successfull
2 - Last event detected was Backup Successfull
3 - Last event detected was Differential Backup Successfull
4 - Error: Backup failed

This sensor uses an Invoke-Command, and is not ment to query the local server the probe
is running on. Don't install the PRTG-probe on a SQL server. Just don't.

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER Computer
Mandatory parameter giving the name of the remote computer the SQL is running on.

.PARAMETER Hours
Optional parameter for how many hours the sensor should look back for. Default is 24 hours.

.PARAMETER Username
Optional parameter, for defining the name of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string in a domain\accountname format.

.PARAMETER Password
Optional parameter, for defining the password of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string value, ment to be used with %windowspassword (PRTG variable).

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       read-SQLBackupEventlog_Sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\read-SQLBackupEventlog_ChannelConfiguration.xml" -Computer "plugge-fs01.plugge-d.local" '
- Enviroment:       personal preference
- Security context: personal preference
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. The backup probably only runs once a day.

Script can be run locally for test-purposes via
.\Read-SQLBackupEventlog.ps1 -Filename "\\Server.domain.local\share\folder\read-SQLBackupEventlog_ChannelConfiguration.xml" -Computer "plugge-fs01.plugge-d.local"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 18.08.2019: Initial upload 
Version 1.2 / 14.11.2021: Moved functions to PRTG Module
Version 2.1 / 10.07.2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1)][String]$Filename,
        [Parameter(Mandatory=$true, Position=2)][String]$Computer,
        [Parameter(Mandatory=$false,Position=3)][Int]   $Hours=24,
        [Parameter(Mandatory=$false,Position=4)][String]$Username,
        [Parameter(Mandatory=$false,Position=5)][String]$Password
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[Boolean]  $Boolean_Skip    = $False
[Boolean]  $Boolean_Cred    = $False

[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $LocalComputer   = $($Env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK (0=No backup found, 1=Last event: logbackup, 2=Last event: backup, 3=Last event: diff.backup, 4=SQLbackup failed)"

[String]   $Eventlog        = 'Application'
[String]   $Source          = 'MSSQLSERVER'
[Array]    $EventID         = @(3041,18264,18265,18270)
[String]   $TimeFrame       = ( (Get-date).AddHours(-1 * $Hours ) ).toString('yyyy-MM-ddThh:mm:ss.000Z')

[XML]      $Configuration   = $null

[String] $Query = @"
*   [System[TimeCreated [@SystemTime > '$Timeframe']]]
    [System[Provider    [@Name       = '$Source'   ]]]
    [System[EventID = '$($EventID[0])' or EventID = '$($EventID[1])' or EventID = '$($EventID[2])' or EventID = '$($EventID[3])']]
"@

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
            Write-Verbose   "$Timestamp : LOG   : Credentialobject build on username $Username."
    } Catch {
            Write-Error     "$Timestamp : ERROR : Could not build credential object."
            Write-Error     "$Timestamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not build credential object."
            $Boolean_Exit = $True 
    }
}
$Username = $null
$Password = $null

## Importing configuration-files
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try {
        [XML] $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose          "$Timestamp : LOG   : Imported Channel configuration from XML."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not import configuration from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"      
        $Output_Message = "Could not import configuration from XML."     
        $Boolean_Exit   = $True
    }
}

## Invoking query to remote computer
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $true) {
        Try {
            $Events = Get-PRTGClientEventlog -Computer $Computer -Eventlog $Eventlog -Query $Query -Credential $Credential
            Write-Verbose "$Timestamp : LOG   : Collected Events from computer $Computer w/ creds ($($Events.Count))."
        } Catch {
            Write-Error "$Timestamp : ERROR : Could not collect Events from computer $Computer w/ creds."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"  
            $Output_Message = "Could not collect Events from computer $Computer w/ creds."           
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Events = Get-PRTGClientEventlog -Computer $Computer -Eventlog $Eventlog -Query $Query
            Write-Verbose "$Timestamp : LOG   : Collected Events from computer $Computer ($($Events.Count))."
        } Catch {
            Write-Error "$Timestamp : ERROR : Could not collect Events from computer $Computer."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)" 
            $Output_Message = "Could not collect Events from computer $Computer."            
            $Boolean_Exit = $True
        }        
    }
}

## Looping through channels
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Write-Verbose "$TimeStamp : LOG   : Looping through ChannelConfiguration."
    Foreach ($Channel in $($Configuration.prtg.result)) {
        [Array]   $Selected_Events = @()
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        [Boolean] $Boolean_Skip    = $False
        [Int]     $ReturnValue     = 0
        Write-Verbose "$TimeStamp : LOG   : Using channel $($Channel.Channel)."

        ##Collecting events for this computer from Events Array
        [String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $False) {
            Try {
                $Selected_Events = $Events.Events | Where-Object -FilterScript {$_.Message -like "*$($Channel.Channel)*"} | Sort-object -Property TimeCreated -Descending
                Write-Verbose      "$Timestamp : LOG   : Selected Events from db $($Channel.Channel) ($($Selected_Events.Count))."
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not collect Events from computer $Computer."
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)" 
                $Output_Message = "Could not collect Events from computer $Computer."          
                $Boolean_Skip    = $True
            }
        }

        ## Evaluating
        [String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Skip -eq $False) {        
            If ( $($Selected_Events).Count -eq 0 ) {
                $ReturnValue = 0
                Write-Verbose "$Timestamp : LOG   : Returning $ReturnValue (1)."
                If ($Boolean_Warning -eq $False) {
                    Write-Verbose "$Timestamp : LOG   : No events found. Prompting 'No Backup found' as Warningmessage."
                    $Output_Message = "No SQL-Backupevents found."
                }
                $Boolean_Warning = $true
            } ElseIf ($Selected_Events[0] -eq $EventID[0]) {
                $ReturnValue = 4
                Write-Verbose "$Timestamp : LOG   : Returning $ReturnValue (2)."
                If ($Boolean_Error -eq $False) {
                    Write-Verbose "$Timestamp : LOG   : ErrorEvent found. Prompting 'SQL-Backup failed on db $($Channel.Channel)'."
                    $Output_Message = "SQL-Backup failed on db $($Channel.Channel)"
                }
                $Boolean_Error   = $True
                $Boolean_Warning = $true
            } ElseIf ($($Selected_Events[0].id) -eq $EventID[1]) {
                $ReturnValue = 1
                Write-Verbose "$Timestamp : LOG   : Returning $ReturnValue (3)."
            } ElseIf ($($Selected_Events[0].id) -eq $EventID[2]) {
                $ReturnValue = 2
                Write-Verbose "$Timestamp : LOG   : Returning $ReturnValue (4)."
            } ElseIf ($($Selected_Events[0].id) -eq $EventID[3]) {
                $ReturnValue = 3
                Write-Verbose "$Timestamp : LOG   : Returning $ReturnValue (5)."
            } Else {
                Write-Verbose "$Timestamp : ERROR : Unexpected result, prompting errror"
                $Boolean_Skip = $true
            }
        }

        ##Writing value to PRTG-Channel
        [String] $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( $Boolean_Skip -eq $False ) {
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($Channel.Channel)  -Value $ReturnValue
                Write-Verbose "$Timestamp : LOG   : Written value $ReturnValue to Channel $($Channel.Channel)."
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not write to channel $($Channel.Channel)."
                Write-Error "$Timestamp : ERROR : $($_.Exception.Message)."
                $Output_Message = "Could not write to channel $($Channel.Channel)."
                $Boolean_Skip  = $True
            }
        }
        If ($Boolean_Skip -eq $True) { $Boolean_Exit -eq $True }
    }
}        

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml