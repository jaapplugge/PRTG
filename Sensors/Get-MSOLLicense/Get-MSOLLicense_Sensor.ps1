<#
.SYNOPSIS
PRTG-Sensor for checking license status for MS Office 365 licenses. 

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It loads the MSOnline module, and connect to MS Online.
It will collect all licenses available on the tennant. For every license, the script will check whether a matching 
ChannelConfiguration is given, and if so, it will list the total number of licenses, the number of licenses available,
and the number of licenses in warning state.
If the number of free licenses is lower than given minimum, it will show a warning. If licenses are in warning, it will
prompt an error. 

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Username
Mandatory parameter for giving the username of the account used to connect to MSOnline.
Username is expected as <username>@<mailsuffix>, e.g. SA_Prtg_MSOL@plugged.onmicrosoft.com.

.PARAMETER Password
Mandatory parameter for giving the password of this account, which can be entered as %Windowspassword.

.PARAMETER Prefix
Mandatory parameter for defining the prefix of the licensename. E.g. the VISIO PRO license of PLUGGED.nl is named
'plugged:VISIOPROFESSIONAL'. This parameter would expect 'plugged:'

.PARAMETER Suffix_total
Optional parameter for defining the Suffix as used in the channelconfigurations' name. Default value is
' - Licenties totaal'.

.PARAMETER Suffix_free
Optional parameter for defining the Suffix as used in the channelconfigurations' name. Default value is
' - Licenties vrij'.

.PARAMETER Suffix_warning
Optional parameter for defining the Suffix as used in the channelconfigurations' name. Default value is
' - Licenties in warning'.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-MSOLLicence_Sensor.ps1
- Parameters:       -Filename 'C:\Scripting\Configurations\Get-MSOLLicence_Configuration.xml' -Username 'sa_PRTG_MSOL@plugged.nl' -Password %Windowspassword -Prefix 'plugged:'
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

Script can be run locally for test-purposes via
.\Get-MSOLLicence_Sensor.ps1 -Filename "c:\scripting\Get-MSOLLicence_Configuration.xml" -Username 'sa_PRTG_MSOL@plugged.nl' -Password 'Welkom123' -Prefix 'plugged:

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 06-08-2018: Initial upload 
Version 1.1 / 18-11-2019: moved to ADO
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.0 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
    [Parameter(Mandatory=$True,Position=1)] [String] $Filename,
    [Parameter(Mandatory=$True,Position=2)] [String] $Username,
    [Parameter(Mandatory=$True,Position=3)] [String] $Password,
    [Parameter(Mandatory=$True,Position=4)] [String] $Prefix
)
## Variables
[Boolean] $Boolean_Exit    = $False
[Boolean] $Boolean_Error   = $False
[Boolean] $Boolean_Warning = $False
[Boolean] $Boolean_unknown = $False
[Boolean] $Boolean_firstunknown = $False
  
[String]  $Command         = $MyInvocation.MyCommand.Name
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]  $Output_Message  = "OK"
If ($Prefix -notlike "*:") {$Prefix = $Prefix + ':'}
[Array]   $All_Licenses    = @()

Write-Verbose "SENSOR:$Command"
Write-Verbose $("_" * 120)
Write-Verbose "$Timestamp : LOG   : Username: $env:username"
Write-Verbose "$Timestamp : LOG   : Session : $( ([System.IntPtr]::Size)*8 )bit Session"

## Import the ChannelConfiguration
# If this step fails, sensor will prompt error:
# 'XML: The returned XML does not match the expected schema. (code: PE233) 
# JSON: The returned JSON does not match the expected structure (Invalid JSON.). (code: PE231)'

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

## Importing configuration-files
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
Try {
    [XML] $Configuration    = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
    Write-Verbose "$Timestamp : LOG   : Imported Channel configuration from XML."
} Catch {
    Write-Error "$Timestamp : ERROR : Could not import Channel configuration from XML or Json."
    Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
    $Output_Message = "Could not import ChannelConfiguration"
    $Boolean_Exit = $True
}

## Import the MS Online module
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_Exit -eq $False) -and !(Get-Module -Name MSOnline) ) {
    Write-Verbose "$TimeStamp : LOG   : Trying to import the MSOnline module."
    Try {
        Import-Module -Name MSOnline
        Write-Verbose "$Timestamp : LOG   : Import-Module -Name MSOnline succesfull."
    } Catch {
        Write-Error "$Timestamp : ERROR : Import-Module -Name MSOnline NOT succesfull."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not import MSOnline module"        
        $Boolean_Exit   = $True      
    }
}

##Connecting to MS Online
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_Exit -eq $False) -and ($null -eq (Get-MSOLDomain -ErrorAction silentlycontinue -WarningAction SilentlyContinue)) ) {
    ##Building credential-object
    Try {
        $SecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $Credential   = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecureString
        Write-Verbose "$Timestamp : LOG   : Credentialobject build on username $Username."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not build credential object."         
        $Boolean_Exit = $True 
    }
    ##Connecting to MSOL
    Try {
        Connect-MsolService -Credential $Credential #-ErrorAction silentlycontinue
        Write-Verbose "$Timestamp : LOG   : Connect-MsolService succesfull"
    } Catch {
        $Boolean_Exit = $True
        Write-Error "$Timestamp : ERROR : Connect-MsolService NOT succesfull"
        $Output_Message = "Connect-MsolService NOT succesfull."         
    }
    ##Clearing Password variables
    $Password     = $null
    $Securestring = $null
    $Credential   = $null
}

## Check if connection is made
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    If ( $null -eq (Get-MSOLDomain -ErrorAction silentlycontinue)) {
        $Boolean_Exit = $True
        Write-Error "$Timestamp : ERROR : Connection to MSOL not verified. If persists, run script manually once."
        $Output_Message = "Connection to MSOL not verified. If persists, run script manually once."
    } Else {
        Write-Verbose "$Timestamp : LOG   : Connection to MSOL verified."
    }
}

##Collecting Licenses 
[String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Try {
        $All_Licenses = Get-MsolAccountSku
        Write-Verbose "$timeStamp : LOG   : Collected all licenses in the tennant."
    } Catch {
        $Boolean_Exit = $True
        Write-Error "$Timestamp : ERROR : Could not collect all licenses in the tennant."
        $Output_Message = "Could not collect all licenses in the tennant."
    }
}

##Looping through the configurations
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($License in $All_Licenses) {
        [Boolean] $Boolean_Skip   = $False
        $License_Name_Total   = ($License.AccountskuID).replace("$Prefix",'').replace("_",' ') + ' - Total licenses'
        $License_Total        = $($License.ActiveUnits)
        $License_Name_Free    = ($License.AccountskuID).replace("$Prefix",'').replace("_",' ') + ' - Free licenses'
        $License_Free         = $( ($License.ActiveUnits) - ($License.ConsumedUnits) - ($License.WarningUnits) )
        Write-Verbose "$Timestamp : LOG   : Using license $($License.AccountskuID) / $License_Name_Total."               

        ##Checking if Channel exists
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        [Array]   $Channels = $Configuration.PRTG.result 
        [Boolean] $Boolean_unknown = $True
        Foreach ($Channel in $Channels) {
            If ($channel.Channel -eq $License_Name_Total) {
                Write-Verbose "$Timestamp : LOG   : Detected license $($License.AccountskuID)."
                $Boolean_unknown = $False
            }
        }
            
        If ($Boolean_unknown -eq $True) {
            Write-Verbose "$Timestamp : LOG   : Detected unknown license $($License.AccountskuID)."
            $Boolean_Skip   = $True
            If ($Boolean_firstunknown -eq $False) {
                Write-Verbose "$Timestamp : LOG   : Prompt in messagefield if status is ok."
                $Output_Message = "Detected unknown license $($License.AccountskuID)."
            }
            $Boolean_unknown = $True
        } 
            
        ##Writing result in Channel
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( $Boolean_Skip -eq $False ) {
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $License_Name_Total  -Value $License_Total
                Write-Verbose "$Timestamp : LOG   : Written value $License_Free to Channel $License_Name_Free."
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $License_Name_Free   -Value $License_Free
                Write-Verbose "$Timestamp : LOG   : Written value $License_Total to Channel $License_Name_Total."
            } Catch {
                Write-Error "$Timestamp : ERROR : Could not write to channel $License_Name."
                $Output_Message = "Could not write to channel $License_Name.."
                $Boolean_Skip    = $True
                $Boolean_Exit    = $True
            }
        } 
            
        ##Determining ErrorStatus
        [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Skip -eq $False) -and ($Boolean_Error -eq $False) ){
            If ( ( $($License.WarningUnits) -gt 0 ) ) {
                $Boolean_Error   = $True
                $Boolean_Warning = $True
                Write-verbose      "$Timestamp : LOG   : Detected ERROR in query $Query."
                $Output_Message  = "License $($License.AccountSkuID) returned $($License.Warningunits) licenses in Warning."
            }
        } 
        If ( ($Boolean_Skip -eq $False) -and ($Boolean_Warning -eq $False) ) {
            If ( $( ($License.ActiveUnits) - ($License.ConsumedUnits) ) -lt ($Configuration.prtg.result.$Name_Licenses_Free.LimitMinWarning) ) {
                $Boolean_Warning = $True
                Write-verbose      "$Timestamp : LOG   : Detected WARNING in query $Query."
                $Output_Message  = "License $($License.AccountSkuID) only $( ($License.ActiveUnits) - ($License.ConsumedUnits) ) licenses available."
            }
        }
    }
}

If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml