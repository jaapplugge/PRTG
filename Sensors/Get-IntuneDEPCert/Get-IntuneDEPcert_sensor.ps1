<#
.SYNOPSIS
PRTG-Sensor for calling the MS Graph API to collect the Apple DEP certificate

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to the Graph API, published as an application in 
Azure, and calls this API with a query for the Apple DEP token. This certificate is used to authenticate new phones to 
the Intuneportal, and will expire every year.

Other channels will show the number of days since last sync, and the number of iPhones connected.

For connecting, an application must be available on Azure for the Graph API. On this sensor, the connection to 
this api is secured by a shared secret.

.PARAMETER TennantID
Mandatory parameter for the TennantID of the GraphAPI to call. This is a string value, and can be passed trough via 
'%WindowsDomain' (PRTG variable).

.PARAMETER ClientID
Mandatory parameter for the ClientID of the GraphAPI-application to call. This is a string value, and can be passed trough via 
'%WindowsUsername' (PRTG variable).

.PARAMETER SharedSecret
Mandatory parameter of SharedSecret of this application. This is a string value, and can be passed trough via 
'%WindowsPassword' (PRTG variable).

.PARAMETER Filename
Mandatory parameter of the XML formatted configuration file.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-IntuneDEPcert_sensor.ps1
- Parameters:       -TennantID %WindowsDomain -ClientID %WindowsUser -SharedSecret %WindowsPassword -Filename 'C:\Scripting\Configurations\Get-IntuneDEPcert_channelconfiguration.xml'
- Enviroment:       personal preference
- Security context: Windows Credentials
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. Running this sensor every 24 hours will be more than enough.

Script can be run locally for test-purposes via
.\Get-IntuneDEPcert_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-IntuneDEPcert_channelconfiguration.xml" -ClientID $ClientID -SharedSecret $Password -TennantID $TennantID

.NOTES
This script is written by Jaap Plugge, Σ OGD, 
Version 1.0 / 02-02-2020: Initial upload 
Version 2.0 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $TenantID,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $ClientID,
        [Parameter(Mandatory=$True ,Position=3)] [String]  $SharedSecret,
        [Parameter(Mandatory=$True ,Position=4)] [String]  $Filename
)

## Variables
[Boolean]   $Boolean_Exit    = $False
[String]    $Output_Message  = $null
[String]    $Token           = $null
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[XML]       $Configuration   = $null

[Int]       $WarningValue    = 0
[Int]       $ErrorValue      = 0
[String]    $Query_String    = $null
[String]    $Query_AppleID   = $null
[String]    $Query_Version   = $null
[PSObject]  $DEP_token       = $null
[PSObject]  $DEP_Object      = $null
[DateTime]  $DEP_ExpirationDate = Get-date 0
[String]    $DEP_tokenName      = $null
[Int]       $DEP_SyncedDevices  = 0
[DateTime]  $DEP_LastSyncDate   = Get-date 0
[Int]       $Channel_DaysUntilExpiration = 0
[Int]       $Channel_DaysSinceLastSync   = 0
[Int]       $Channel_SyncedDevices       = 0

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
        $Configuration        = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $WarningValue         = ($Configuration.prtg.result | Where-Object { $_.Channel -eq "Days until expiration" }).LimitMinWarning
        $ErrorValue           = ($Configuration.prtg.result | Where-Object { $_.Channel -eq "Days until expiration" }).LimitMinError
        $Query_String         = $Configuration.prtg.query.query
        $Query_AppleID        = $Configuration.prtg.query.appleid
        $Query_Version        = $Configuration.prtg.query.version
        Write-Verbose           "$Timestamp : LOG   : Imported configuration."
        Write-Verbose           "$TimeStamp : LOG   : Warning value: $WarningValue"
        Write-Verbose           "$TimeStamp : LOG   : Error value:   $ErrorValue"
        Write-Verbose           "$TimeStamp : LOG   : Query:         $Query_String ($Query_version)"
        Write-Verbose           "$TimeStamp : LOG   : AppleID:       $Query_AppleID"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit         = $True
    }
}

## Collecting Graph API Token
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Token        = Get-PRTGGraphApiToken -Secret $SharedSecret -ClientID $clientId -TenantID $tenantId
        Write-Verbose   "$Timestamp : LOG   : Collected token starting with $($Token.SubString(0,8))"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect token."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect token."
        $Boolean_Exit = $True
    }
}

## Collecting DEP token
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        Write-Verbose         "$TimeStamp : LOG   : Collecting DEP-Token ($Query_String)"
        $DEP_token          = Invoke-PRTGGraphApiCall -Token $Token -Query $Query_String -Version $Query_Version 
        Write-Verbose         "$TimeStamp : LOG   : Collected DEPtoken $($DEP_token) " 
        $DEP_Object         = $DEP_token.value | Where-Object -FilterScript { $_.appleIdentifier -eq $Query_AppleID } 
        Write-Verbose         "$TimeStamp : LOG   : Collecting DEP-Object ($($DEP_Object)"
        $DEP_ExpirationDate = [datetime]::parse($($DEP_Object.tokenExpirationDateTime))
        Write-Verbose         "$TimeStamp : LOG   : Collecting DEP-Object ($($DEP_Object.tokenExpirationDateTime)"
        $DEP_tokenName      = $DEP_Object.tokenName
        $DEP_SyncedDevices  = $DEP_Object.syncedDeviceCount
        $DEP_LastSyncDate   = [datetime]::parse( $($DEP_Object.lastSuccessfulSyncDateTime) )
        $Channel_DaysUntilExpiration = ($DEP_ExpirationDate - (Get-Date)).Days
        $Channel_DaysSinceLastSync   = ( (Get-Date) - $DEP_LastSyncDate ).Days
        Write-Verbose         "$timeStamp : LOG   : Collected DEPtoken for AppleID $AppleID"
        Write-Verbose         "$timeStamp : LOG   : Certificate $DEP_Tokenname will expire $DEP_ExpirationDate"
        Write-Verbose         "$Timestamp : LOG   : Last Sync: $Dep_LastSyncdate ($Dep_SyncedDevices devices)"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect DEP token via GraphApi."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect DEP token via GraphApi."
        $Boolean_Exit       = $True        
    }
}

## Writing to PRTG
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Days until expiration" -Value $Channel_DaysUntilExpiration
        Write-Verbose    "$Timestamp : LOG   : Written value $Channel_DaysUntilExpiration to Channel 'Days until expiration'."
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Days since last sync" -Value $Channel_DaysSinceLastSync
        Write-Verbose    "$Timestamp : LOG   : Written value $Channel_DaysSinceLastSync to Channel 'Days since last sync'."
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Synced devices" -Value $Channel_SyncedDevices
        Write-Verbose    "$Timestamp : LOG   : Written value $Channel_SyncedDevices to Channel 'Synced devices'."
    } Catch {
        Write-Error      "$Timestamp : ERROR : Could not write to PRTG channel."
        Write-Error      "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to PRTG channel."
        $Boolean_Exit  = $True
    }
} 
                
##Determining ErrorStatus
[String]  $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_Exit -eq $False) -and ($Channel_DaysUntilExpiration -lt $ErrorValue) ) {
    Write-verbose      "$Timestamp : LOG   : Detected ERROR in query $Query. `n"
    $Output_Message  = "Certificate $DEP_tokenName will expire in $Channel_DaysUntilExpiration days ($DEP_ExpirationDate)"
} ElseIf ( ($Boolean_Exit -eq $False) -and ($Channel_DaysUntilExpiration -lt $WarningValue) ) {
    Write-verbose      "$Timestamp : LOG   : Detected ERROR in query $Query. `n"
    $Output_Message  = "Certificate $DEP_tokenName will expire in $Channel_DaysUntilExpiration days ($DEP_ExpirationDate)"
} ElseIf ($Boolean_Exit -eq $False) {
    Write-Verbose     "$TimeStamp : LOG   : No errors found"
    $Output_Message = "$DEP_tokenName Last Sync: $DEP_LastSyncDate for $DEP_SyncedDevices. Cert valid until $DEP_ExpirationDate"
} Else {
    $Configuration.prtg.error = '2'
    Write-Verbose     "$TimeStamp : LOG   : PRTG sensor in ErrorState"
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml