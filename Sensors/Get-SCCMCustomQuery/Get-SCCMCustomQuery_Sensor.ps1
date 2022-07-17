<#
.SYNOPSIS
PRTG-Sensor for running a custom query in a Config Manager Site

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It connects to an SCCM Siteserver using a serviceaccount, 
queries the WMI for the root\sms\Site_$site Namepace, and collects query-objects from WMI.
(See Monitoring > Queries)

It will run queries selected in the ChannelConfiguration, and run these. ResultCount will be sent to the
PRTG-Channel. By setting error-limits in PRTG, this can be used to prompt an error. 

For connecting, the PRTG-installation will need to use a serviceaccount with the 'read-only analyst' role in SCCM.

.PARAMETER SiteServer
Mandatory parameter for the FQDN of the site-server / database-server of the SCCM Site to monitor.

.PARAMETER Site
Mandatory parameter for the Sitecode of the SCCM Site to monitor.

.PARAMETER Filename
Mandatory parameter to the path of the PRTG Channel Configuration file, XML formatted.

.PARAMETER Prefix
Mandatory parameter to define which SCCM Queries to collect. The sensor expects a string value; Prefix + Channelname should match with the SCCM Queryname. 
E.g: 
Channelname: All computers without bitlocker
Prefix:      PRTG_Client_Security_
SCCM Query:  PRTG_Client_Security_All computers without bitlocker

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script ADVANCED'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       Get-SCCMCustomQuery.ps1
- Parameters:       -SiteServer 'Sccm01.test.local' -Site 'test' -Configuration 'C:\Scripting\Configurations\Get-SCCMCustomQuery_ChannelConfiguration.xml'
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
Version 1.0 / 07.29.2018: Initial upload
Version 1.2 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Moved to Github

.LINK
https://msdn.microsoft.com/en-us/library/cc144830.aspx
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
        [Parameter(Mandatory=$True,Position=1 )] [String] $Siteserver,
        [Parameter(Mandatory=$True,Position=2 )] [String] $Site,
        [Parameter(Mandatory=$True,Position=3 )] [String] $Filename,
        [Parameter(Mandatory=$True,Position=4 )] [String] $Prefix,
        [Parameter(Mandatory=$False,Position=5)] [String] $Username = $null,
        [Parameter(Mandatory=$False,Position=6)] [String] $Password = $null 
)
## Variables
[BOOLEAN]   $Boolean_Exit   = $False
[Boolean]   $Boolean_Cred   = $False
[STRING]    $Output_Message = 'OK'
[STRING]    $Command        = $MyInvocation.MyCommand.Name
[String]    $Timestamp      = Get-Date -format yyyy.MM.dd_hh:mm
[Array]     $Collected_Queries = @()

## Query
[String] $Query_for_Queries = @"
SELECT 
	Expression
	,LimitToCollectionID
	,Name
	,TargetClassName
FROM 
	SMS_Query 
WHERE 
	Name like "$Prefix%"
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

## Import the ChannelConfiguration
# If this step fails, sensor will prompt error:
# 'XML: The returned XML does not match the expected schema. (code: PE233) 
# JSON: The returned JSON does not match the expected structure (Invalid JSON.). (code: PE231)'

## Importing configuration-file
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        $Configuration          = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose             "$Timestamp : LOG   : Imported configuration."
    } Catch {
        Write-Error     "$TimeStamp : ERROR : Could not collect data from XML."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not collect data from XML."
        $Boolean_Exit = $True
    }
}

##Checking if Creds are given
[String] $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
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
        Write-Verbose "$Timestamp : LOG   : Credentialobject build on username $Username."
    } Catch {
        Write-Error "$Timestamp : ERROR : Could not build credential object."
        Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)"
        $Output_Message = "Could not build credential object."        
        $Boolean_Exit = $True 
    }
}
$Username = $null
$Password = $null

##Collecting errormessages from SCCM-server
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    If ($Boolean_Cred -eq $False) {
        Try {
            $Collected = Connect-PRTGtoSCCMviaWMI -Query $Query_for_Queries -Site $site -SiteServer $Siteserver
            Write-Verbose      "$timeStamp : LOG   : Collected queries from SCCM server $Siteserver / $Site."
        } Catch {
            $Boolean_Exit    = $True
            Write-Error "$TimeStamp : ERROR : Not successfull in querying from SCCM ($Site / $SiteServer)."
            Write-Error "$TimeStamp : ERROR : Query : $($Query.Expression)."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        }
    } Else {
        Try {
            $Collected = Connect-PRTGtoSCCMviaWMI -Query $Query_for_Queries -Site $site -SiteServer $Siteserver -Credential $Credential
            Write-Verbose      "$timeStamp : LOG   : Collected queries from SCCM server $Siteserver / $Site."
        } Catch {
            $Boolean_Exit    = $True
            Write-Error "$TimeStamp : ERROR : Not successfull in querying from SCCM ($Site / $SiteServer) w/ cred."
            Write-Error "$TimeStamp : ERROR : Query : $($Query.Expression)."
            Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
        }                                
    }
    If ($Collected.result -eq $True) {
        $Collected_Queries       = $Collected.Return
        $Collected_Queries       = $Collected_Queries | Sort-object -Property Name -Descending
        Write-Verbose "$Timestamp : LOG   : Imported and sorted $($Collected_Queries.Count) Queries from SCCM."
    } Else {
        Write-Error "$Timestamp : LOG   : Could not import data from SCCM through Connectto-SCCMviaWMI."
        $Output_Message = "Could not import data from SCCM through Connectto-SCCMviaWMI." 
        $Boolean_Exit = $True
    }
}

##Running found Queries
[String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $false) {
    Foreach ($Query in $Collected_Queries) {
        [String]   $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        [PSObject] $Result    = $null
        [String]   $Returned_result = $null
        [String]   $Returned_Name   = $null
            
        ##Collecting data from SCCM
        [String]   $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) { 
            If ($Boolean_Cred -eq $False) {
                Try {
                    $Result          = (Connect-PRTGtoSCCMviaWMI -Query $($Query.Expression) -Site $Site -SiteServer $Siteserver).Return
                    Write-Verbose      "$timeStamp : LOG   : Collected data from SCCM server $Siteserver / $Site."
                } Catch {
                    $Boolean_Exit    = $True
                    $Boolean_Error   = $True
                    $Boolean_Warning = $True
                    Write-Error "$TimeStamp : ERROR : Not successfull in querying from SCCM ($Site / $SiteServer)."
                    Write-Error "$TimeStamp : ERROR : Query : $($Query.Expression)."
                    Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
                    $Output_Message = "Not successfull in querying from SCCM ($Site / $SiteServer)." 
                }
            } Else {
                Try {
                    $Result          = (Connect-PRTGtoSCCMviaWMI -Query $($Query.Expression) -Site $Site -SiteServer $Siteserver -Credential $Credential).Return
                    Write-Verbose      "$timeStamp : LOG   : Collected data from SCCM server $Siteserver / $Site w/ cred."
                } Catch {
                    $Boolean_Exit    = $True
                    $Boolean_Error   = $True
                    $Boolean_Warning = $True
                    Write-Error "$TimeStamp : ERROR : Not successfull in querying from SCCM ($Site / $SiteServer) w/ cred."
                    Write-Error "$TimeStamp : ERROR : Query : $($Query.Expression)."
                    Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
                    $Output_Message = "Not successfull in querying from SCCM ($Site / $SiteServer) w/ cred."
                }                                
            }
        }
            
        ##Writing to PRTG
        [String]   $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Exit -eq $False) {
            $Returned_result = ($Result.Return).count
            $Returned_Name   = ($Query.Name).Replace("$Prefix","")
            Write-Verbose      "$timeStamp : LOG   : Query : $($Query.Expression)"
            Write-Verbose      "$TimeStamp : LOG   : Name  : $($Query.Name)"
            Write-Verbose      "$Timestamp : LOG   : Result : $Returned_Result"
            ##Writing to Channel with the same name in PRTG-XML
            Try {
                $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $Returned_Name -Value $Returned_result
                Write-Verbose    "$TimeStamp : LOG   : Written result to Configuration ($Returned_Name / $Returned_result)"
            } Catch {
                $Boolean_Exit    = $True
                $Boolean_Error   = $True
                $Boolean_Warning = $True
                Write-Error "$TimeStamp : ERROR : Could not write result to Configuration ($Returned_Name / $Returned_result)"
                Write-Error "$TimeStamp : ERROR : $($_.Exception.Message)."
                $Output_Message = "Could not write result to Configuration ($Returned_Name / $Returned_result)"                
            }
        }

        ##Determining ErrorStatus
        [String]   $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        If ($Boolean_Error -eq $False) {
            If (
                (
                    ($Returned_result -gt ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMaxError) -and 
                    ( ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMaxError -ne "$Null") 
                ) -or (
                    ($Returned_result -lt ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMinError) -and 
                    ( ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMinError -ne "$Null") 
                ) 
            ) {
                $Boolean_Error   = $True
                $Boolean_Warning = $True
                Write-verbose      "$Timestamp : LOG   : Detected ERROR in query $($Query.Name)."
                $Output_Message  = "ERROR: Investigate query $($Query.Name) on SCCM Site $Sitecode.($Returned_result)"
            }
        } 

        ##Determining WarningStatus
        If ($Boolean_Warning -eq $False) {
            If (
                (
                    ($Returned_result -gt ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMaxWarning) -and 
                    ( ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMaxWarning -ne "$Null") 
                ) -or (
                    ($Returned_result -lt ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMinWarning) -and 
                    ( ($Configuration.prtg.result | Where-Object -FilterScript {$_.Name -eq $Returned_Name}).LimitMinWarning -ne "$Null") 
                ) 
            ) {
                $Boolean_Warning = $True
                Write-verbose      "$Timestamp : LOG   : Detected WARNING in query $($Query.Name)."
                $Output_Message  = "Warning: Investigate query $($Query.Name) on SCCM Site $Sitecode.($Returned_result)"
            }
        }
    }
}

If ($Boolean_Exit -eq $True) {
    $Configuration.prtg.error = '2'
}

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml