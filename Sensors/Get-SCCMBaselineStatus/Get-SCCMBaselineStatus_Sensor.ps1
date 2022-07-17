<#
.SYNOPSIS
PRTG-Sensor for checking the current status of a Config Manager baseline

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects the status of a SCCM baseline.
I.e. this is the Result-page of a baseline

It will return the status of all Configuration Items, including (if given) remediation-status. Depending on alert-
and result it will determine errorstatus. 

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Site
Mandatory parameter for the Sitecode of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Baseline
Mandatory parameter to the name of the SCCM Baseline to monitor.

.PARAMETER Username
Optional parameter, for defining the name of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string in a domain\accountname format.

.PARAMETER Password
Optional parameter, for defining the password of the useraccount to use for connecting. Can be used if the SCCM server
is in another domain as the probeserver. Expects a string value, ment to be used with %windowspassword (PRTG variable).

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-SCCMBaselineStatus_sensor.ps1
- Parameters:       -SiteServer 'Sccm01.test.local' -Site 'test' -Configuration 'C:\Scripting\Configurations\Get-SCCMBaselineStatus_ChannelConfiguration.xml'
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
Version 1.0 / 17.11.2018: Initial upload
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://github.com/jaapplugge/PRTGModule
#>  

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True,Position=1)]  [String] $Siteserver,
        [Parameter(Mandatory=$True,Position=2)]  [String] $Site,
        [Parameter(Mandatory=$True,Position=3)]  [String] $Filename,
        [Parameter(Mandatory=$True,Position=4)]  [String] $Baseline,
        [Parameter(Mandatory=$False,Position=5)] [String] $Username = $null,
        [Parameter(Mandatory=$False,Position=6)] [String] $Password = $null
)

## Variables
[Boolean]   $Boolean_Exit            = $False
[Int]       $Result_Complaint        = 0
[Int]       $Result_NonCompliant     = 0
[Int]       $Result_Error            = 0
[Int]       $Percentage_Compliant    = 0
[Int]       $Percentage_NonCompliant = 0
[Int]       $Percentage_Error        = 0
[Array]     $Col_Compliant           = @()
[Array]     $Col_NonCompliant        = @()
[Array]     $Col_Error               = @()        

[String]    $Output_Message          = $null
[String]    $Command                 = $MyInvocation.MyCommand.Name
[XML]       $Configuration           = $null
[String]    $Timestamp               = Get-Date -format yyyy.MM.dd_hh:mm

## Query's
[String] $Query_Compliant = @"
SELECT 
    BLName
    ,Assets
    ,SummarizationTime
FROM
    SMS_DCMDeploymentCompliantStatus
WHERE
    BLName = `"$Baseline`"
"@
[String] $Query_NonCompliant = @"
SELECT 
    BLName
    ,Assets
FROM
    SMS_DCMDeploymentNonCompliantStatus
WHERE
    BLName = `"$Baseline`"
"@
[String] $Query_Error = @"
SELECT 
    BLName
    ,Assets
FROM
    SMS_DCMDeploymentErrorStatus
WHERE
    BLName = `"$Baseline`"
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
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        $Output_Message = "Could not build credential object."
        $Boolean_Exit = $True 
    }
}
$Username = $null
$Password = $null

## Importing configuration-file
[String] $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration          = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        $ErrorPercentage        = ($Configuration.prtg.result | Where-Object -FilterScript {$_.channel -eq "% Error"         }).LimitMaxError
        $NonCompliantPercentage = ($Configuration.prtg.result | Where-Object -FilterScript {$_.channel -eq "% NonCompliant"  }).LimitMaxWarning
        Write-Verbose             "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

##Collecting baseline results from SCCM-server
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $False) {
        Try {
            $Col_Compliant    = (Connect-PRTGtoSCCMviaWMI -Query $Query_Compliant    -Site $site -SiteServer $Siteserver).Return
            $Col_NonCompliant = (Connect-PRTGtoSCCMviaWMI -Query $Query_NonCompliant -Site $site -SiteServer $Siteserver).Return
            $Col_Error        = (Connect-PRTGtoSCCMviaWMI -Query $Query_Error        -Site $site -SiteServer $Siteserver).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI"
        } Catch {
            Write-Error "$TimeStamp : ERROR : Could not collect data from SCCM via WMI."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.message)"
            $Output_Message = "Could not collect data from SCCM via WMI."
            $Boolean_Exit = $True
        }
    } Else {
        Try {
            $Col_Compliant    = (Connect-PRTGtoSCCMviaWMI -Query $Query_Compliant    -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            $Col_NonCompliant = (Connect-PRTGtoSCCMviaWMI -Query $Query_NonCompliant -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            $Col_Error        = (Connect-PRTGtoSCCMviaWMI -Query $Query_Error        -Site $site -SiteServer $Siteserver -Credential $Credential).Return
            Write-Verbose "$Timestamp : LOG   : Imported data from SCCM through Connectto-SCCMviaWMI with Credentials."
        } Catch {
            Write-Error     "$TimeStamp : ERROR : Could not collect data from SCCM via WMI with Credentials."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.message)"
            $Output_Message = "Could not collect data from SCCM via WMI with credentials."
            $Boolean_Exit = $True
        }
    }
}

##Calculating returnvalues
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($item in $Col_Compliant) {
        $Result_Compliant = $Result_Compliant + $Item.Assets
        Write-Verbose       "$TimeStamp : LOG   : Compliant : Collected $($Item.Assets) /Total $Result_Compliant."
        $LastRunTime      = ([Management.ManagementDateTimeConverter]::ToDateTime($Item.SummarizationTime))
    }
    Foreach ($item in $Col_NonCompliant) {
        $Result_NonCompliant = $Result_NonCompliant + $Item.Assets
        Write-Verbose       "$TimeStamp : LOG   : NonCompliant : Collected $($Item.Assets) /Total $Result_NonCompliant."
    }
    Foreach ($item in $Col_Error) {
        $Result_Error = $Result_Error + $Item.Assets
        Write-Verbose       "$TimeStamp : LOG   : Error : Collected $($Item.Assets) /Total $Result_Error."
    }          
    Try {
        $Result_Total            = $Result_Compliant + $Result_NonCompliant + $Result_Error
        if ($Result_Total -ne 0) {
            $Percentage_Compliant    = ($Result_Compliant    *100) / $Result_Total 
            $Percentage_NonCompliant = ($Result_NonCompliant *100) / $Result_Total 
            $Percentage_Error        = ($Result_Error        *100) / $Result_Total 
            Write-Verbose   "$TimeStamp : LOG   : Result Compliant    : $Result_Compliant ($Percentage_Compliant %)"
            Write-Verbose   "$TimeStamp : LOG   : Result NonCompliant : $Result_NonCompliant ($Percentage_NonCompliant %)"
            Write-Verbose   "$TimeStamp : LOG   : Result Error        : $Result_Error ($Percentage_Error %)"
            Write-Verbose   "$TimeStamp : LOG   : Result Total        : $Result_Total"
            Write-Verbose   "$TimeStamp : LOG   : Last run time       : $LastRunTime"
        } Else {
            Write-Verbose   "$Timestamp : LOG   : No results found."
        }
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not calculate return data."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.message)"
        $Output_Message = "Could not calculate return data."
        $Boolean_Exit = $True
    }
}

##Writing results to PRTG
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Compliant"      -Value $Result_Complaint
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "NonCompliant"   -Value $Result_NonComplaint
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Error"          -Value $Result_Error
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "Total"          -Value $Result_Total
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "% Compliant"    -Value $Percentage_Compliant
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "% NonCompliant" -Value $Percentage_NonCompliant
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel "% Error"        -Value $Percentage_Error
        Write-Verbose    "$TimeStamp : LOG   : Wrote results to XML Configuration."
    } Catch {
        Write-Error      "$TimeStamp : ERROR : Could not write results to XML Configuration."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.message)"
        $Output_Message = "Could not write results to XML Configuration."
        $Boolean_Exit  = $True
    }
} 

##Determining ErrorStatus
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        If ( ($ErrorPercentage -ge $Percentage_Error) -and ($ErrorPercentage) ) {
            Write-Verbose    "$TimeStamp : LOG   : Detected errorstatus ($ErrorPercentage > $Percentage_Error)"
            $Output_Message = "$Baseline returned $Result_Error Devices in error (Last run $LastRunTime)"
        } ElseIf ( ($NonCompliantPercentage -ge $Percentage_NonCompliant) -and ($NonCompliantPercentage) ) {
            Write-Verbose    "$TimeStamp : LOG   : Detected warningstatus ($NonCompliantPercentage > $Percentage_NonCompliant)"
            $Output_Message = "$Baseline returned $Result_NonComplaint NonCompliant devices (Last run $LastRunTime)"
        } ElseIf ($Result_Total -eq 0) {
            Write-Verbose    "$TimeStamp : LOG   : Detected no results found ($Result_Total)"
            $Output_Message = "$Baseline returned no result found."                
        } Else {
            Write-Verbose    "$TimeStamp : LOG   : Detected OK"
            $Output_Message = "$Baseline : OK $Result_Compliant / NOK $Result_NonCompliant / ERR $Result_Error / TOT $Result_Total (Last run $LastRunTime)"
        }
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not determine Errorstatus."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.message)"
        $Output_Message = "Could not determine Errorstatus."
        $Boolean_Exit = $True
    }
}

##Finishing
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

##Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml
##Script ends