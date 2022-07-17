<#
.SYNOPSIS
PRTG-Sensor for Collecting Dell Warranty status from the Dell TechApi

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will collect an accesstoken for the Dell
Technet v.5 API, and call for the warranty expirydate, of each device (defined as channel
in the channgelconfiguration-file). It will post warning and errormessages if the number
of days is less than given. 

The script can be configured to check for multiple servers in one go. PRTG's channelmax 
is 50 (but only in theory); Dell will support upto 100 servicetags in one go. So only
one sensor to check every server in prod. 

Devices can be defined by assettag or hostname, by using the switch $UseComputername

.PARAMETER Filename
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER ApiKey
Mandatory parameter for defining the API-key to be used. Expects a string value, ment 
to be used with %windowsusername (PRTG variable). 

.PARAMETER SharedSecret
Mandatory parameter for defining the SharedSecret to be used. Expects a string value, ment 
to be used with %windowspassword (PRTG variable). 

.PARAMETER UseComputername
Optional parameter, for displaying channels as hostname, not as assettag. If used, a parameter
<assettag> must be added to the XML configurationfile.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-DellWarranty_sensor.ps1
- Parameters:       '-Filename "\\Server.domain.local\share\folder\Get-DellWarranty_ChannelConfiguration.xml" -apikey "%windowsusername" -SharedSecret "%windowspassword"'
- Enviroment:       personal preference
- Security context: personal preference
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. 
                    Dell asks to not overload this api, and warranty does 
                    not change much. Ones a week will be enough.

Script can be run locally for test-purposes via
.\Get-DellWarranty_sensor.ps1 -Filename "\\Server.domain.local\share\folder\Get-DellWarranty_ChannelConfiguration.xml" -apikey "apikey" -sharedsecret "secret" -useComputername

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten
Version 1.0 / 28-12-2018: Initial Upload 
Version 1.1 / 17-06-2020: changed the 'select' for the enddate (Dell api changed)
Version 2.0 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True ,Position=1)] [String]  $Filename,
        [Parameter(Mandatory=$True ,Position=2)] [String]  $ApiKey,
        [Parameter(Mandatory=$True ,Position=3)] [String]  $SharedSecret,
        [Parameter(Mandatory=$False,Position=4)] [Switch]  $UseComputername
)

####################################################################################################### Script start
## Variables
[Boolean]   $Boolean_Exit    = $False
[Boolean]   $Boolean_Error   = $False
[Boolean]   $Boolean_Warning = $False
[Boolean]   $Boolean_Resolve = $False
If ($UseComputername) {$Boolean_Resolve = $True}

[Array]     $ServiceTagArray = @()
[Array]     $Return_Api      = @()
[Array]     $ChannelConfiguration = @()
[String]    $Token           = $null

[String]    $Output_Message  = "OK"
[String]    $Command         = $MyInvocation.MyCommand.Name
[String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[XML]       $Configuration   = $null

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

## Importing configuration-file
[String] $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration          = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $ChannelConfiguration   = $Configuration.prtg.result
        Write-Verbose             "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Boolean_Exit = $True
    }
}

##Calling REST-Api for Token
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Token = Get-DellAccessToken -ApiKey $ApiKey -SharedSecret $SharedSecret 
        Write-Verbose "$TimeStamp : LOG   : Collected accesstoken $Token."
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect accessToken with apikey $Apikey."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Boolean_Exit = $True          
    }
}
[String] $ApiKey       = $null
[String] $SharedSecret = $null

##Looping through the Channels to collect ServiceTags
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Foreach ($Item in $ChannelConfiguration) {
        If ($Boolean_Resolve -eq $True) {
            Write-Verbose "$TimeStamp : LOG   : Using Computername $($Item.Channel) and Assettag $($Item.Assettag)."
            $ServiceTagArray += $($Item.Assettag)
        } Else {
            $ServiceTagArray += $Item.Channel
            Write-Verbose "$TimeStamp : LOG   : Using Servicetag $($Item.Channel)."
        }
    }   
}

##Calling for data from rest-api
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Return_Api = Get-DellWarantyInfo -Token $Token -Assettags $ServiceTagArray
        Write-Verbose "$TimeStamp : LOG   : Collected results from REST-api."
        Write-Verbose "$TimeStamp : LOG   : Collected $($Return_api.Count) results of $($ServiceTagArray.Count) devices."
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect results from REST-api."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Boolean_Exit = $True   
    }
}        

##Looping through channels to write data
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Foreach ($Item in $ChannelConfiguration) {
        [DateTime] $WarrantyExp = Get-Date
        [Int]      $Value       = 0
        
        ##Collecting value for warranty expiration
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Resolve -eq $True) {
            Write-Verbose    "$TimeStamp : LOG   : Using Computername $($Item.Channel) and Assettag $($Item.Assettag)."
            $WarrantyExp   = (($Return_Api | Where-Object -FilterScript {$_.ServiceTag -eq $($Item.Assettag) }).entitlements | Sort-object -property endDate | Select-Object -Last 1).enddate
            $Value         = ($WarrantyExp - (Get-Date)).Days
            Write-Verbose    "$TimeStamp : LOG   : Collected $WarrantyExp / $Value."
        } Else {
            Write-Verbose    "$TimeStamp : LOG   : Using Assettag $($Item.Channel)."
            $WarrantyExp   = (($Return_Api | Where-Object -FilterScript {$_.ServiceTag -eq $($Item.Channel) }).entitlements | Sort-object -property endDate |  Select-Object -Last 1).enddate
            $Value         = ($WarrantyExp - (Get-Date)).Days
            Write-Verbose    "$TimeStamp : LOG   : Collected $WarrantyExp / $Value"       
        }

        ##Writing to PRTG
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) {
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $($Item.Channel) -Value $Value
                Write-Verbose    "$Timestamp : LOG   : Written result to PRTG XML for Channel."
            } Catch {
                Write-Error     "$TimeStamp : ERROR : Could not write to channel $($Item.Channel)."
                Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Exit = $True 
            }
        }

        ##Determining Warninglevels
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Exit -eq $False) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $false) ) {
            Write-Verbose "$TimeStamp : LOG   : Using min warninglevel $($Item.LimitMinWarning) for Channel $($Item.Channel)."
            If ( ($Value -lt $($Item.LimitMinWarning)) -and ($($Item.LimitMinWarning) -gt 0) -and ($Boolean_Resolve -eq $true) ) {
                Write-verbose "$TimeStamp : LOG   : Triggered WARNING-value, setting warningmessage."
                $Output_Message = "Server $($Item.Channel) / $($Item.Assettag) only has $Value days of support ($(Get-date $WarrantyExp -format dd.MM.yy))"
                Write-verbose "$TimeStamp : LOG   : Message 'Server $($Item.Channel) / $($Item.Assettag) only has $Value days of support ($(Get-date $WarrantyExp -format dd.MM.yy))'"
                $Boolean_Warning = $True
            } ElseIf ( ($Value -lt $($Item.LimitMinError)) -and ($($Item.LimitMaxError) -gt 0) -and ($Boolean_Resolve -eq $False) ) {
                Write-verbose "$TimeStamp : LOG   : Triggered WARNING-value, setting warningmessage, no hostname."
                $Output_Message = "Server $($Item.Channel) only has $Value days of support ($(Get-date $WarrantyExp -format dd.MM.yy))"
                Write-verbose "$TimeStamp : LOG   : Message 'Server $($Item.Channel) only has $Value days of support ($(Get-date $WarrantyExp -format dd.MM.yy))'"
                $Boolean_Warning = $True
            } Else {
                Write-verbose "$TimeStamp : LOG   : No warning triggered on $($Item.Channel)."
            }
        }

        ##Determining Errorlevels
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ( ($Boolean_Exit -eq $False) -and ($Boolean_Error -eq $False) ) {
            Write-Verbose "$TimeStamp : LOG   : Using min errorlevel $($Item.LimitMinError) for Channel $($Item.Channel)."
            If ( ($Value -lt $($Item.LimitMinError)) -and ($($Item.LimitMinError) -gt 0) -and ($Boolean_Resolve -eq $true) ) {
                Write-verbose "$TimeStamp : LOG   : Triggered ERROR-value, setting errormessage."
                $Output_Message = "Server $($Item.Channel) / $($Item.Assettag) only has $Value days of support! ($(Get-date $WarrantyExp -format dd.MM.yy))"
                Write-verbose "$TimeStamp : LOG   : Message 'Server $($Item.Channel) / $($Item.Assettag) only has $Value days of support! ($(Get-date $WarrantyExp -format dd.MM.yy))'"
                $Boolean_Error   = $True
                $Boolean_Warning = $True
            } ElseIf ( ($Value -lt $($Item.LimitMinError)) -and ($($Item.LimitMinError) -gt 0) -and ($Boolean_Resolve -eq $False) ) {
                Write-verbose "$TimeStamp : LOG   : Triggered ERROR-value, setting errormessage, no hostname."
                $Output_Message = "Server $($Item.Channel) only has $Value days of support! ($(Get-date $WarrantyExp -format dd.MM.yy))"
                Write-verbose "$TimeStamp : LOG   : Message 'Server $($Item.Channel) only has $Value days of support! ($(Get-date $WarrantyExp -format dd.MM.yy))'"
                $Boolean_Error   = $True
                $Boolean_Warning = $True
            } Else {
                Write-verbose "$TimeStamp : LOG   : No error triggered on $($Item.Channel)."
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