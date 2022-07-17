<#
.SYNOPSIS
PRTG-Sensor for calling the MS Graph Api to collect the Apple Push Notification Certificate

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to the Graph API, published as an application in 
Azure, and calls this api with a query for the Apple Push Notification Certificate. This certificate is used  
connect to the phones from the Intuneportal and push settings, applications. It will expire every year.

For connecting, the an application must be available on Azure for the Graph Api. For this sensor, this api is
secured by a shared secret.

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
- EXE/Script:       Get-IntuneApplePushcert_sensor.ps1
- Parameters:       -TennantID %WindowsDomain -ClientID %WindowsUser -SharedSecret %WindowsPassword -Filename 'C:\Scripting\Configurations\Get-IntuneApplePushcert_channelconfiguration.xml'
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
.\Get-IntuneApplePushcert_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-IntuneApplePushcert_channelconfiguration.xml" -ClientID $ClientID -SharedSecret $Password -TennantID $TennantID

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten
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
[Int]       $Channel_DaysUntilExpiration = 0
[DateTime]  $AP_ExpirationDate = Get-date 0
[String]    $AP_AppleID        = $null
[PSObject]  $AP_return         = $null

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
        $Query_Version        = $Configuration.prtg.query.version
        Write-Verbose           "$Timestamp : LOG   : Imported configuration."
        Write-Verbose           "$TimeStamp : LOG   : Warning value: $WarningValue"
        Write-Verbose           "$TimeStamp : LOG   : Error value:   $ErrorValue"
        Write-Verbose           "$TimeStamp : LOG   : Query:         $Query_String"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

## Collecting Graph API Token
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Token        = Get-PRTGGraphApiToken -Secret $SharedSecret -ClientID $clientId -TenantID $tenantId
        Write-Verbose   "$Timestamp : LOG   : Collected token starting with $($Token.SubString(0,8))"
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect token."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect token."
        $Boolean_Exit = $True
    }
}

## Collecting Apple Push Certificate
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        Write-Verbose         "$TimeStamp : LOG   : Collecting Apple Push Certificate ($Query_String)"
        $AP_return          = Invoke-PRTGGraphApiCall -Token $Token -Query $Query_String -Version $Query_Version 
        Write-Verbose         "$TimeStamp : LOG   : Collected Apple Push object" 
        $AP_ExpirationDate  = [datetime]::parse( $($AP_return.expirationDateTime) )
        Write-Verbose         "$TimeStamp : LOG   : Collected Apple Push Date Time ($AP_ExpirationDate)" 
        $AP_AppleID         = $AP_return.appleIdentifier
        $Channel_DaysUntilExpiration = ($AP_ExpirationDate - (Get-Date)).Days
        Write-Verbose         "$timeStamp : LOG   : Collected ApplePush cert for AppleID $AP_AppleID"
        Write-Verbose         "$timeStamp : LOG   : Certificate will expire $AP_ExpirationDate"
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect Apple Push Cert via GraphApi."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect Apple Push Cert via GraphApi."
        $Boolean_Exit = $True        
    }
}

## Writing to PRTG
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Days until expiration" -Value $Channel_DaysUntilExpiration
        Write-Verbose    "$Timestamp : LOG   : Written value $Channel_DaysUntilExpiration to Channel 'Days until expiration'."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not write to channel."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not write to channel."
        $Boolean_Exit = $True
    }
} 
                
##Determining ErrorStatus
[String]  $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ( ($Boolean_Exit -eq $False) -and ($Channel_DaysUntilExpiration -lt $ErrorValue) ) {
    Write-verbose      "$Timestamp : LOG   : Detected ERROR in query $Query."
    $Output_Message  = "Certificate will expire in $Channel_DaysUntilExpiration days ($AP_ExpirationDate)"
} ElseIf ( ($Boolean_Exit -eq $False) -and ($Channel_DaysUntilExpiration -lt $WarningValue) ) {
    Write-verbose      "$Timestamp : LOG   : Detected ERROR in query $Query."
    $Output_Message  = "Certificate will expire in $Channel_DaysUntilExpiration days ($AP_ExpirationDate)"
} ElseIf ($Boolean_Exit -eq $False) {
    Write-Verbose     "$TimeStamp : LOG   : No errors found"
    $Output_Message = "Apple Push Cert for appleID $AP_AppleID will expire $AP_ExpirationDate"
} Else {
    $Configuration.prtg.error = '2'
    Write-Verbose     "$TimeStamp : LOG   : PRTG sensor in ErrorState"
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml