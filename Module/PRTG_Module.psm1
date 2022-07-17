<#
    FunctionList:
    - Connect-PRTGtoSCCMviaWMI
    - Connect-PRTGtoSCCMforSiteCode
    - Get-PRTGClientMaintenanceWindow
    - Get-PRTGClientUpdateStatus
    - Get-PRTGClientRegistryValue
    - Get-PRTGClientLastReboot
    - Get-PRTGClientUserProfileSize
    - Get-PRTGClientEventlog
    - Get-PRTGDHCPScopeStatistics
    - Get-PRTGGraphApiToken
    - Get-PRTGIPAddressesInSubnet
    - Get-PRTGSPFRecord
    - Get-PRTGSccmPatchTuesday
    - Import-PRTGConfigFile
    - Invoke-PRTGGraphApiCall
    - New-PRTGPSSession
    - Test-PRTGGraphApiToken
    - Write-PRTGresult
    - Write-PRTGChannel

    - Get-DellAccessToken
    - Get-DellWarantyInfo
#>

##Function Import-PRTGConfigFile
#Function for importing a configuration file, either XML or JSON, for use in PRTG.
Function Import-PRTGConfigFile {
    [cmdletbinding()] Param (
            [Parameter(Mandatory=$true,Position=1 )] [String]  $FilePath,
            [Parameter(Mandatory=$true,Position=2 )] [ValidateSet('XML','JSON')] [String] $FileType
    )
    ##Variables
    [Boolean]  $Boolean_Success = $true
    [Array]    $ReturnMessage   = @()
    [String]   $Filetype_incl   = '*.' + $FileType
    [String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    
    Write-Verbose     "$Timestamp : FUNCTION: Import-PRTGConfigFile"
    Write-Verbose     "$TimeStamp : PARAM : Filepath : $Filepath"
    Write-Verbose     "$TimeStamp : PARAM : Filetype : $Filetype"
    $ReturnMessage += "$Timestamp : FUNCTION: Import-PRTGConfigFile"
    $ReturnMessage += "$TimeStamp : PARAM : Filepath : $Filepath"
    $ReturnMessage += "$TimeStamp : PARAM : Filetype : $Filetype"
    
    ##Test if file is present
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ( (Test-path $Filepath -Include "$Filetype_incl") -eq $true ) {
        Write-Verbose      "$Timestamp : LOG   : Test-Path successfull to $FilePath"
        $ReturnMessage  += "$Timestamp : LOG   : Test-Path successfull to $FilePath"
    } Else {
        Write-Verbose      "$Timestamp : ERROR : Test-Path NOT successfull to $FilePath"
        $ReturnMessage  += "$Timestamp : ERROR : Test-Path NOT successfull to $FilePath"
        $Boolean_Success = $false
    }

    ##Import File
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ( ($Boolean_Success -eq $true) -and ($FileType -eq 'XML') ) {
        Try {
            [XML] $ReturnObj = $null
            $ReturnObj       = Get-Content -Raw -Path $Filepath 
            Write-Verbose      "$Timestamp : LOG   : Collected data from $FilePath."
            $ReturnMessage  += "$Timestamp : LOG   : Collected data from $FilePath."
        } Catch {
            Write-Verbose      "$Timestamp : ERROR : Could not collect data from $FileType."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$Timestamp : ERROR : Could not collect data from $FileType."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    } ElseIf ( ($Boolean_Success -eq $true) -and ($FileType -eq 'Json') ) {
        Try {
            [PSObject] $ReturnObj = $null
            $ReturnObj       = Get-Content -Raw -Path $Filepath | ConvertFrom-Json
            Write-Verbose      "$Timestamp : LOG   : Collected data from $FileType."
            $ReturnMessage  += "$Timestamp : LOG   : Collected data from $FileType."
        } Catch {
            Write-Verbose      "$Timestamp : ERROR : Could not collect data from $FileType."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$Timestamp : ERROR : Could not collect data from $FileType."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }

    ## Returning..
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$Timestamp : LOG   : Returning.."
        $ReturnMessage  += "$Timestamp : LOG   : Returning.."
        Return $ReturnObj
    } Else {
        Write-Verbose      "$TimeStamp : ERROR : Function Import-PRTGConfigFile not successfull."
        $ReturnMessage  += "$TimeStamp : ERROR : Function Import-PRTGConfigFile not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Write-PRTGResult
#Function for writing the collected result to a certain channel. This function returns an XML formatted returnObject.
Function Write-PRTGResult {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1)] [XML]    $Configuration,
        [Parameter(Mandatory=$true, Position=2)] [String] $Channel,
        [Parameter(Mandatory=$true, Position=3)] [Int]    $Value
    )
    ##Variables
    [String] $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
    [Array]  $ReturnMessage = @()

    Write-Verbose     "$Timestamp : FUNCTION: Write-PRTGresult"
    Write-Verbose     "$TimeStamp : PARAM : Configuration : $Filepath"
    Write-Verbose     "$TimeStamp : PARAM : Channel : $Channel"
    Write-Verbose     "$TimeStamp : PARAM : Value   : $Value"
    $ReturnMessage += "$Timestamp : FUNCTION: Write-PRTGresult"
    $ReturnMessage += "$TimeStamp : PARAM : Configuration : $Filepath"
    $ReturnMessage += "$TimeStamp : PARAM : Channel : $Channel"
    $ReturnMessage += "$TimeStamp : PARAM : Value   : $Value"

    ##Create return object
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    Try {
        ($Configuration.prtg.result | Where-Object -FilterScript {$_.channel -eq $Channel}).value = ($value.ToString())
        Write-Verbose     "$Timestamp : LOG   : Set value $Value to channel $Channel, and returning."
        $ReturnMessage += "$Timestamp : LOG   : Set value $Value to channel $Channel, and returning."
        Return $Configuration
    } Catch {
        Write-Verbose     "$Timestamp : ERROR : Could set $Value to Channel $channel."
        Write-Verbose     "$Timestamp : ERROR : $($_.Exception.Message)"
        $ReturnMessage += "$Timestamp : ERROR : Could set $Value to Channel $channel."
        $ReturnMessage += "$Timestamp : ERROR : $($_.Exception.Message)"
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Write-PRTGChannel (26-05-2020)
#Function for adding a channgel and values to an XML PRTGConfiguration
Function Write-PRTGChannel {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1 )] [String] $Channel,
        [Parameter(Mandatory=$true, Position=2 )] [Float]  $Value,
        [Parameter(Mandatory=$true, Position=3 )] [ValidateSet('No','Min','Max')][String] $LimitMode,
        [Parameter(Mandatory=$true, Position=4 )] [String] $Unit,
        [Parameter(Mandatory=$true, Position=5 )] [XML]    $Configuration,
        [Parameter(Mandatory=$false)] [Float]  $ErrorLimit,
        [Parameter(Mandatory=$false)] [Float]  $WarningLimit
    )
    [Array]    $ReturnMessage   = @()
    [String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [PSObject] $ChannelNode     = $null
    [Boolean]  $Boolean_Success = $true
    [Array]    $PropertyArray   = @()

    <#
    Structure to build:
      <result>
          <channel>Total size</channel>
          <value>0</value>
          <unit>Custom</unit>
          <customunit>Gb</customunit>
          <showChart>1</showChart>
          <showTable>1</showTable>
          <float>1</float>
          <DecimalMode>2</DecimalMode>
          <mode>absolute</mode>
          OF  <LimitMode>0</LimitMode>                @LimitMode NO 
          OF  <LimitMode>1</LimitMode>                @LimitMode MIN
              <LimitMinError>30</LimitMinError>
              <LimitMinWarning>20</LimitMinWarning>
          OF  <LimitMode>1</LimitMode>                @LimitMode MAX
              <LimitMaxError>30</LimitMaxError>
              <LimitMaxWarning>20</LimitMaxWarning>
      </result>
    #>

    Write-Verbose     "$TimeStamp : FUNCTION : Write-PRTGChannel"
    Write-Verbose     "$TimeStamp : PARAM : Channel    : $Channel"
    Write-Verbose     "$TimeStamp : PARAM : Value      : $Value"
    Write-Verbose     "$TimeStamp : PARAM : LimitMode  : $LimitMode"
    Write-Verbose     "$TimeStamp : PARAM : Unit       : $Unit"
    Write-Verbose     "$TimeStamp : PARAM : Configuration : `$Configuration"
    $ReturnMessage += "$TimeStamp : FUNCTION : Write-PRTGChannel"
    $ReturnMessage += "$TimeStamp : PARAM : Channel    : $Channel"
    $ReturnMessage += "$TimeStamp : PARAM : Value      : $Value"
    $ReturnMessage += "$TimeStamp : PARAM : LimitMode  : $LimitMode"
    $ReturnMessage += "$TimeStamp : PARAM : Unit       : $Unit"    
    $ReturnMessage += "$TimeStamp : PARAM : Configuration : `$Configuration"
    If ($ErrorLimit) {
        Write-Verbose     "$TimeStamp : PARAM : ErrorLimit   : $ErrorLimit"
        $ReturnMessage += "$TimeStamp : PARAM : ErrorLimit   : $ErrorLimit"
    }
    If ($WarningLimit) {
        Write-Verbose     "$TimeStamp : PARAM : WarningLimit : $WarningLimit"
        $ReturnMessage += "$TimeStamp : PARAM : WarningLimit : $WarningLimit"        
    }
   
    ##Creating Array with Key / Value pairs
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            Write-Verbose     "$TimeStamp : LOG   : Creating PropertyArray"
            $ReturnMessage += "$TimeStamp : LOG   : Creating PropertyArray"
            $PropertyArray = @(
                @{"channel"     = [String] $Channel             },
                @{"value"       = [String] $($Value.toString()) },
                @{"unit"        = [String] "Custom"             },
                @{"customunit"  = [String] $Unit                },
                @{"showChart"   = [String] "1"                  },
                @{"showChart"   = [String] "1"                  },
                @{"float"       = [String] "1"                  },
                @{"decimalmode" = [string] "2"                  },
                @{"mode"        = [String] "absolute"           }
            )
            If ($LimitMode -eq 'No') {
                $PropertyArray  += @{ "LimitMode" = [String] "0" }
                Write-Verbose      "$TimeStamp : LOG   : Set LimitMode to 0: No Limitz"
                $ReturnMessage  += "$TimeStamp : LOG   : Set LimitMode to 0: No Limitz"
            } ElseIf ($LimitMode -eq 'Min') {
                $PropertyArray  += @{ "LimitMode"       = [String] "1" }
                $PropertyArray  += @{ "LimitMinError"   = [String] $($ErrorLimit.toString())   }
                $PropertyArray  += @{ "LimitMinWarning" = [String] $($WarningLimit.toString()) }
                Write-Verbose      "$TimeStamp : LOG   : Set LimitMode to 1: Limits to MIN $($ErrorLimit.toString()) Error / $($WarningLimit.toString()) Warning"
                $ReturnMessage  += "$TimeStamp : LOG   : Set LimitMode to 1: Limits to MIN $($ErrorLimit.toString()) Error / $($WarningLimit.toString()) Warning"
            } ElseIf ($LimitMode -eq 'Max') {
                $PropertyArray  += @{ "LimitMode"       = [String] "1" }
                $PropertyArray  += @{ "LimitMaxError"   = [String] $($ErrorLimit.toString())   }
                $PropertyArray  += @{ "LimitMaxWarning" = [String] $($WarningLimit.toString()) }
                Write-Verbose      "$TimeStamp : LOG   : Set LimitMode to 1: Limits to MAX $($ErrorLimit.toString()) Error / $($WarningLimit.toString()) Warning"
                $ReturnMessage  += "$TimeStamp : LOG   : Set LimitMode to 1: Limits to MAX $($ErrorLimit.toString()) Error / $($WarningLimit.toString()) Warning"
            }
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not set PropertyArray."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not set PropertyArray."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }

    ##Creating Channel Object
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $ChannelNode     = $Configuration.CreateNode("element","result","")
            Write-verbose      "$TimeStamp : LOG   : Created channelNode."
            $ReturnMessage  += "$TimeStamp : LOG   : Created channelNode."
            $ChannelNode.RemoveAttribute("xmlns")
            Write-Verbose      "$TimeStamp : LOG   : Remove XMLNS if present."
            $ReturnMessage  += "$TimeStamp : LOG   : Remove XMLNS if present."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not create ChannelObject."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not create ChannelObject."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }

    ##Creating nodes under the channel
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Foreach ($Node in $PropertyArray) {
            Try { 
                $NodeObject      = $null
                $NodeObject      = $Configuration.CreateNode("element","$($Node.Keys)","")
                Write-Verbose      "$timestamp : LOG   : Created Node $($Node.Keys)."
                $ReturnMessage  += "$timestamp : LOG   : Created Node $($Node.Keys)."
                $NodeObject.Innertext = $($Node.Values)
                Write-Verbose      "$TimeStamp : LOG   : Added value $($Node.Values)."
                $ReturnMessage  += "$TimeStamp : LOG   : Added value $($Node.Values)."
                $NodeObject.RemoveAttribute("xmlns")
                Write-Verbose      "$TimeStamp : LOG   : Remove XMLNS from childnode if present."
                $ReturnMessage  += "$TimeStamp : LOG   : Remove XMLNS from childnode if present."
                $ChannelNode.appendChild($NodeObject) | Out-null
                Write-Verbose      "$TimeStamp : LOG   : Added node to ChannelNode"
                $ReturnMessage  += "$TimeStamp : LOG   : Added node to ChannelNode"
            } Catch {
                Write-Verbose      "$TimeStamp : ERROR : Could not add Node to XML."
                Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
                $ReturnMessage  += "$TimeStamp : ERROR : Could not add Node to XML."
                $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Success = $false
            }
        }
    }

    ##Adding to XML Object
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $ChannelNode.RemoveAttribute("xmlns")
            Write-Verbose      "$TimeStamp : LOG   : Remove XMLNS if present."
            $ReturnMessage  += "$TimeStamp : LOG   : Remove XMLNS if present."
            $Configuration.PRTG.appendchild($ChannelNode) | Out-null
            Write-Verbose      "$TimeStamp : LOG   : Added node to XML"
            $ReturnMessage  += "$TimeStamp : LOG   : Added node to XML"
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not add ChannelNode to XML."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not add ChannelNode to XML."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }

    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$TimeStamp : LOG   : Returning..."
        $ReturnMessage  += "$TimeStamp : LOG   : Returning..."
        Return $Configuration
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGDHCPScopeStatistics
#Function for collecting all active DHCPScopes on a server
Function Get-PRTGDHCPScopeStatistics {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1 )] [String] $Server,
        [Parameter(Mandatory=$false)] [PSCredential] $Credential
    )

    ##Variables
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [Array]     $ReturnMessage   = @()
    [Array]     $ScopeIDs        = @()
    [Array]     $Return_Array    = @()
    [Array]     $DHCPProperties  = @("ScopeID", "Name", "StartRange", "EndRange")
    [PSObject]  $Result          = $null
    [Boolean]   $Boolean_Success = $true
    [Boolean]   $Boolean_Cred    = $false
    [HashTable] $Sessionsplat    = @{}

    If ($Credential) {$Boolean_Cred = $true}
    
    Write-Verbose     "$Timestamp : FUNCTION: PRTGDHCPScopeStatistics"
    Write-Verbose     "$TimeStamp : PARAM : Server   : $Server"
    Write-Verbose     "$TimeStamp : PARAM : UseCreds : $Boolean_Cred"
    $ReturnMessage += "$Timestamp : FUNCTION: PRTGDHCPScopeStatistics"
    $ReturnMessage += "$TimeStamp : PARAM : Server   : $Server"
    $ReturnMessage += "$TimeStamp : PARAM : UseCreds : $Boolean_Cred"
    
    ##Creating CimSession to DHCPServer
    [String]  $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $Sessionsplat = @{
                ComputerName = $server
            }
            Write-Verbose      "$TimeStamp : LOG   : Created splat to create CimSession"
            $ReturnMessage  += "$TimeStamp : LOG   : Created splat to create CimSession"                              
            If ($Boolean_Cred -eq $true) {
                $Sessionsplat.add("Credential", $Credential)
                Write-Verbose     "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
                $ReturnMessage += "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"   
                $Credential     = $null             
            }
            $Session         = New-CimSession @Sessionsplat
            Write-Verbose      "$TimeStamp : LOG   : Build CimSession $Session to server $Server."
            $ReturnMessage  += "$TimeStamp : LOG   : Build CimSession $Session to server $Server."
        } Catch {
            Write-Verbose      "$Timestamp : ERROR : Could not build CimSession to server $Server."
            Write-Verbose      "$Timestamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not build CimSession to server $Server."
            $ReturnMessage  += "$Timestamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
        If ($Boolean_Cred -eq $true) {$Sessionsplat.Credential = $null}
    }

    ##Collect all scopes
    [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $ScopeIDs        = Get-DhcpServerv4Scope -CimSession $Session | Where-Object -FilterScript {$_.State -eq 'Active'} | Select-Object -Property $DHCPProperties
            Write-Verbose      "$TimeStamp : LOG   : Collected ScopeID's for active scopes ($($ScopeIDs.Count))"
            $ReturnMessage  += "$TimeStamp : LOG   : Build CimSession $Session to server $Server."
        } Catch {
            Write-Verbose      "$Timestamp : ERROR : Could not collect ScopeID's for active scopes."
            Write-Verbose      "$Timestamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not collect ScopeID's for active scopes."
            $ReturnMessage  += "$Timestamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false            
        }    
    }

    ##Loop through scopes
    [String]  $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Foreach ($ScopeID in $ScopeIDs) {
            [PSObject] $Result   = $null
            Write-Verbose      "$Timestamp : LOG   : Looping through scopeID's ($($ScopeID.ScopeID.IPAddressToString))"
            $ReturnMessage  += "$Timestamp : LOG   : Looping through scopeID's ($($ScopeID.ScopeID.IPAddressToString))"
            Try {
                $Result          = Get-DhcpServerv4ScopeStatistics -ScopeId $($ScopeID.ScopeID) -CimSession $Session | Select-Object -Property Free,PercentageInUse
                Write-Verbose      "$TimeStamp : LOG   : Collected ScopeStatistics for scope $($ScopeID.IPAddressToString)."
                Write-Verbose      "$TimeStamp : LOG   : Free Addresses    : $($Result.Free)."
                Write-Verbose      "$TimeStamp : LOG   : Percentage in use : $($Result.PercentageInUse)."
                Write-Verbose      "$TimeStamp : LOG   : Name              : $($ScopeID.Name)."
                Write-Verbose      "$TimeStamp : LOG   : Long Name         : $($ScopeID.Name + ' (' +  $ScopeID.StartRange.IPAddressToString + ' - ' + $ScopeID.EndRange.IPAddressToString + ')')."
                $ReturnMessage  += "$TimeStamp : LOG   : Collected ScopeStatistics for scope $($ScopeID.IPAddressToString)."
                $ReturnMessage  += "$TimeStamp : LOG   : Free Addresses    : $($Result.Free)."
                $ReturnMessage  += "$TimeStamp : LOG   : Percentage in use : $($Result.PercentageInUse)."
                $ReturnMessage  += "$TimeStamp : LOG   : Name              : $($ScopeID.Name)."
                $ReturnMessage  += "$TimeStamp : LOG   : Long Name         : $($ScopeID.Name + ' (' +  $ScopeID.StartRange.IPAddressToString + ' - ' + $ScopeID.EndRange.IPAddressToString + ')')."                
                $Result | Add-Member -NotePropertyName LongName -NotePropertyValue $($ScopeID.Name + ' (' +  $ScopeID.StartRange.IPAddressToString + ' - ' + $ScopeID.EndRange.IPAddressToString + ')')
                $Result | Add-Member -NotePropertyName Name     -NotePropertyValue $($ScopeID.Name)
                $Return_Array   += $Result
            } Catch {
                Write-Verbose      "$Timestamp : ERROR : Could not collect ScopeStatistics for scope $($ScopeID.ScopeID.IPAddressToString)."
                Write-Verbose      "$Timestamp : ERROR : $($_.Exception.Message)"
                $ReturnMessage  += "$TimeStamp : ERROR : Could not collect ScopeStatistics for scope $($ScopeID.ScopeID.IPAddressToString)."
                $ReturnMessage  += "$Timestamp : ERROR : $($_.Exception.Message)"
                $Boolean_Success = $false   
            }
        }
        $Session | Remove-CimSession
    }

    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-verbose     "$TimeStamp : LOG   : Returning.."
        $ReturnMessage += "$TimeStamp : LOG   : Returning.."
        Return $Return_Array
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function returned error."
        Write-Verbose     "$TimeStamp : ERROR : Function returned error."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Connect-PRTGtoSCCMviaWMI
#Function for connecting to a SCCM Siteserver and running a Query against WMI
Function Connect-PRTGtoSCCMviaWMI {
    [cmdletbinding()] Param (
            [Parameter(Mandatory=$true, Position=1 )]  [String]       $Site,
            [Parameter(Mandatory=$true, Position=2 )]  [String]       $SiteServer,
            [Parameter(Mandatory=$true, Position=3 )]  [String]       $Query,
            [Parameter(Mandatory=$false)] [PSCredential] $Credential
    )
    ##Variables
    [Boolean] $Boolean_Success = $true
    [Boolean] $Boolean_Cred    = $false
    If ($Credential) { $Boolean_Cred = $true }

    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [Array]     $ReturnMessage   = @()
    [PSObject]  $ReturnObj = $null
    [PSObject]  $Respons   = $null
    [Hashtable] $WMISplat = @{}

    Write-Verbose     "$TimeStamp : FUNCTION : Connect-PRTGtoSCCMviaWMI"
    Write-Verbose     "$TimeStamp : PARAM : Site  : $Site"
    Write-Verbose     "$TimeStamp : PARAM : Query : $(If ($Query.Length -gt 15) {$Query.Substring(0,12) + '...'} Else {$Query})"
    Write-Verbose     "$TimeStamp : PARAM : SiteServer: $SiteServer"
    Write-Verbose     "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : Connect-PRTGtoSCCMviaWMI"
    $ReturnMessage += "$TimeStamp : PARAM : Site  : $Site"
    $ReturnMessage += "$TimeStamp : PARAM : Query : $(If ($Query.Length -gt 15) {$Query.Substring(0,12) + '...'} Else {$Query})"
    $ReturnMessage += "$TimeStamp : PARAM : SiteServer: $SiteServer"
    $ReturnMessage += "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"

    ##Query WMI on the siteserver
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $WMISplat = @{
                NameSpace    = [String] "root\sms\Site_$site"
                Query        = [String] $Query
                ComputerName = [String] $SiteServer
            }
            Write-Verbose      "$TimeStamp : LOG   : Created splat to query WMI"
            $ReturnMessage  += "$TimeStamp : LOG   : Created splat to query WMI"
            If ($Boolean_Cred -eq $true) {
                $WMISplat.Add("Credential",$Credential)
                $Credential      = $null
                Write-Verbose      "$TimeStamp : LOG   : Added credentials to the splat ($($Credential.UserName))."
                $ReturnMessage  += "$TimeStamp : LOG   : Added credentials to the splat ($($Credential.UserName))."                
            }            
            $Respons         = Get-WmiObject @WMISplat
            Write-Verbose      "$TimeStamp : LOG   : Queried WMI on siteserver $siteServer / Site $Site."
            $ReturnMessage  += "$TimeStamp : LOG   : Queried WMI on siteserver $siteServer / Site $Site."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not query WMI on siteserver $siteServer / Site $Site."
            Write-Verbose      "$TimeStamp : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not query WMI on siteserver $siteServer / Site $Site."
            $ReturnMessage  += "$TimeStamp : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
        If ($Boolean_Cred -eq $true) {$WMISplat.Credential = $null}
    }
    
    ## Create return-object
    [String]  $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    Write-Verbose     "$Timestamp : LOG   : Created return-object, and returning."
    $ReturnMessage += "$Timestamp : LOG   : Created return-object, and returning."
    $ReturnObj      = New-Object -TypeName PSObject -Property @{
        Result  = [Boolean]  $Boolean_Success
        Return  = [PSObject] $Respons
        Message = [String]   ($ReturnMessage -join "`n")
    }
    Return $ReturnObj
}

##Function Connect-PRTGtoSCCMforSiteCode
#Function for collecting the SCCM Sitecode for an SCCM Site from the siteserver
Function Connect-PRTGtoSCCMforSiteCode {
    [cmdletbinding()] Param (
            [Parameter(Mandatory=$true, Position=1 )]  [String] $SiteServer,
            [Parameter(Mandatory=$false )] [PSCredential] $Credential
    )
    ##Variables
    [String]    $SiteCode  = $null
    [Array]     $WMIArray  = @()
    [Array]     $ReturnMessage = @()
    [String]    $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    [Hashtable] $WMISplat  = @{}
    [Boolean]   $Boolean_Success = $true
    [Boolean]   $Boolean_Cred    = $false
    If ($Credential) { $Boolean_Cred = $true }

    Write-Verbose     "$TimeStamp : FUNCTION : Connect-PRTGtoSCCMforSiteCode"
    Write-Verbose     "$TimeStamp : PARAM : SiteServer: $SiteServer"
    Write-Verbose     "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : Connect-PRTGtoSCCMforSiteCode"
    $ReturnMessage += "$TimeStamp : PARAM : SiteServer: $SiteServer"
    $ReturnMessage += "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"

    ##Collect data from WMI
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $WMISplat = @{
                ComputerName = $Siteserver
                NameSpace    = 'root\SMS'
                Class        = 'SMS_ProviderLocation'
            }
            Write-Verbose      "$TimeStamp : LOG   : Created splat to query WMI"
            $ReturnMessage  += "$TimeStamp : LOG   : Created splat to query WMI"            
            If ($Boolean_Cred -eq $true) {
                $WMISplat.add("Credential", $Credential)
                Write-Verbose      "$TimeStamp : LOG   : Added credentialObject ($($Credential.Username))"
                $ReturnMessage  += "$TimeStamp : LOG   : Added credentialObject ($($Credential.Username))"  
                $Credential      = $null              
            }
            $WMIArray        = Get-WMIObject @WMISplat
            Write-Verbose      "$TimeStamp : LOG   : Collected WMIObject SMS_ProviderLocation. ($($WMIArray.Count) entries)"
            $ReturnMessage  += "$TimeStamp : LOG   : Collected WMIObject SMS_ProviderLocation. ($($WMIArray.Count) entries)"            
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not query WMI on siteserver $siteServer / Site $Site."
            Write-Verbose      "$TimeStamp : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not query WMI on siteserver $siteServer / Site $Site."
            $ReturnMessage  += "$TimeStamp : $($_.Exception.Message)"
            $Boolean_Success = $false            
        }
        If ($Boolean_Cred -eq $true) {$WMISplat.Credential = $null}
    }

    ##Looping through resultset to filter out SSMSSiteCode
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm    
    If ($Boolean_Success -eq $true) {
        ForEach ($Item in $WMIArray) {
            If ($Item.ProviderForLocalSite -eq $true){
                $SiteCode        = $Item.sitecode
                Write-Verbose      "$TimeStamp : LOG   : Collected sitecode $SiteCode as LocalProvider."
                $ReturnMessage  += "$TimeStamp : LOG   : Collected sitecode $SiteCode as LocalProvider."
            }
        }
        If ( !($SiteCode) ) {
            Write-Verbose     "$TimeStamp : LOG   : Could nog select SCCM sidecode from WMI."
            $ReturnMessage += "$TimeStamp : LOG   : Could nog select SCCM sidecode from WMI."
            $Boolean_Success = $false
        }
    }

    ##Returning...
    If ($Boolean_Success -eq $true) {
        Write-Verbose     "$Timestamp : LOG   : Returning.."
        $ReturnMessage += "$Timestamp : LOG   : Returning.."
        Return $SiteCode
    } Else {
        Write-Verbose     "$Timestamp : ERROR : Function not successfull"
        $ReturnMessage += "$Timestamp : ERROR : Function not successfull"
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGClientRegistryValue
#Function for collecting a value from a remote registry
Function Get-PRTGClientRegistryValue {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1 )] [ValidateSet('HKRoot','HKCU','HKLM','HKU','HCC')] [String] $Registryhyve,
        [Parameter(Mandatory=$true, Position=2 )] [ValidateSet('DWord','String')] [String] $DataType,
        [Parameter(Mandatory=$true, Position=3 )] [String] $Registry,
        [Parameter(Mandatory=$true, Position=4 )] [String] $Name,
        [Parameter(Mandatory=$false)][String] $Computer,
        [Parameter(Mandatory=$false)][PSCredential] $Credential
    )

    ##Variables
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [Boolean]   $Boolean_Success = $true
    [Boolean]   $Boolean_Cred    = $true
    [String]    $Name_RegistryProvider = "StdRegProv"
    [String]    $NameSpace             = "root\default"
    [String]    $RegistryValue         = $null
    [String]    $DataTypeValue         = $null
    [PSObject]  $WMIObj                = $null
    [Hashtable] $RegSplat              = @{}   
    [Array]     $ReturnMessage         = @() 

    If ( $Credential ) { $Boolean_cred = $true }

    [Array] $DataType_Array = @(
        @{
            KeyName = "DWord";
            Call = "uValue"
        },
        @{
            KeyName = "String";
            Call = "sValue"
        }        
    )

    [Array] $Classes_Regkey = @(
        @{
            FullName  = "HKEY_CLASSES_ROOT";
            ShortName = "HKRoot";
            Value     = 2147483648
        },
        @{
            FullName  = "HKEY_CURRENT_USER";
            ShortName = "HKCU";
            Value     = 2147483649
        },
        @{
            FullName  = "HKEY_LOCAL_MACHINE";
            ShortName = "HKLM";
            Value     = 2147483650
        },
        @{
            FullName  = "HKEY_USERS";
            ShortName = "HKU"
            Value     = 2147483651
        },
        @{
            FullName  = "HKEY_CURRENT_CONFIG"
            ShortName = "HCC"
            Value     = 2147483653
        }
    )

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGClientRegistryValue"
    Write-Verbose     "$TimeStamp : PARAM : Registryhyve : $Registryhyve"
    Write-Verbose     "$TimeStamp : PARAM : Registry     : $Registry"
    Write-Verbose     "$TimeStamp : PARAM : DataType     : $DataType"
    Write-Verbose     "$TimeStamp : PARAM : Name         : $Name"
    Write-Verbose     "$TimeStamp : PARAM : Computer     : $Computer"
    Write-Verbose     "$TimeStamp : PARAM : Use Creds    : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGClientRegistryValue"
    $ReturnMessage += "$TimeStamp : PARAM : Registryhyve : $Registryhyve"
    $ReturnMessage += "$TimeStamp : PARAM : Registry     : $Registry"
    $ReturnMessage += "$TimeStamp : PARAM : DataType     : $DataType"    
    $ReturnMessage += "$TimeStamp : PARAM : Name         : $Name"
    $ReturnMessage += "$TimeStamp : PARAM : Computer     : $Computer"
    $ReturnMessage += "$TimeStamp : PARAM : Use Creds    : $Boolean_Cred"

    ##Select value for registry
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    Write-Verbose     "$TimeStamp : LOG   : Collecting numeric value for registry hyve."
    $ReturnMessage += "$TimeStamp : LOG   : Collecting numeric value for registry hyve."
    $RegValue       = ($Classes_Regkey | Where-Object -FilterScript {$_.ShortName -eq "$Registryhyve"}).value
    $DataTypeValue  = ($DataType_Array | Where-Object -FilterScript {$_.KeyName   -eq "$DataType"}).call

    ##Collect registry-setting from WMI with credentials
    If ($Boolean_Success -eq $true) {
        Try {
            $RegSplat = @{
                List = $true
                NameSpace = $NameSpace
                Computer  = $Computer
            }
            If ($Boolean_Cred -eq $true) {
                $RegSplat.add("Credential", $Credential)
                $Credential = $null
                Write-Verbose      "$TimeStamp : LOG   : Added credentials to the splat ($($Credential.UserName))."
                $ReturnMessage  += "$TimeStamp : LOG   : Added credentials to the splat ($($Credential.UserName))."                
            }
            $WMIObj = Get-WmiObject @RegSplat | Where-Object -FilterScript { $_.Name -eq $Name_RegistryProvider }
            Write-Verbose      "$TimeStamp : LOG   : Collected registry from WMI."
            $ReturnMessage  += "$TimeStamp : LOG   : Collected registry from WMI."
            $RegistryValue   = $RegistryWMI_Object.GetStringValue($RegValue,"$Registry","$Name").$DataTypeValue
            Write-Verbose      "$TimeStamp : LOG   : Collected registryvalue $RegistryValue for key $Name on path $Registry."
            $ReturnMessage  += "$TimeStamp : LOG   : Collected registryvalue $RegistryValue for key $Name on path $Registry."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Cannot collect value for registrykey."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage  += "$TimeStamp : ERROR : Cannot collect value for registrykey."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Boolean_Success = $false
        }
        If ($Boolean_Cred -eq $true) {$RegSplat.Credential = $null}
    }

    ##Returning...
    If ($Boolean_Success -eq $true) {
        Write-Verbose     "$Timestamp : LOG   : Returning.."
        $ReturnMessage += "$Timestamp : LOG   : Returning.."
        Return $RegistryValue
    } Else {
        Write-Verbose     "$Timestamp : ERROR : Function not successfull"
        $ReturnMessage += "$Timestamp : ERROR : Function not successfull"
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGClientMaintenanceWindow
#Function for collecting the previous and next maintenancewindow on a SCCM Managed client
Function Get-PRTGClientMaintenanceWindow {
    [cmdletbinding()] Param ( 
        [Parameter(Mandatory=$true, Position=1 )] [String] $Server, 
        [Parameter(Mandatory=$false)] [PSCredential] $Credential
    )
    
    ##Variables
    [Boolean]  $Boolean_Success  = $true
    [Boolean]  $Boolean_Cred     = $false
    [Array]    $ReturnMessage    = @()
    [String]   $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
    [String]   $Query            = "Select type,starttime,endtime,duration from CCM_serviceWindow where (type=2) or (type=4)"
    [Array]    $MWindows_Array   = @()
    [Hashtable] $WMISplat        = @{}

    If ($Credential) { $Boolean_Cred = $true }

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGClientMaintenanceWindow"
    Write-Verbose     "$TimeStamp : PARAM : Server    : $Server"
    Write-Verbose     "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGClientMaintenanceWindow"
    $ReturnMessage += "$TimeStamp : PARAM : Server    : $Site"
    $ReturnMessage += "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"

    ##Collect maintenancewindows on client
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            Write-Verbose     "$TimeStamp : LOG   : Collecting maintenancewindow on server using WMI."
            $ReturnMessage += "$TimeStamp : LOG   : Collecting maintenancewindow on server using WMI."
            $WMISplat = @{
                Namespace    = "root\ccm\clientsdk"
                Query        = $Query
                ComputerName = $Server
            }
            If ($Boolean_Cred -eq $true) {
                $WMISplat.add("Credential", $Credential)
                Write-Verbose     "$TimeStamp : LOG   : Added credentials for $($Credential.UserName)"
                $ReturnMessage += "$TimeStamp : LOG   : Added credentials for $($Credential.UserName)"
                $Credential     = $null
            }
            $MWindows_Array  = Get-WmiObject @WMISplat | Sort-Object -Property 'StartTime'
            Write-Verbose      "$TimeStamp : LOG   : Collected $($MWindows_Array.Count) Maintenancewindows."
            $ReturnMessage  += "$TimeStamp : LOG   : Collected $($MWindows_Array.Count) Maintenancewindows."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not collect MaintenanceWindows."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not collect MaintenanceWindows."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
        If ($Boolean_Cred -eq $true) {$WMISplat.Credential = $null}
    }
    
    ##Select the next maintenancewindow
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            Write-Verbose      "$TimeStamp : LOG   : Collecting first maintenancewindow."
            $ReturnMessage  += "$TimeStamp : LOG   : Collecting first maintenancewindow."
            $Next_StartTime  = ([System.Management.ManagementDateTimeconverter]::ToDateTime( $($MWindows_Array[0].StartTime) ) )
            $Next_EndTime    = ([System.Management.ManagementDateTimeconverter]::ToDateTime( $($MWindows_Array[0].Endtime) ) )
            Write-Verbose      "$TimeStamp : LOG   : Collected startTime $Next_StartTime / EndTime $Next_EndTime."
            $ReturnMessage  += "$TimeStamp : LOG   : Collected startTime $Next_StartTime / EndTime $Next_EndTime."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not sort and select MaintenanceWindows."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not sort and select MaintenanceWindows."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false                        
        }
     }
   
    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $false) {
        $Return_object = New-Object -TypeName PSObject -Property @{
            StartTime     = [DateTime] $Next_StartTime
            Endtime       = [DateTime] $Next_EndTime
        }
        Write-Verbose "$TimeStamp : LOG   : Created returnobject, returning.."
        Return $Return_Object
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGClientUpdateStatus
#Function for collecting the Windows update status from a SCCM Managed client
Function Get-PRTGClientUpdateStatus {
    [cmdletbinding()] Param ( 
            [Parameter(Mandatory=$true, Position=1 )] [String] $Server,
            [Parameter(Mandatory=$false)] [PSCredential] $Credential
    )
    ##Variables
    [Boolean]   $Boolean_Success = $true
    [boolean]   $Boolean_Cred    = $false
    [Array]     $ReturnMessage   = @()
    [Array]     $WMIResult       = @()
    [Array]     $ResultArray     = @()
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [String]    $NameSpace       = "ROOT\ccm\SoftwareUpdates\UpdatesStore"
    [PSObject]  $ReturnObj       = $null
    [Hashtable] $WMISplat        = @{}

    [String]    $Query_Missing   = "Select Title, ScanTime, Status, UniqueID from CCM_UpdateStatus where Status='Missing' AND NOT Title LIKE `"Definition%`" AND NOT Title LIKE `"Definitie-update%`" AND NOT Title LIKE `"%Malicious Software Removal Tool%`" AND NOT Title LIKE `"%verwijderen van schadelijke software%`" AND NOT `"%Beveiligingsinformatie-update%`""
    [String]    $Query_Installed = "Select Title, ScanTime, Status, UniqueID from CCM_UpdateStatus where Status='Installed' AND NOT Title LIKE `"Definition%`" AND NOT Title LIKE `"Definitie-update%`" AND NOT Title LIKE `"%Malicious Software Removal Tool%`" AND NOT Title LIKE `"%verwijderen van schadelijke software%`" AND NOT `"%Beveiligingsinformatie-update%`""
    [String]    $Query_Failed    = "Select Title, ScanTime, Status, UniqueID from CCM_UpdateStatus where Status!='Missing' AND Status!='Installed' AND NOT Title LIKE `"Definition%`" AND NOT Title LIKE `"Definitie-update%`" AND NOT Title LIKE `"%Malicious Software Removal Tool%`" AND NOT Title LIKE `"%verwijderen van schadelijke software%`" AND NOT `"%Beveiligingsinformatie-update%`""
    [Array]     $QueryArray      = @($Query_Missing,$Query_Installed,$Query_Failed)

    If ($Credential) { $Boolean_Cred = $true }

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGClientUpdateStatus"
    Write-Verbose     "$TimeStamp : PARAM : Server    : $Server"
    Write-Verbose     "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGClientUpdateStatus"
    $ReturnMessage += "$TimeStamp : PARAM : Server    : $Site"
    $ReturnMessage += "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"

    ##Building splat for calling to WMI
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose     "$TimeStamp : LOG   : Collecting windows update status from local SCCM client via WMI"
        $ReturnMessage += "$TimeStamp : LOG   : Collecting windows update status from local SCCM client via WMI"
        $WMISplat = @{
            NameSpace    = $NameSpace
            ComputerName = $Server
            Query        = [String] $null
        }
        If ($Boolean_Cred -eq $true) {
            $WMISplat.add("Credential", $Credential)
            Write-Verbose     "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
            $ReturnMessage += "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
            $Credential     = $null
        }
    }

    ##Collecting update-status from server using WMI
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {    
        Foreach ($Query in $QueryArray) {
            Try {
                [Array] $WMIResult = @()
                Write-Verbose      "$TimeStamp : LOG   : Using query $($Query.Substring(0,15))."
                $ReturnMessage  += "$TimeStamp : LOG   : Using query $($Query.Substring(0,15))."
                $WMISplat.Query  = $Query
                $WMIResult       = Get-WmiObject $WMISplat | Sort-Object -Property "Title" -Unique
                Write-Verbose      "$TimeStamp : LOG   : Collected $($WMIResult.Count) updates, adding to resultArray."
                $ReturnMessage  += "$TimeStamp : LOG   : Collected $($WMIResult.Count) updates, adding to resultArray."                
                $ResultArray    += $WMIResult
            } Catch {
                Write-Verbose      "$TimeStamp : ERROR : Could not collect Windows update status from local SCCM client."
                Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
                $ReturnMessage  += "$TimeStamp : ERROR : Could not collect Windows update status from local SCCM client."
                $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
                $Boolean_Success = $false
            }
        }
        If ($Boolean_Cred -eq $true) {$WMISplat.Credential = $null}
    }

    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$TimeStamp : LOG   : Building return-object, and returning."
        $ReturnMessage  += "$TimeStamp : LOG   : Building return-object, and returning."
        $ReturnObj       = New-Object -TypeName PSObject -Property @{
            Updates_missing    = $ResultArray[0]
            Updates_installed  = $ResultArray[1]
            Updates_failed     = $ResultArray[2]
        }
        Return $ReturnObj
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGClientLastReboot
#Function for collecting the last time a client rebooted
Function Get-PRTGClientLastReboot {
    [cmdletbinding()] Param ( 
        [Parameter(Mandatory=$true, Position=1 )] [String] $Server, 
        [Parameter(Mandatory=$false)] [PSCredential] $Credential 
    )

    ##Variables
    [Boolean]  $Boolean_Success  = $true
    [Boolean]  $Boolean_Cred     = $false
    [Array]    $ReturnMessage    = $null
    [String]   $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
    [String]   $Query            = "Select lastbootuptime from win32_operatingsystem"
    [DateTime] $LastBootTime     = 0
    [String]   $StringTime       = $null

    If ($Credential) { $Boolean_Cred = $true }

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGClientLastReboot"
    Write-Verbose     "$TimeStamp : PARAM : Server    : $Server"
    Write-Verbose     "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGClientLastReboot"
    $ReturnMessage += "$TimeStamp : PARAM : Server    : $Site"
    $ReturnMessage += "$TimeStamp : PARAM : Use Creds : $Boolean_Cred"

    ##Collect last reboot from server using WMI
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            Write-Verbose     "$TimeStamp : LOG   : Using query $Query."
            $ReturnMessage += "$TimeStamp : LOG   : Using query $Query."
            $WMISplat = @{
                NameSpace = "Root\Cimv2"
                Query     = $Query
                ComputerName = $Server
            }

            If ($Boolean_Cred -eq $true) {
                $WMISplat.add("Credential", $Credential)
                Write-Verbose     "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
                $ReturnMessage += "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
                $Credential     = $null
            }
            $StringTime      = (Get-WmiObject $WMISplat).LastBootUptime
            Write-Verbose      "$TimeStamp : LOG   : Collected LastBootTime $StringTime"
            $ReturnMessage  += "$TimeStamp : LOG   : Collected LastBootTime $StringTime"
            $LastBootTime    = [System.Management.ManagementDateTimeconverter]::ToDateTime($StringTime)
            Write-Verbose      "$TimeStamp : LOG   : Converted to $LastBootTime."
            $ReturnMessage  += "$TimeStamp : LOG   : Converted to $LastBootTime."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not collect LastBootTime."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not collect LastBootTime."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
        If ($Boolean_Cred -eq $true) { $WMISplat.Credential = $null }
    }
   
    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$TimeStamp : LOG   : Returning..."
        $ReturnMessage  += "$TimeStamp : LOG   : Returning..."
        Return $LastBootTime
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Get-DellAccessToken (25-12-2019)
#Function to collect an AccessToken from the Dell TechApi v.5
Function Get-DellAccessToken {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1 )] [String] $ApiKey,
        [Parameter(Mandatory=$true, Position=2 )] [String] $SharedSecret,
        [Parameter(Mandatory=$false)] [String]  $Uri = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
    )
    ##Variables
    [Array]     $ReturnMessage = @()
    [String]    $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
    [PSObject]  $TokenObj      = $null
    [Hashtable] $Auth_Body = @{
        'grant_type'     = "client_credentials"
        'client_id'      = [String] $ApiKey
        'client_secret'  = [String] $SharedSecret
        'Content-Type'   = "application/x-www-form-urlencoded"
    }
    
    Write-Verbose     "$Timestamp : FUNCTION: Get-DellAccessToken"
    Write-Verbose     "$TimeStamp : PARAM : Uri    : $Uri"
    Write-Verbose     "$TimeStamp : PARAM : Apikey : $ApiKey"
    Write-Verbose     "$TimeStamp : PARAM : Secret : $($SharedSecret.substring(0,3) + '..')"
    $ReturnMessage += "$Timestamp : FUNCTION: Get-DellAccessToken"
    $ReturnMessage += "$TimeStamp : PARAM : Uri    : $Uri"
    $ReturnMessage += "$TimeStamp : PARAM : Apikey : $ApiKey"
    $ReturnMessage += "$TimeStamp : PARAM : Secret : $($SharedSecret.substring(0,3) + '..')"

    Try {
        $TokenObj       = Invoke-RestMethod -Uri $uri -Method Post -Body $Auth_Body
        Write-Verbose     "$TimeStamp : LOG   : Collected token, valid for $($TokenObj.expires_in) seconds."
        $ReturnMessage += "$TimeStamp : LOG   : Collected token, valid for $($TokenObj.expires_in) seconds."
        Return $($TokenObj.access_token)
    } catch {
        $ReturnMessage += "$TimeStamp : ERROR : Could not collect Access-token."
        $ReturnMessage += "$TimeStamp : ERROR : $($_.Exception.Message) `n"
        Write-Verbose     "$TimeStamp : ERROR : Could not collect Access-token."
        Write-Verbose     "$TimeStamp : ERROR : $($_.Exception.Message)"
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Get-DellWarantyInfo (25-12-2019)
#Function to collect WarrantyInfo from the Dell TechApi v.5
Function Get-DellWarantyInfo {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1)] [String] $Token,
        [Parameter(Mandatory=$true, Position=2)] [Array]  $Assettags,
        [Parameter(Mandatory=$false)] [String]  $Uri        = "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements",
        [Parameter(Mandatory=$false)] [Int]     $Resultsize = 50
    )    
    ##Variables
    [Boolean]   $Boolean_Success = $true
    [Array]     $ReturnMessage   = @()
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [Int]       $Runs            = 0
    [Int]       $Lastcall        = 0   
    [Int]       $Count           = 0
    [Array]     $Result          = @()
    [PSObject]  $Return          = $null
    [Hashtable] $params = @{}    

    ##HeaderObject
    [Hashtable] $Headers = @{
        'Accept'        = "application/json"
        'Authorization' = "Bearer $Token" 
    }

    Write-Verbose     "$Timestamp : FUNCTION: Get-DellWarantyInfo"
    Write-Verbose     "$TimeStamp : PARAM : Uri    : $Uri"
    Write-Verbose     "$TimeStamp : PARAM : Token  : $($Token.substring(0,3) + '..')"
    Write-Verbose     "$TimeStamp : PARAM : Assettags : $($Assettags -join ',')"
    Write-Verbose     "$TimeStamp : PARAM : Resultsize: $Resultsize"
    $ReturnMessage += "$Timestamp : FUNCTION: Get-DellWarantyInfo"
    $ReturnMessage += "$TimeStamp : PARAM : Uri    : $Uri"
    $ReturnMessage += "$TimeStamp : PARAM : Token  : $($Token.substring(0,3) + '..')"
    $ReturnMessage += "$TimeStamp : PARAM : Assettags : $($Assettags -join ',')"
    $ReturnMessage += "$TimeStamp : PARAM : Resultsize: $Resultsize"
    
    ##Calculate runs
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    $Runs           = [math]::floor($($Assettags.Count) / $Resultsize)
    $Lastcall       = $($Assettags.Count) - ($Resultsize * $Runs) -1
    Write-verbose     "$TimeStamp : LOG   : With $Assettag_Count devices and $Resultsize devices per run,"
    Write-verbose     "$TimeStamp : LOG   : script will run $Runs loops of $Resultsize devices, and 1 run of $LastCall devices."
    $ReturnMessage += "$TimeStamp : LOG   : With $Assettag_Count devices and $Resultsize devices per run,"
    $ReturnMessage += "$TimeStamp : LOG   : script will run $Runs loops of $Resultsize devices, and 1 run of $LastCall devices."

    ##Looping through the snow, on a one-horse open sleigh
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    While ($Count -lt $Runs) {
        [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
        Write-verbose     "$TimeStamp : LOG   : Running loop $Count for clients $($Count*$Resultsize) / $(($Count*$Resultsize) + ($Resultsize-1))"
        $ReturnMessage += "$TimeStamp : LOG   : Running loop $Count for clients $($Count*$Resultsize) / $(($Count*$Resultsize) + ($Resultsize-1))"
        
        [PSObject]  $Return          = $null
        [Hashtable] $params = @{}

        [Hashtable] $params = @{
            Uri         = [String]    $Uri
            Headers     = [Hashtable] $Headers
            Method      = "GET"
            Body        = [Hashtable] @{ "servicetags" = [String] $($Assettags[$($Count*$Resultsize) .. $(($Count*$Resultsize) + ($Resultsize-1))] -join (','))}
            ContentType = 'application/json'    
        } 
        Try {
            $Return = Invoke-RestMethod @Params
            Write-Verbose     "$TimeStamp : LOG   : Collected data from REST-api."
            $ReturnMessage += "$TimeStamp : LOG   : Collected data from REST-api."
            $Result += $Return
        } Catch {
            $Count = $Runs
            $Boolean_Success = $false
            Write-verbose      "$TimeStamp : ERROR : Could not collect data from REST-api."
            Write-verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not collect data from REST-api."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message) `n"
        }
        $Count++
    }

    ##Calling the rest
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$TimeStamp : LOG   : Calling for $($Count*$Resultsize) / $( ($Count*$Resultsize) + $Lastcall)"
        $ReturnMessage  += "$TimeStamp : LOG   : Calling for $($Count*$Resultsize) / $( ($Count*$Resultsize) + $Lastcall)"
        [PSObject]  $Return = $null
        [Hashtable] $params = @{}

        Try {
            $params = @{
                Uri         = $Uri;
                Headers     = $Headers;
                Method      = "GET"
                Body        = [Hashtable] @{servicetags = [String] $($Assettags[$($Count*$Resultsize) .. $(($Count*$Resultsize) + $Lastcall)] -join (', '))}
                ContentType = 'application/json'    
            } 
            $Return          = Invoke-RestMethod @Params
            Write-Verbose      "$TimeStamp : LOG   : Collected data from REST-api for LastCall objects."
            $ReturnMessage  += "$TimeStamp : LOG   : Collected data from REST-api for LastCall objects."
            $Result         += $Return
        } Catch {
            $Boolean_Success = $false
            Write-verbose      "$TimeStamp : ERROR : Could not collect data from REST-api for LastCall objects."
            Write-verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not collect data from REST-api for LastCall objects."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message) `n"
        } 
    }

    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-verbose     "$TimeStamp : LOG   : Returning.."
        $ReturnMessage += "$TimeStamp : LOG   : Returning.."
        Return $Result
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function returned error."
        Write-Verbose     "$TimeStamp : ERROR : Function returned error."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGIPAddressesInSubnet
#Function for collecting all addresses in a CDR block
Function Get-PRTGIPAddressesInSubnet {
    Param(
        [Parameter(Mandatory = $true, Position=1 )]  [String] $IP,
        [Parameter(Mandatory = $true, Position=2 )]  [Int]    $subnet,
        [Parameter(Mandatory = $false)] [Switch] $IPv6
    )
    ##Variables
    [String]  $Timestamp       = Get-Date -format yyyy.MM.dd.hh:mm
    [Boolean] $Boolean_Success = $true
    [Boolean] $Boolean_IPv6    = $false
    If ($IPv6) { $Boolean_IPv6 = $true}
    
    [Array]  $ReturnMessage   = @()
    [Array]  $IPAdresses = @()
    [String] $IPBinary   = $null
    [Int]    $Count      = 0
    [Int]    $Count_max  = 0
    
    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGIPAddressesInSubnet"
    Write-Verbose     "$TimeStamp : PARAM : Ip    : $Ip"
    Write-Verbose     "$TimeStamp : PARAM : Subnet: $Subnet"
    Write-Verbose     "$TimeStamp : PARAM : IPv6  : $Boolean_IPv6"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGIPAddressesInSubnet"
    $ReturnMessage += "$TimeStamp : PARAM : Ip    : $Ip"
    $ReturnMessage += "$TimeStamp : PARAM : Subnet: $Subnet"
    $ReturnMessage += "$TimeStamp : PARAM : IPv6  : $Boolean_IPv6"

    ##Determining what mode to run in 
    [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm    
    If ($Boolean_IPv6 -eq $true) {
        Write-Verbose     "$TimeStamp : LOG   : IPv6-mode not yet available."
        $ReturnMessage += "$TimeStamp : LOG   : IPv6-mode not yet available."
        $IPAdresses = $IP
    } 
            
    #Calculate IPSpace
    [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm 
    If ( ($Boolean_Success -eq $true) -and ($Boolean_IPv6 -eq $false) ) {
        Try {
            $IPBinary        = ($IP.split('.') | Foreach-Object {("0" * (8 - ([convert]::ToString($_,2)).Length) + ([convert]::ToString($_,2)))}) -join ""
            $NetworkID       = $IPBinary.Substring(0,$subnet)
            $HostID          = ($IPBinary.Substring($Subnet,(32-$Subnet) )).Replace("1","0")
            $Count_max       = [convert]::ToInt32(("1" * (32-$Subnet)),2) -1
            Write-Verbose      "$TimeStamp : LOG   : Converted IP to Binary   : $IPBinary"
            Write-Verbose      "$TimeStamp : LOG   : Collected NetworkID-part : $NetworkID"
            Write-Verbose      "$TimeStamp : LOG   : Collected HostID-part    : $( (' '*($NetworkID.length)) + $HostID)"
            Write-Verbose      "$TimeStamp : LOG   : Will collect $Count_Max addresses."
            $ReturnMessage  += "$TimeStamp : LOG   : Converted IP to Binary   : $IPBinary"
            $ReturnMessage  += "$TimeStamp : LOG   : Collected NetworkID-part : $NetworkID"
            $ReturnMessage  += "$TimeStamp : LOG   : Collected HostID-part    : $( (' '*($NetworkID.length)) + $HostID)"
            $ReturnMessage  += "$TimeStamp : LOG   : Will collect $Count_Max addresses."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Cannot write IP-space to binary."
            Write-Verbose      "$TimeStamp : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Cannot write IP-space to binary."
            $ReturnMessage  += "$TimeStamp : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }

    ##Looping through binary addresses
    [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm 
    If ( ($Boolean_Success -eq $true) -and ($Boolean_IPv6 -eq $false) ) {
        While ($Count -lt $Count_max) {
            [Int]    $Count_Octet     = 0
            [Array]  $Octet           = @()
            [Int32]  $NextHostDecimal = 0
            [String] $NextHost        = $null
            [String] $NextIP          = $null
            $Count++

            ##Collect next ip
            [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm 
            If ($Boolean_Success -eq $true) {
                Try {
                    $NextHostDecimal = ([convert]::ToInt32($HostID,2) + $Count)
                    $NextHost        =  [convert]::ToString($NextHostDecimal,2)
                    $NextIP          = $NetworkID + ("0" * ($HostID.Length - $NextHost.Length)) + $NextHost
                    Write-Verbose      "$TimeStamp : LOG   : Collected next ip (binary)  : $NextIP"
                    $ReturnMessage  += "$TimeStamp : LOG   : Collected next ip (binary)  : $NextIP"
                } Catch {
                    Write-Verbose      "$TimeStamp : ERROR : Cannot collect next ip."
                    Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $ReturnMessage  += "$TimeStamp : ERROR : Cannot collect next ip."
                    $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $Boolean_Success = $false
                }
            }

            ##Convert from Networkengineer-readable to Human-readable
            [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm                        
            If ($Boolean_Success -eq $true) {
                Try {
                    While ($Count_Octet -lt 4) {
                        [Array] $Octet = @()
                        $Octet += $([convert]::ToInt32($($NextIP.Substring(($Count_Octet*8),8)),2)).toString()
                        $Count_Octet++
                    }
                    $IPAdresses     += $($Octet -Join '.')    
                    Write-Verbose      "$TimeStamp : LOG   : Added $($Octet -Join '.')"
                    $ReturnMessage  += "$TimeStamp : LOG   : Added $($Octet -Join '.')"
                } Catch {
                    Write-Verbose      "$TimeStamp : ERROR : Cannot convert to humanreadable ip."
                    Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $ReturnMessage  += "$TimeStamp : ERROR : Cannot convert to humanreadable ip."
                    $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $Boolean_Success = $false
                }
            }
        }
    }

    ## Create return-object
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose    "$Timestamp : LOG   : Returning IPAddresses."
        Return $IPAdresses
    } Else {
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGSPFRecord
#Function for collecting an SPF record
Function Get-PRTGSPFRecord {
    [cmdletbinding()] Param(
        [Parameter(Mandatory=$true, Position=1 )] [String] $URL,
        [Parameter(Mandatory=$true, Position=2 )] [Array]  $NameServers
    )

    ##Variables
    [Boolean]  $Boolean_Success = $true
    [Array]    $ReturnMessage   = @()
    [String]   $Timestamp       = Get-Date -format yyyy.MM.dd.hh:mm 

    [PSObject] $SPFRecord    = $null
    [PSObject] $ReturnObj    = $null
    [String]   $SPFString    = $null
    [Int]      $All          = 0
    [String]   $Version      = 'N/A'
    [Array]    $ARecord      = @()
    [Array]    $PTRRecord    = @()
    [Array]    $ExistsRecord = @()
    [Array]    $MXRecord     = @()
    [Array]    $Include      = @()
    [Array]    $Ipv4         = @()
    [Array]    $IPv4Block    = @()
    [Array]    $Ipv6         = @()
    [Array]    $IPv6Block    = @()
    [Boolean]  $DNS_Record   = $false
    [Boolean]  $DNS_Multiple = $false
    [Boolean]  $AfterAll     = $true
    [Boolean]  $StartVSPF1   = $false
    [Int]      $RecordCount  = 0
    [Int]      $RecordLength = 0
    [Int]      $StringLength = 0
    [Int]      $LookupFail   = 0
    [Int]      $TTL          = 0
    [String]   $Name         = $null

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGSPFRecord"
    Write-Verbose     "$TimeStamp : PARAM : Url: $Url"
    Write-Verbose     "$TimeStamp : PARAM : NameServers: $($NameServers -join ',')"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGSPFRecord"
    $ReturnMessage += "$TimeStamp : PARAM : Url: $Url"
    $ReturnMessage += "$TimeStamp : PARAM : NameServers: $($NameServers -join ',')"

    ##Collecting SPF Record
    [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm 
    If ($Boolean_Success -eq $true) {
        Try {
            $SPFRecord = Resolve-DnsName -Name $URL -Type TXT -Server $NameServers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Where-Object -Filterscript {$_.Strings -like "*spf*"}
            Write-Verbose     "$TimeStamp : LOG   : Collected SPF Record"
            $ReturnMessage += "$TimeStamp : LOG   : Collected SPF Record"
            If ($SPFRecord.Count -eq 0) {
                Write-verbose      "$TimeStamp : ERROR : No SPF Record found in DNS"
                $ReturnMessage  += "$TimeStamp : ERROR : No SPF Record found in DNS"
                $DNS_Record      = $false
                $DNS_Multiple    = $false
                $Boolean_Success = $false
            } ElseIf ($SPFRecord.Count -gt 1) {
                Write-Verbose      "$TimeStamp : ERROR : Multiple SPF records found. Using record 1."
                $ReturnMessage  += "$TimeStamp : ERROR : Multiple SPF records found. Using record 1."
                $SPFString       = 'v=spf1 ' + $( ( ($SPFRecord.Strings -join '') -split 'v=spf1')[0])
                Write-Verbose      "$TimeStamp : USING : $SPFString"
                $ReturnMessage  += "$TimeStamp : USING : $SPFString"
                $TTL             = $SPFRecord.TTL[0]
                $Name            = $SPFRecord.Name[0]
                $DNS_Record      = $true
                $DNS_Multiple    = $true
            } Else {
                $SPFString       = $($SPFRecord.Strings -join '')
                Write-Verbose      "$TimeStamp : RECORD: $SPFString"
                $ReturnMessage  += "$TimeStamp : RECORD: $SPFString"
                $TTL             = $SPFRecord.TTL
                $Name            = $SPFRecord.Name
                $DNS_Record      = $true
                $DNS_Multiple    = $false
            }
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not search for SPF records."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage  += "$TimeStamp : ERROR : Could not search for SPF records."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Boolean_Success = $false
        }
    }
    
    ##Trim string to entries
    [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm 
    If ($Boolean_Success -eq $true) {
        Try {
            $Version      = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "V=*"       } | Foreach-Object {$_.replace('v=','')}
            $Include      = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "include:*" } | Foreach-Object {$_.replace('include:','')}
            $ARecord      = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "a:*"       } | Foreach-Object {$_.replace('a:','')}
            $PTRRecord    = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "ptr:*"     } | Foreach-Object {$_.replace('ptr:','')}
            $ExistsRecord = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "exits:*"   } | Foreach-Object {$_.replace('exists:','')}
            $MXRecord     = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "mx:*"      } | Foreach-Object {$_.replace('mx:','')}
            $IPv4Block    = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "ip4:*/*"   } | Foreach-Object {$_.replace('ip4:','')}
            $IPv6Block    = $SPFString.Split(' ') | Where-Object -FilterScript { $_ -like "ip6:*/*"   } | Foreach-Object {$_.replace('ip6:','')}
            $Ipv4         = $SPFString.Split(' ') | Where-Object -FilterScript { ($_ -like "ip4:*") -and ($_ -notlike "ip4:*/*") } | Foreach-Object {$_.replace('ip4:','')}
            $IPv6         = $SPFString.Split(' ') | Where-Object -FilterScript { ($_ -like "ip6:*") -and ($_ -notlike "ip6:*/*") } | Foreach-Object {$_.replace('ip6:','')}

            ##Check if no more than 10 DNSrecords are given in include:, a:, ptr:, Exists:
            $RecordCount  = $($Include.count) + $($ARecord.count) + $($PTRRecord.count) + $($ExistsRecord.count)
            ##Check record length
            $RecordLength = $SPFString.Length
            Foreach ($String in $SPFRecord.Strings) {
                If ($String.Length -gt $StringLength) {$StringLength = $String.Length}
            }
            ##Check what kind of all-statement and if entries are given after
            If ($SPFString -like "*-all") { 
                $All = 0 ##Reject if not matching  
                If ( ( ($SPFString -Split '-all')[1] -eq "") -or ( $null -eq ($SPFString -Split '~all')[1]) ) {
                    $AfterAll = $false
                }
            } ElseIf ($SPFString -like "*~all") { 
                $All = 1 ##Mark as suspicious
                If ( ( ($SPFString -Split '~all')[1] -eq "") -or ( $null -eq ($SPFString -Split '-all')[1]) ) {
                    $AfterAll = $false
                }
            } ElseIf ($SPFString -like "*?all") { 
                $All = 2  ##Allow if not matching 
                If ( ( ($SPFString -Split '?all')[1] -eq "") -or ( $null -eq ($SPFString -Split '-all')[1]) ) {
                    $AfterAll = $false
                }
            } Else { 
                $All = 10; $AfterAll = $false ##Missing
            }
            ##Check If statement starts with 'v=spf1' statement
            If ( ( ($SPFString -Split 'v=spf1')[0] -eq "") -or ( $null -eq ($SPFString -Split 'v=spf1')[0]) ) {
                $StartVSPF1 = $true
            }
            ##Check if all nslookups are successfull on the include:, PRT:, a: & exists records. Count failures
            Foreach ($Record in $Include) {
                [PSObject] $LookupRecord = $null
                $LookupRecord = Resolve-DnsName -Name $Record -Server $NameServers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                If ( ($LookupRecord -eq "") -or ($Null -eq $LookupRecord) ) {
                    Write-Verbose     "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (Include)"
                    $ReturnMessage += "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (Include)"
                    $LookupFail++
                }
            }
            Foreach ($Record in $ARecord) {
                [PSObject] $LookupRecord = $null
                $LookupRecord = Resolve-DnsName -Name $Record -Server $NameServers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                If ( ($LookupRecord -eq "") -or ($Null -eq $LookupRecord) ) {
                    Write-Verbose     "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (A-record)"
                    $ReturnMessage += "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (A-record)"
                    $LookupFail++
                }
            }
            Foreach ($Record in $PTRRecord) {
                [PSObject] $LookupRecord = $null
                $LookupRecord = Resolve-DnsName -Name $Record -Server $NameServers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                If ( ($LookupRecord -eq "") -or ($Null -eq $LookupRecord) ) {
                    Write-Verbose     "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (PTR-Record)"
                    $ReturnMessage += "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (PTR-Record)"
                    $LookupFail++
                }
            }
            Foreach ($Record in $ExistsRecord) {
                [PSObject] $LookupRecord = $null
                $LookupRecord = Resolve-DnsName -Name $Record -Server $NameServers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                If ( ($LookupRecord -eq "") -or ($Null -eq $LookupRecord) ) {
                    Write-Verbose     "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (Exists-record)"
                    $ReturnMessage += "$TimeStamp : LOG   : Record $Record cannot be found in DNS-Servers (Exists-record)"
                    $LookupFail++
                }
            }
            
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not split records into valid parts."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage  += "$TimeStamp : ERROR : Could not split records into valid parts."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Boolean_Success = $false
        }
    }

    ##Creating returnobject
    [String] $Timestamp = Get-Date -format yyyy.MM.dd.hh:mm 
    If ($Boolean_Success -eq $true) {
        Write-Verbose "$TimeStamp : RECORD : DNS Record published? : $DNS_Record"
        Write-Verbose "$TimeStamp : RECORD : Multiple DNS Records? : $DNS_Multiple"
        Write-Verbose "$TimeStamp : RECORD : Records after ~All?   : $AfterAll"
        Write-Verbose "$TimeStamp : RECORD : Starts with V=SPF1?   : $StartVSPF1"
        Write-Verbose "$TimeStamp : RECORD : Version       : $Version"
        Write-Verbose "$TimeStamp : RECORD : Include       : $($Include -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : A-Record      : $($ARecord -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : MXRecord      : $($MXRecord -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : ExistsRecord  : $($ExistsRecord -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : PRTRecord     : $($PTRRecord -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : Record count  : $RecordCount"
        Write-Verbose "$TimeStamp : RECORD : Record length : $RecordLength"
        Write-Verbose "$TimeStamp : RECORD : String length : $StringLength"
        Write-Verbose "$TimeStamp : RECORD : Lookup fails  : $LookupFail"
        Write-Verbose "$TimeStamp : RECORD : All         : $All"
        Write-Verbose "$TimeStamp : RECORD : IPv4        : $($IPv4 -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : IPv4 blocks : $($IPv4Block -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : IPv6        : $($IPv6 -join ' *** ')"
        Write-Verbose "$TimeStamp : RECORD : IPv6 blocks : $($IPv6Block -join ' *** ')"
                
        $ReturnObj = New-Object -TypeName PSObject -Property @{
            DNSRecord    = [Boolean] $DNS_Record
            MultipleDNS  = [Boolean] $DNS_Multiple
            AfterAll     = [Boolean] $AfterAll
            StartwVSPF1  = [Boolean] $StartVSPF1
            Record       = [String]  $SPFString
            TTL          = [Int]     $TTL
            Name         = [String]  $Name
            Version      = [String]  $Version
            All          = [Int]     $All
            RecordCount  = [Int]     $RecordCount
            RecordLength = [Int]     $RecordLength
            StringLength = [Int]     $StringLength
            Include      = [Array]   $Include
            'A-record'   = [Array]   $ARecord
            MXrecord     = [Array]   $MXRecord
            Exitstrecord = [Array]   $ExistsRecord
            PTRrecord    = [Array]   $PTRRecord
            LookupFails  = [Int]     $LookupFail
            IPv4         = [Array]   $IPv4
            IPv4block    = [Array]   $IPv4Block
            IPv6         = [Array]   $IPv6
            IPv6block    = [Array]   $IPv6Block
        }
        Write-Verbose     "$TimeStamp : LOG   : Created returnobject, returning.."
        $ReturnMessage += "$TimeStamp : LOG   : Created returnobject, returning.."
        Return $ReturnObj
    } Else {
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGGraphApiToken
#Function for collecting a Graph Api token with a shared secret
Function Get-PRTGGraphApiToken {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true, Position=1 )] [String] $Secret,
        [Parameter(Mandatory=$true, Position=2 )] [String] $ClientID,
        [Parameter(Mandatory=$true, Position=3 )] [String] $TenantID,
        [Parameter(Mandatory=$false)] [String] $Scope_URL = "https://graph.microsoft.com/.default"
    )
    ##Variables
    [Boolean]   $Boolean_Success = $true
    [Array]     $ReturnMessage   = @()
    [PSObject]  $Request         = $null
    [String]    $Uri             = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [HashTable] $Body            = @{}

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGGraphApiToken"
    Write-Verbose     "$TimeStamp : PARAM : Secret   : $($Secret.Substring(0,3) + '..')"
    Write-Verbose     "$TimeStamp : PARAM : ClientID : $ClientID"
    Write-Verbose     "$TimeStamp : PARAM : TenantID : $TenantID"
    Write-Verbose     "$TimeStamp : PARAM : Scope:     $Scope_URL"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGGraphApiToken"
    $ReturnMessage += "$TimeStamp : PARAM : Secret   : $($Secret.Substring(0,3) + '..')"
    $ReturnMessage += "$TimeStamp : PARAM : ClientID : $ClientID"
    $ReturnMessage += "$TimeStamp : PARAM : TenantID : $TenantID"
    $ReturnMessage += "$TimeStamp : PARAM : Scope:     $Scope_URL"

    ##Construct body & Invoke-RestMethod
    [String] $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $Body = @{
                'client_id'     = $ClientID
                'scope'         = "https://graph.microsoft.com/.default"
                'client_secret' = $SharedSecret
                'grant_type'    = 'client_credentials'
                'content-type'  = 'application/json'
            }
            Write-Verbose      "$TimeStamp : LOG   : Constructed hashtable to use in Rest-Call."
            $ReturnMessage  += "$TimeStamp : LOG   : Constructed hashtable to use in Rest-Call."
            $Request         = Invoke-RestMethod -Method POST -Uri $uri -Body $Body -UseBasicParsing
            Write-Verbose      "$TimeStamp : LOG   : performed REST-call (POST), collected AccessToken"
            Write-Verbose      "$TimeStamp : LOG   : Uri         : $Uri"
            Write-Verbose      "$TimeStamp : LOG   : Token Type  : $($Request.token_type)"
            Write-Verbose      "$TimeStamp : LOG   : Expires in  : $($Request.expires_in)"
            Write-Verbose      "$TimeStamp : LOG   : Extended    : $($Request.ext_expires_in)"
            Write-Verbose      "$TimeStamp : LOG   : Starts with : $($Request.access_token.Substring(0,10))"
            $ReturnMessage  += "$TimeStamp : LOG   : performed REST-call (POST), collected AccessToken"
            $ReturnMessage  += "$TimeStamp : LOG   : Uri         : $Uri"
            $ReturnMessage  += "$TimeStamp : LOG   : Token Type  : $($Request.token_type)"
            $ReturnMessage  += "$TimeStamp : LOG   : Expires in  : $($Request.expires_in)"
            $ReturnMessage  += "$TimeStamp : LOG   : Extended    : $($Request.ext_expires_in)"
            $ReturnMessage  += "$TimeStamp : LOG   : Starts with : $($Request.access_token.Substring(0,10))"            
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not call REST-api."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not call REST-api."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
        $SharedSecret       = $null
        $Body.client_secret = $null
    }

    ##Returning...
    If ($Boolean_Success -eq $true) {
        Write-Verbose     "$Timestamp : LOG   : Returning.."
        $ReturnMessage += "$Timestamp : LOG   : Returning.."
        Return $RegistryValue
    } Else {
        Write-Verbose     "$Timestamp : ERROR : Function not successfull"
        $ReturnMessage += "$Timestamp : ERROR : Function not successfull"
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Test-PRTGGraphApiToken
#Function for testing if a Graph api token is still valid. Not in use in the PRTG-sensors; for testing purposes
Function Test-PRTGGraphApiToken {
    [cmdletbinding()] Param (
            [Parameter(Mandatory=$true, Position=1)] [String] $Token,
            [Parameter(Mandatory=$false)] [String] $Uri = "https://graph.microsoft.com/v1.0/users"
    )
    ##Variables
    [Boolean]   $Boolean_Success = $true
    [String]    $Method          = "GET"
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [Hashtable] $Header          = @{}
    [PSObject]  $Results         = $null

    Write-Verbose     "$TimeStamp : FUNCTION : Test-PRTGGraphApiToken"
    Write-Verbose     "$TimeStamp : PARAM : Token : $($Token.Substring(0,3) + '..')"
    Write-Verbose     "$TimeStamp : PARAM : Uri   : $Uri"
    
    ##Test whether the token is valid by querying the used account - Building header
    [String] $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {        
            $Header = @{
                'Content-Type'  = 'application\json'
                'Authorization' = "Bearer $Token"
            }
            Write-Verbose      "$TimeStamp : LOG   : Constructed hashtable to use in Rest-Call."
            $Results         = Invoke-RestMethod -Headers $Header -Uri $Uri -UseBasicParsing -Method $Method
            Write-Verbose      "$TimeStamp : LOG   : Used header to call RestApi. ResultCount $(($Results.Value).count)"
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not call REST-api."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }
    
    ##Returning...
    Return $Boolean_Success
}

##Function Invoke-PRTGGraphApiCall
#Function for calling Graph-Api with a query
Function Invoke-PRTGGraphApiCall {
    [cmdletbinding()] Param (
            [Parameter(Mandatory=$true, Position=1 )] [String] $Token,
            [Parameter(Mandatory=$true, Position=2 )] [String] $Query,
            [Parameter(Mandatory=$false)] [ValidateSet('GET','POST','PATCH','PUT','DELETE')][String] $Method = 'GET',
            [Parameter(Mandatory=$false)] [ValidateSet('v1.0','BETA')][String] $Version = 'v1.0',
            [Parameter(Mandatory=$false)] [String] $Uri = 'https://graph.microsoft.com/'
    )
    ##Variables
    [Boolean]   $Boolean_Success = $true
    [Array]     $ReturnMessage   = @()
    [String]    $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
    [HashTable] $Header          = @{'Authorization' = "Bearer $Token"}
    [String]    $Uri_Const       = $null
    [PSObject]  $Results         = $null

    Write-Verbose     "$TimeStamp : FUNCTION : Invoke-PRTGGraphApiCall"
    Write-Verbose     "$TimeStamp : PARAM : Token    : $($Token.Substring(0,3) + '..')"
    Write-Verbose     "$TimeStamp : PARAM : Query    : $Query"
    Write-Verbose     "$TimeStamp : PARAM : Method   : $Method"
    Write-Verbose     "$TimeStamp : PARAM : Version  : $Version"
    Write-Verbose     "$TimeStamp : PARAM : Uri      : $Uri"
    $ReturnMessage += "$TimeStamp : FUNCTION : Invoke-PRTGGraphApiCall"
    $ReturnMessage += "$TimeStamp : PARAM : Token    : $($Token.Substring(0,3) + '..')"
    $ReturnMessage += "$TimeStamp : PARAM : Query    : $Query"
    $ReturnMessage += "$TimeStamp : PARAM : Method   : $Method"
    $ReturnMessage += "$TimeStamp : PARAM : Version  : $Version"
    $ReturnMessage += "$TimeStamp : PARAM : Uri      : $Uri"

    ##Building Header
    [String]    $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            Write-Verbose      "$TimeStamp : LOG   : Adding '/' as last char to components for URL."
            $ReturnMessage  += "$TimeStamp : LOG   : Adding '/' as last char to components for URL."
            If ($Uri[$Uri.Length -1]         -ne '/' ) { $Uri = $Uri + '/'}
            If ($Query[$Query.Length -1]     -ne '/' ) { $Query = $Query + '/'}
            If ($Version[$Version.Length -1] -ne '/' ) { $uVersion = $Version + '/'}
            $Uri_Const       = $Uri + $uVersion + $Query
            Write-Verbose      "$TimeStamp : LOG   : Constructed URI $URI_Const."
            $ReturnMessage  += "$TimeStamp : LOG   : Constructed URI $URI_Const."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not construct URI."
            Write-Verbose      "$Timestamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not construct URI."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false            
        }
    }

    ##Calling api
    [String]    $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {    
            $Results         = Invoke-RestMethod -Headers $Header -Uri $Uri_Const -Method $Method
            Write-Verbose      "$TimeStamp : LOG   : Called $URI_Const to RestApi ($Method)"
            $ReturnMessage  += "$TimeStamp : LOG   : Called $URI_Const to RestApi ($Method)"
            Write-Verbose      "$TimeStamp : LOG   : Resultsize $($Results.value.count)."
            $ReturnMessage  += "$TimeStamp : LOG   : Resultsize $($Results.value.count)."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not call restapi."
            Write-Verbose      "$Timestamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not call restapi."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false   
        }
    }
    
    ##Returning...
    If ($Boolean_Success -eq $true) {
        Write-Verbose     "$Timestamp : LOG   : Returning.."
        $ReturnMessage += "$Timestamp : LOG   : Returning.."
        Return $Results
    } Else {
        Write-Verbose     "$Timestamp : ERROR : Function not successfull"
        $ReturnMessage += "$Timestamp : ERROR : Function not successfull"
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGSccmPatchTuesday 
#Function for collecting patch tuesday
Function Get-PRTGSccmPatchTuesday {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$false)] [Switch] $Next
    )
    ##Variables
    [String]   $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    [Boolean]  $Boolean_Next = $false
    [Array]    $ResultArray = @()
    If ($Next) { $Boolean_Next = $true }
    [DateTime] $Current    = Get-Date
    [Int]      $Count      = 0
    [Int]      $Count_Max  = 2    

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGSccmPatchTuesday"
    Write-Verbose     "$TimeStamp : PARAM : Next  : $Boolean_Next"

    ##Get first day of this month
    $1stday_Array = @(
        Get-Date -Day 1 -Year $((Get-Date).Year) -Hour 3 -Minute 0 -Second 0 -Month $( ( (Get-Date).AddMonths(-1)).Month);
        Get-Date -Day 1 -Year $((Get-Date).Year) -Hour 3 -Minute 0 -Second 0 -Month $( (Get-Date).Month);
        Get-Date -Day 1 -Year $((Get-Date).Year) -Hour 3 -Minute 0 -Second 0 -Month $( ( (Get-Date).AddMonths(1)).Month);
    )
    Write-Verbose     "$TimeStamp : LOG   : Collected first day of prev. month, current and next"
   
    ##Collecting the second tuesday
    Write-Verbose     "$TimeStamp : LOG   : Looping to count to second day of that month."
    Foreach ($Day in $1stday_Array) {
        [Int] $Count_Max = 2
        [Int] $Count = 0
        While ($Count -lt $Count_Max) {
            If ($Day.DayOfWeek -eq 'TuesDay') {
                $Count++
            }
            If ($Count -eq 2) {
                $ResultArray += $Day
                Write-Verbose     "$TimeStamp : LOG   : Detected 2nd tuesday on $Day."
            }
            $Day = $Day.AddDays(1)
        }
    }

    ##Returning based on either next or previous month
    If ( ($Boolean_Prev -eq $true) -and ($ResultArray[1] -le $Current) ) {
        Write-Verbose "$TimeStamp : LOG   : Returning previous patchtuesday"
        Return $ResultArray[1]
    } ElseIf ( ($Boolean_Prev -eq $true) -and ($ResultArray[1] -gt $Current) ) {
        Write-Verbose "$TimeStamp : LOG   : Returning previous patchtuesday"
        Return $ResultArray[0]
    } ElseIf ( ($Boolean_Prev -eq $false) -and ($ResultArray[1] -gt $Current) ) {
        Write-Verbose "$TimeStamp : LOG   : Returning next patchtuesday"
        Return $ResultArray[1]
    } Else {
        Write-Verbose "$TimeStamp : LOG   : Returning previous patchtuesday"
        Return $ResultArray[2]
    }
}

##Function Get-PRTGClientUserProfileSize (26-05-2020)
#Function for collecting the profilesize of each user on a remote computer
Function Get-PRTGClientUserProfileSize {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$false)] [String]       $Query,
        [Parameter(Mandatory=$false)] [String]       $Unit  = 'Gb',
        [Parameter(Mandatory=$false)] [PSCredential] $Credential,
        [Parameter(Mandatory=$true )] [String]       $Computer   
    )
    [Array]     $ReturnMessage = @()
    [String]    $Timestamp     = Get-Date -format yyyy.MM.dd_hh:mm
    [Array]     $ResultArray   = @()
    [PSObject]  $ReturnObject  = $null
    [Boolean]   $Boolean_Success  = $true
    [Boolean]   $Boolean_Cred     = $false
    [Boolean]   $Boolean_Local    = $false
    If ( ($($env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN) -eq $Computer) -or ($env:COMPUTERNAME -eq $Computer) ) {
        $Boolean_Local = $true
    }
    If ($Credential) { $Boolean_Cred = $true }

    ##Scriptblock running on remote computer
    [Scriptblock] $Scriptblock = {
        [Array]     $sessionMessage   = @()
        [Boolean]   $Boolean_Session  = $true
        [Array]     $Users            = @()
        [Int]       $Count            = 0
        [PSObject]  $SessionObject    = $null
        [Double]    $ProfileSize      = 0
        [PSObject]  $ReturnObject     = $null
        [Array]     $SessionArray     = @()
        [String]    $Timestamp        = Get-Date -format yyyy.MM.dd_hh:mm
       
        ##Collecting userlist from WMI
        Try {
            $Users = Get-WmiObject -Query $Using:Query 
            Write-Verbose      "$TimeStamp : LOG   : Collected users from WMI ($($Users.Count) found)"
            $sessionMessage += "$TimeStamp : LOG   : Collected users from WMI ($($Users.Count) found)"
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not collect users from WMI."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $sessionMessage += "$TimeStamp : ERROR : Could not collect users from WMI."
            $sessionMessage += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Session = $false
        }
        
        ##Looping through userlist to collect sizes
        If ($Boolean_Session -eq $true) {
            While ($Count -lt $($Users.Count) ) {
                [PSObject]  $sessionObject = $null
                [Double]    $ProfileSize  = 0
                [String]    $Timestamp    = Get-Date -format yyyy.MM.dd_hh:mm    
               
                Try {
                    $ProfileSize      = ( (Get-ChildItem $($Users[$count].LocalPath) -recurse -force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Measure-Object -property length -sum).Sum) / $(1$Using:Unit)
                    Write-Verbose       "$TimeStamp : LOG   : Collected profilesize for user $($Users[$count].LocalPath.Replace("C:\Users\",'')) : $ProfileSize $Using:Unit"
                    $sessionMessage  += "$TimeStamp : LOG   : Collected profilesize for user $($Users[$count].LocalPath.Replace("C:\Users\",'')) : $ProfileSize $Using:Unit `n"
                    $sessionObject = New-Object -TypeName PSObject -Property @{
                        "ProfileSize"  = [Double] $ProfileSize
                        "Username"     = [String] $Users[$count].LocalPath.Replace("C:\Users\",'')
                        "ProfilePath"  = [String] $Users[$count].LocalPath
                    }
                    Write-Verbose      "$TimeStamp : LOG   : Created returnObject."
                    $sessionMessage += "$TimeStamp : LOG   : Created returnObject. `n"
                    $SessionArray   += $SessionObject
                    Write-Verbose      "$TimeStamp : LOG   : Added to resultArray"
                    $sessionMessage += "$TimeStamp : LOG   : Added to resultArray. `n"
                    $Count++
                } Catch {
                    Write-Verbose      "$TimeStamp : ERROR : Could not collect profileSize."
                    Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $sessionMessage += "$TimeStamp : ERROR : Could not collect profileSize."
                    $SessionMessage += "$TimeStamp : ERROR : $($_.Exception.Message)"
                    $Boolean_Session = $false
                    $Count = $($Users.Count)
                }
            }
        }
        
        ##ReturnObject
        $ReturnObject = New-Object -TypeName PSObject -Property @{
            "ResultArray"   = [Array]   $SessionArray
            "ResultMessage" = [Array]   $sessionMessage
            "Result"        = [Boolean] $Boolean_Session
        }
        Return $ReturnObject
    }

    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGClientUserProfileSize"
    Write-Verbose     "$TimeStamp : PARAM : Query     : $($Query.Substring(0,8)).."
    Write-Verbose     "$TimeStamp : PARAM : Unit      : $Unit"
    Write-Verbose     "$TimeStamp : PARAM : Computer  : $Computer"
    Write-Verbose     "$TimeStamp : PARAM : UseCreds  : $Boolean_Cred"
    Write-Verbose     "$TimeStamp : PARAM : Local PC  : $Boolean_local"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGClientUserProfileSize"
    $ReturnMessage += "$TimeStamp : PARAM : Query     : $($Query.Substring(0,8)).."
    $ReturnMessage += "$TimeStamp : PARAM : Unit      : $Unit"
    $ReturnMessage += "$TimeStamp : PARAM : Computer  : $Computer"
    $ReturnMessage += "$TimeStamp : PARAM : UseCreds  : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : PARAM : Local PC  : $Boolean_local"

    ##Create Remote session
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Local -eq $False) {
        Try {
            $SessionSplat = @{
                "ComputerName" = $Computer
            }
            If ($Boolean_Cred -eq $true) {
                $SessionSplat.add("Credential", $Credential)
                Write-Verbose     "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
                $ReturnMessage += "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
            }
            $Session         = New-PSSession @SessionSplat
            Write-Verbose      "$TimeStamp : LOG   : Created PSSession to computer $Computer."
            $ReturnMessage  += "$TimeStamp : LOG   : Created PSSession to computer $Computer."
            $RemoteSession   = @{
                "Session" = $Session
                "Scriptblock" = $Scriptblock
            }
            Write-Verbose      "$TimeStamp : LOG   : Created Splat to pass to Invoke-Command."
            $ReturnMessage  += "$TimeStamp : LOG   : Created Splat to pass to Invoke-Command."            
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not create PSSession to computer $computer."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not create PSSession to computer $computer."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    } Else {
        Write-Verbose      "$TimeStamp : LOG   : Running against local computer."
        Write-Verbose      "$TimeStamp : LOG   : Created Splat to pass to Invoke-Command."
        $ReturnMessage  += "$TimeStamp : LOG   : Running against local computer."
        $ReturnMessage  += "$TimeStamp : LOG   : Created Splat to pass to Invoke-Command."
        $RemoteSession   = @{ "Scriptblock" = $Scriptblock }
    }

    ##Calling remote Session
    If ($Boolean_Success -eq $true) {
        Try{
            $ResultObject     = Invoke-Command @RemoteSession
            Write-Verbose      "$TimeStamp : LOG   : Collected Profilesize from computer $Computer."
            $ReturnMessage  += "$TimeStamp : LOG   : Collected Profilesize from computer $Computer."
            If ($($ResultObject.Result) -eq $false) {
                Write-Verbose      "$TimeStamp : ERROR : Remote session to Computer $Computer NOT successfull"
                Write-Verbose      $("`n`n" + ($ResultObject.Message -join "`n"))
                $ReturnMessage  += "$TimeStamp : ERROR : Remote session to Computer $Computer NOT successfull"
                $ReturnMessage  += $ResultObject.Message
                $Boolean_Success = $false
            }
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Could not collect ProfileSize from computer $Computer."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)"
            $ReturnMessage  += "$TimeStamp : ERROR : Could not collect ProfileSize from computer $Computer."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)"
            $Boolean_Success = $false
        }
    }

    ##removing PsSession
    If ($Boolean_Local -eq $False) {
        $Session | Remove-PSSession -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Write-Verbose     "$TimeStamp : LOG   : Removed PSSession"
        $ReturnMessage += "$TimeStamp : LOG   : Removed PSSession"
    }
       
    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$TimeStamp : LOG   : Returning..."
        $ReturnMessage  += "$TimeStamp : LOG   : Returning..."
        Return $ResultArray
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}

##Function Get-PRTGClientEventlog
#Function for collecting remote eventlogs from a client in PRTG
Function Get-PRTGClientEventlog {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true)]  [PSObject] $Computer,
        [Parameter(Mandatory=$true)]  [String]   $Eventlog,
        [Parameter(Mandatory=$false)] [String]   $Source,
        [Parameter(Mandatory=$false)] [String]   $EventID,
        [Parameter(Mandatory=$false)] [String]   $TimeFrame,
        [Parameter(Mandatory=$false)] [String]   $Query,
        [Parameter(Mandatory=$false)] [PSCredential] $Credential
    )
    ##Variables
    [String]    $Timestamp         = Get-Date -format yyyy.MM.dd_hh:mm
    [Boolean]   $Boolean_Success   = $true
    [Boolean]   $Boolean_Cred      = $false
    [Boolean]   $Boolean_Local     = $false
    [Boolean]   $Boolean_Query     = $false
    [Boolean]   $Boolean_LE        = $false
    [Boolean]   $Boolean_TimeStamp = $false
    
    [PSObject]  $ReturnObj       = $null
    [Array]     $Events          = @()
    [Array]     $ReturnMessage   = @()
    
    If ($Credential) {$Boolean_Cred      = $true}
    If ($Query)      {$Boolean_Query     = $true}
    If ($TimeStamp)  {$Boolean_TimeStamp = $true}
    If ($LastEvent)  {$Boolean_LE        = $true}
    If (($Computer -eq $env:COMPUTERNAME) -or ($Computer = $($env:ComputerName + '.' + $env:USERDNSDOMAIN))) {
        $Boolean_Local = $true
    }
    [String] $X_path = @"
    <QueryList>
        <Query Id   = `"0`" Path = `"$Eventlog`">
            <Select Path = `"$Eventlog`"> 
                !QUERY!
            </Select>
        </Query>
    </QueryList>
"@
    [String] $X_Path_1 = "* [System[Provider    [@Name       = `'$Source`'   ]]]"
    [String] $X_Path_2 = "[System[TimeCreated [@SystemTime > `'$Timeframe`']]]"
    [String] $X_Path_3 = "[System[EventID                  = `'$EventID`'  ]]"

    
    Write-Verbose     "$TimeStamp : FUNCTION : Get-PRTGClientEventlog"
    Write-Verbose     "$TimeStamp : PARAM : Computer  : $Computer"
    Write-Verbose     "$TimeStamp : PARAM : Eventlog  : $Eventlog"
    Write-Verbose     "$TimeStamp : PARAM : LocalPC?  : $Boolean_Local"
    Write-Verbose     "$TimeStamp : PARAM : UseCred   : $Boolean_Cred"
    Write-Verbose     "$TimeStamp : PARAM : UseQuery? : $Boolean_Query"
    $ReturnMessage += "$TimeStamp : FUNCTION : Get-PRTGClientEventlog"
    $ReturnMessage += "$TimeStamp : PARAM : Computer  : $Computer"
    $ReturnMessage += "$TimeStamp : PARAM : Eventlog  : $Eventlog"
    $ReturnMessage += "$TimeStamp : PARAM : LocalPC?  : $Boolean_Local"
    $ReturnMessage += "$TimeStamp : PARAM : UseCred   : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : PARAM : UseQuery? : $Boolean_Query"
    If ($Boolean_Query -eq $true) {
        Write-Verbose     "$TimeStamp : PARAM : Query : $(If ($Query.Length -gt 24) {$Query.SubString(0,24) + '...'} else {$Query})"
        $ReturnMessage += "$TimeStamp : PARAM : Query : $(If ($Query.Length -gt 24) {$Query.SubString(0,24) + '...'} else {$Query})"
    } Else {
        Write-Verbose     "$TimeStamp : PARAM : EventID  : $EventID"
        Write-Verbose     "$TimeStamp : PARAM : Source   : $Source"
        $ReturnMessage += "$TimeStamp : PARAM : EventID  : $EventID"
        $ReturnMessage += "$TimeStamp : PARAM : Source   : $Source"
        If ($Boolean_TimeStamp -eq $true) {
            Write-Verbose     "$TimeStamp : PARAM : TimeFrame: $TimeFrame"
            $ReturnMessage += "$TimeStamp : PARAM : TimeFrame: $TimeFrame"
        }
    }
    If ($Boolean_LE) {
        Write-Verbose     "$TimeStamp : PARAM : Only return last event: $Boolean_LE"
        $ReturnMessage += "$TimeStamp : PARAM : Only return last event: $Boolean_LE"
    }

    If ( !($Query) -and (!($Source) -and !($EventID)) ) {
        Write-Verbose   "$TimeStamp : ERROR : Selected neither Query, or via EventID. Please choose either."
        $LogMesseage += "$TimeStamp : ERROR : Selected neither Query, or via EventID. Please choose either."
        $Boolean_Success = $False
    }ElseIf ( !($Query) -and (!($Source) -or !($EventID)) ) {
        Write-Verbose   "$TimeStamp : ERROR : Please use following: Source AND EventID (and TimeFrame optionally)."
        $LogMesseage += "$TimeStamp : ERROR : Please use following: Source AND EventID (and TimeFrame optionally)."
        $Boolean_Success = $False
    }    

    ##Building Xpath-query
    If ( ($Boolean_Success -eq $true) -and ($Boolean_Query -eq $true) ) {
        $X_path = $X_path -replace '!QUERY!', $Query
        Write-Verbose     "$TimeStamp : LOG   : Constructed splat based on query"
        $ReturnMessage += "$TimeStamp : LOG   : Constructed splat based on query"
    } ElseIf ( ($Boolean_Success -eq $true) -and ($Boolean_Query -eq $false) -and ($Boolean_TimeStamp -eq $true) ) {
        $X_Path = $X_path -replace '!QUERY!', $($X_Path_1 + $X_Path_2 + $X_Path_3)
        Write-Verbose     "$TimeStamp : LOG   : Constructed splat based on EventID, Source and TimeStamp"
        $ReturnMessage += "$TimeStamp : LOG   : Constructed splat based on EventID, Source and TimeStamp"
    } ElseIf ( ($Boolean_Success -eq $true) -and ($Boolean_Query -eq $false) -and ($Boolean_TimeStamp -eq $false) ) {
        $X_Path = $X_path -replace '!QUERY!', $($X_Path_1 + $X_Path_2)
        Write-Verbose     "$TimeStamp : LOG   : Constructed splat based on EventID, Source"
        $ReturnMessage += "$TimeStamp : LOG   : Constructed splat based on EventID, Source"
    }

    ##Creating PSSession if not local
    If (($Boolean_Success -eq $true) -and ($Boolean_Local -eq $False)) {
        Try {
            $SessionSplat = @{
                "Computer" = $Computer
            }
            Write-Verbose     "$TimeStamp : LOG   : Constructed sessionsplat to query remote computer."
            $ReturnMessage += "$TimeStamp : LOG   : Constructed sessionsplat to query remote computer."
            If ($Boolean_Cred -eq $true) {
                $SessionSplat.Add("Credential", $Credential)
                Write-Verbose     "$TimeStamp : LOG   : Added credential for user $($Credential.Username)."
                $ReturnMessage += "$TimeStamp : LOG   : Added credential for user $($Credential.Username)."                
            }
            $Session = New-PSSession @SessionSplat
            Write-Verbose     "$TimeStamp : LOG   : Created PSSession."
            $ReturnMessage += "$TimeStamp : LOG   : Created PSSession."                
        } Catch {
            Write-Verbose     "$TimeStamp : ERROR : Cannot create PSSessions to $Computer."
            Write-Verbose     "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage += "$TimeStamp : ERROR : Cannot create PSSessions to $Computer."
            $ReturnMessage += "$TimeStamp : ERROR : $($_.Exception.Message)."            
            $Boolean_Success = $false   
        }
    }

    ##Running invoke-command
    If (($Boolean_Success -eq $true) -and ($Boolean_Local -eq $False)) {
        Try {
            $EventArray = Invoke-Command -Session $Session -ScriptBlock {
                [Array] $SessionEvents = @()
                $SessionEvents = Get-WinEvent -LogName "$Using:Eventlog" -FilterXPath $Using:X_path -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                Return $SessionEvents
            }
            Write-Verbose     "$TimeStamp : LOG   : Collected events from remote computer."
            $ReturnMessage += "$TimeStamp : LOG   : Collected events from remote computer."               
        } Catch {
            Write-Verbose     "$TimeStamp : ERROR : Cannot query remote eventlog."
            Write-Verbose     "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage += "$TimeStamp : ERROR : Cannot query remote eventlog."
            $ReturnMessage += "$TimeStamp : ERROR : $($_.Exception.Message)."            
            $Boolean_Success = $false   
        }
    }

    ##Removing Session
    If ($Boolean_Local -eq $False) {
        $Session | Remove-PSSession
        $Credential = $null
        $SessionSplat.Credential = $null
        Write-Verbose     "$TimeStamp : LOG   : Removed PSSession."
        $ReturnMessage += "$TimeStamp : LOG   : Removed PSSession."                       
    }

    ##Collecting local events
    If ( ($Boolean_Success -eq $true) -and ($Boolean_Local -eq $true) ) {
        Try {
            $EventArray = Get-WinEvent -LogName "$Eventlog" -FilterXPath $X_path
            Write-Verbose     "$TimeStamp : LOG   : Collected events from local computer."
            $ReturnMessage += "$TimeStamp : LOG   : Collected events from local computer."             
        } Catch {
            Write-Verbose     "$TimeStamp : ERROR : Cannot query local eventlog."
            Write-Verbose     "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage += "$TimeStamp : ERROR : Cannot query local eventlog."
            $ReturnMessage += "$TimeStamp : ERROR : $($_.Exception.Message)."            
            $Boolean_Success = $false   
        }
    }
        
    ##Returning..
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {    
        Write-Verbose      "$Timestamp : LOG   : Creating returnObject and returning.."
        $ReturnMessage  += "$timestamp : LOG   : Creating returnObject and returning.."
        $ReturnObj       = New-Object -TypeName PSObject -Property @{
            Result = [Boolean] $Boolean_Success
            Events = [Array]   $EventArray
            Count  = [Int]     $($Events.Count)
        }
        Return $ReturnObj
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }                              
}

##Function New-PRTGPSSession
#Function to check whether a pssession is available; if not building
Function New-PRTGPSSession {
    [cmdletbinding()] Param (
        [Parameter(Mandatory=$true )] [String] $Computer,
        [Parameter(Mandatory=$false)] [PSCredential] $Credential   
    )
    ##Variables
    [Boolean]  $Boolean_Success = $true
    [Boolean]  $Boolean_cred    = $false
    [Boolean]  $Boolean_ReUse   = $false
    [Array]    $ReturnMessage   = @()
    [Array]    $Sessions  = @()
    [String]   $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    [PSObject] $Session   = $null
    If ( $Credential ) { $Boolean_cred = $true }

    Write-Verbose     "$TimeStamp : FUNCTION : New-PRTGPSSession"
    Write-Verbose     "$TimeStamp : PARAM : Computer  : $Computer"
    Write-Verbose     "$TimeStamp : PARAM : UseCreds  : $Boolean_Cred"
    $ReturnMessage += "$TimeStamp : FUNCTION : New-PRTGPSSession"
    $ReturnMessage += "$TimeStamp : PARAM : Computer  : $Computer"
    $ReturnMessage += "$TimeStamp : PARAM : UseCreds  : $Boolean_Cred"

    ## Collect all PSSessions to computer
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Try {
            $SessionSplat = @{
                ComputerName = $Computer
            }
            If ($Boolean_Cred -eq $true) {
                $SessionSplat.add("Credential", $Credential)
                Write-Verbose     "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
                $ReturnMessage += "$TimeStamp : LOG   : Added credentials for user $($Credential.UserName)"
            }
            $Sessions   = Get-PSSession @SessionSplat
            Write-Verbose     "$TimeStamp : LOG   : Collecting active PSSessions to computer $Computer"
            $ReturnMessage += "$TimeStamp : LOG   : Collecting active PSSessions to computer $Computer"
            If ($($Sessions.Count) -gt 0) {
                Write-Verbose     "$TimeStamp : LOG   : Already active sessions ($($Sessions.Count)) available. Re-using.."
                $ReturnMessage += "$TimeStamp : LOG   : Already active sessions ($($Sessions.Count)) available. Re-using.."
                $Boolean_ReUse  = $true
                $Session        = $Sessions[0]
            }
        } Catch {
            Write-Verbose     "$TimeStamp : ERROR : Cannot collect PSSessions to $Computer."
            Write-Verbose     "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage += "$TimeStamp : ERROR : Cannot collect PSSessions to $Computer."
            $ReturnMessage += "$TimeStamp : ERROR : $($_.Exception.Message)."            
            $Boolean_Success = $false            
        }
    }

    ##Create a PSSession
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ( ($Boolean_ReUse -eq $false) -and ($Boolean_Success -eq $true) ) {
        Try {
            $Session         = New-PSSession @SessionSplat
            Write-Verbose      "$TimeStamp : LOG   : Created PSSession to remote computer $Computer."
            $ReturnMessage  += "$TimeStamp : LOG   : Created PSSession to remote computer $Computer."
        } Catch {
            Write-Verbose      "$TimeStamp : ERROR : Cannot create PSSession to $Computer."
            Write-Verbose      "$TimeStamp : ERROR : $($_.Exception.Message)."
            $ReturnMessage  += "$TimeStamp : ERROR : Cannot collect PSSessions to $Computer."
            $ReturnMessage  += "$TimeStamp : ERROR : $($_.Exception.Message)."            
            $Boolean_Success = $false            
        }
    }

    ##Returning
    [String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
    If ($Boolean_Success -eq $true) {
        Write-Verbose      "$TimeStamp : LOG   : Returning..."
        $ReturnMessage  += "$TimeStamp : LOG   : Returning..."
        Return $Session
    } Else {
        $ReturnMessage += "$TimeStamp : ERROR : Function not successfull."
        Write-Verbose     "$TimeStamp : ERROR : Function not successfull."
        Throw $("`n`n" + ($ReturnMessage -join "`n"))
    }
}
Export-ModuleMember -Function * -Alias *
