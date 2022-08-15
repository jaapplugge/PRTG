<#
.SYNOPSIS
PRTG-Sensor for checking the current status of a Config Manager Site

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects the Component Status.
I.e. this is the System Status page in Monitoring in the SCCM Console.

It will return the status of all site components as a single channel, with a value of 
GREEN(0)  - OK.       There are no warning or error messages.
YELLOW(1) - Warning.  Warning messages were generated, but not error messages.
RED(2)    - Critical. There are error messages.

By setting error-limits in PRTG, this can be used to prompt an error. As errortext, the script will use the
a description based on the first found error. If no error is found, it will show a description of the last found warning.

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Site
Mandatory parameter for the Sitecode of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-SCCMComponentStatus.ps1
- Parameters:       -SiteServer 'Sccm01.test.local' -Site 'test' -Configuration 'C:\Scripting\Configurations\Get-SCCMComponentStatus_ChannelConfiguration.xml'
- Enviroment:       personal preference
- Security context: a serviceaccount with the 'read-only analyst' role in SCCM
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
Version 1.0 / 07.11.2018: Initial upload 
Version 1.1 / 18.11.2019: moved to ADO
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://msdn.microsoft.com/en-us/library/cc144830.aspx
https://github.com/jaapplugge/PRTGModule
#>  

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True,Position=1)] [String] $Siteserver,
        [Parameter(Mandatory=$True,Position=2)] [String] $Filename,
        [Parameter(Mandatory=$False)] [String] $Username,
        [Parameter(Mandatory=$False)] [String] $Password
)

## Variables
[BOOLEAN]   $Boolean_Exit         = $False
[BOOLEAN]   $Boolean_text_Error   = $False
[BOOLEAN]   $Boolean_text_Warning = $False
[Boolean]   $Boolean_Cred         = $False
[STRING]    $Output_Message = $null
[STRING]    $Command        = $MyInvocation.MyCommand.Name
[ARRAY]     $Unique_Errors  = @()
[String]    $Timestamp      = Get-Date -format yyyy.MM.dd_hh:mm

## Query
[String] $Query = @"
Select 
        LastContacted, MachineName, ComponentName, Status 
From 
        SMS_ComponentSummarizer
"@

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
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Username -eq "") -or !($Username) ) {
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
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not build credential object."        
        $Boolean_Exit = $True 
    }
}
$SecureString = $null
$Username     = $null
$Password     = $null

## Importing configuration-file
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

##Collecting SCCM Sitecode
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ($Boolean_Cred -eq $True) {
        Try {        
            $site = Connect-PRTGtoSCCMforSiteCode -SiteServer $SiteServer -Credential $Credential
            Write-Verbose "$Timestamp : LOG   : Collected sitecode $Sitecode from siteserver $Siteserver w/ cred."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect sitecode from server $Siteserver w/ cred."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect sitecode from server $Siteserver w/ cred."
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $site = Connect-PRTGtoSCCMforSiteCode -SiteServer $SiteServer 
            Write-Verbose "$Timestamp : LOG   : Collected sitecode $Sitecode from siteserver $Siteserver."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect sitecode from server $Siteserver."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect sitecode from server $Siteserver."
            $Boolean_Exit = $True
        }
    }
}

##Collecting errormessages from SCCM-server
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $True) {
        Try {
            $Collected = Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver -Credential $Credential
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connect-toSCCMviaWMI w/ cred"
        } catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from server $Siteserver w/ cred."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from server $Siteserver w/ cred."
            $Boolean_Exit = $True                        
        }
    } Else {
        Try {
            $Collected = Connect-PRTGtoSCCMviaWMI -Query $Query -Site $site -SiteServer $Siteserver
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connect-toSCCMviaWMI w/ cred"
        } catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from server $Siteserver."
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Output_Message = "Could not collect data from server $Siteserver."
            $Boolean_Exit = $True                        
        }               
    }
    $Collected_Errors       = $Collected.Return
    $Count_Collected_Errors = $Count_Collected_Errors.Count
    $Collected_Errors       = $Collected_Errors | Sort-object -Property ComponentName,Status -Descending
    Write-Verbose "$Timestamp : LOG   : Imported and sorted $Count_Collected_Errors Errors from SCCM."
    Foreach ($Item in $ChannelConfiguration) {
        [String] $Channel_verbose = $null
        $Unique_Errors += ($Collected_Errors | Where-Object -FilterScript {$_.ComponentName -eq ($Item.Channel)} | Select-Object -first 1)
        $Channel_verbose = $Item.Channel
        Write-Verbose "$Timestamp : LOG   : Filtered unique error for channel $Channel_Verbose" 
    }
}

##Writing to XML
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($Item in $Unique_Errors) {
        $Unique_Channel = $Item.ComponentName
        $Unique_Status  = $Item.Status
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Unique_Channel -Value $Unique_Status
        Write-Verbose "$Timestamp : LOG   : Written result to PRTG XML for Channel "
        If ($Boolean_text_Error -eq $False) {
            If ($Item.Status -ge 2) {
                If ($Item.LastContacted) {
                    $Output_Message = ($Item.Componentname) + ' - ' + ($Item.MachineName) + ' - Component is in error since ' + ([Management.ManagementDateTimeConverter]::ToDateTime($Item.LastContacted)) 
                } Else { 
                    $Output_Message = ($Item.Componentname) + ' - ' + ($Item.MachineName) + ' - Component is in error since UNKNOWN'
                }
                $Boolean_text_error = $True
                Write-Verbose "$Timestamp : LOG   : Detected errorstatus $Unique_Status"
                Write-Verbose "$timeStamp : LOG   : $Output_Message"
            } Elseif ($Item.Status -eq 1) {
                If ($Item.LastContacted) {
                    $Output_Message = ($Item.ComponentName) + ' - ' + ($Item.MachineName) + ' - Component is in warning since ' + ([Management.ManagementDateTimeConverter]::ToDateTime($Item.LastContacted)) 
                } Else {
                    $Output_Message = ($Item.ComponentName) + ' - ' + ($Item.MachineName) + ' - Component is in warning since UNKNOWN'
                }
                $Boolean_text_warning = $true
                Write-Verbose "$Timestamp : LOG   : Detected warningstatus $Unique_Status"
                Write-Verbose "$timeStamp : LOG   : $Output_Message"
            }
        }
    }
    If ( ($Boolean_text_Error -eq $False) -and ($Boolean_text_warning -eq $False) ) {
        $Output_Message = 'No errors found'
        Write-Verbose "$timeStamp : LOG   : No errors found; writing all-is-safe."
    }
}

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = "2"
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml