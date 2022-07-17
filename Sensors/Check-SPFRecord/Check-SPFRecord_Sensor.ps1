<#
.SYNOPSIS
PRTG-Sensor for reading SPF-records, and testing them to MXToolbox' ruleset. 

.DESCRIPTION
This script is ment to be used as PRTG-sensor. It will read the SPF-record of an email-
domain, and check against the same rules as MXToolbox.

DNS Record Published                -- DNS Record should be found
SPF Record Published                -- SPF Record should be found
SPF Record Deprecated               -- No deprecated records found, only TXT-records
SPF Multiple Records                -- Less than two records should be found 
SPF Contains characters after ALL   -- No items should be after 'ALL'.
SPF Syntax Check                    -- The record should be valid
SPF Included Lookups                -- Number of included lookups is OK. 10 max.
SPF Type PTR Check                  -- No type PTR found. PTR-records are deprecated
SPF Void Lookups                    -- Number of void lookups is OK. Max 2 should fail
SPF Exceeds Maximum Character Limit -- String lengths are OK. A single string should be max 255

Known issues / Features to be added: 
- Script cannot yet resolve IPv6 blocks. It will resolve IPv6 blocks as the first address
- Script does not perform RECURSIVE nslookups for the 10 queries max limit
- Script does not show internal addresses in use on ipv4 or ipv6. 99/100 times there is no use for them in SPF
- +Characters in syntaxt will not yet be ignored.

.PARAMETER Filename 
Mandatory parameter giving the location of the XML-formatted channelconfiguration-file.

.PARAMETER URL
Mandatory parameter giving URL of the emaildomain to test.

.PARAMETER Nameservers
Optional parameter for giving an array of NameServers to test against. Default, OpenDNS 
servers are listed.

.EXAMPLE
This script is ment to be run within PRTG. Probe can be configured as follows:
- Add sensor to device (Windows client / server), Sensor type 'EXE/Script'
- Sensor name:      personal preference
- Priority:         personal preference
- EXE/Script:       check-spfrecord_sensor.ps1
- Parameters:       '-URL "plugged.nl" -filename "\\Server.domain.local\share\folder\Check-SPFRecord_ChannelConfiguration.xml"'
- Enviroment:       personal preference
- Security context: personal preference
- Mutex name:       optionally, if deployed to a lot of servers / clients
- Timeout (sec.):   optionally, if slowlink 
- Value Type:       counter
- Channel name:     personal preference
- Unit string:      personal preference / empty (#)
- If value changes: personal preference
- EXE Result:       whilst implementing "Write EXE to disk" (Logging)
- Inheritance:      Default value will set the checking interval to 60 sec. Depending on $env, this might be a bit much. SPFrecords never change, once a day should be enough

Script can be run locally for test-purposes via
.\Read-SPFRecord.ps1 -Filename "\\Server.domain.local\share\folder\Check-SPFRecord_ChannelConfiguration.xml" -URL "plugged.nl"

.NOTES
This script is written by Jaap Plugge, OGD ict-diensten. 
Version 1.0 / 10-12-2019. 
Version 2.0 / 14-11-2021: Moved functions to PRTG Module
Version 2.1 / 10-07-2022: Upload to Github

.LINK
https://mxtoolbox.com/dmarc/spf/spf-record-tags
https://tools.ietf.org/html/rfc7208
https://github.com/jaapplugge/PRTGModule
#>

## Parameters
[cmdletbinding()] Param (
    [Parameter(Mandatory=$true ,Position=1)][String]$URL,
    [Parameter(Mandatory=$true ,Position=2)][String]$FileName,
    [Parameter(Mandatory=$False,Position=3)][Array] $NameServers
)
## Variables
[Boolean]  $Boolean_Exit    = $False
[Boolean]  $Boolean_Warning = $False
[Boolean]  $Boolean_Error   = $False
[XML]      $Configuration   = $null
[PSObject] $Record          = $null
[String]   $Command         = $MyInvocation.MyCommand.Name
[String]   $Timestamp       = Get-Date -format yyyy.MM.dd_hh:mm
[String]   $Output_Message  = "OK"
[String]   $ChannelName     = $null
[String]   $ChannelMinError   = $null
[String]   $ChannelMinWarning = $null
[String]   $ChannelMaxError   = $null
[String]   $ChannelMaxWarning = $null

Write-Verbose "SENSOR:$Command"
Write-Verbose $("_" * 120)
Write-Verbose "$Timestamp : LOG   : Username: $env:username"
Write-Verbose "$Timestamp : LOG   : Session : $( ([System.IntPtr]::Size)*8 )bit Session"

##Collecting DNS Servers if not explicit
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If (!($NameServers)) {
    Try {
        Write-Verbose "$Timestamp : LOG   : Using default nameservers"
        $NameServers = (Get-DnsClientServerAddress | Where-Object {$_.AddressFamily -eq 2}).ServerAddresses | Sort-Object -Unique
        Write-Verbose "$TimeStamp : LOG   : Collected nameservers $($NameServers -join ',')"
    } Catch {
        Write-Error     "$Timestamp : ERROR : Could not get DNSServers from local server."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "DNSServer not found"
        $Boolean_Exit   = $True           
    }
}

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
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {
    Try {
        [XML] $Configuration = Import-PRTGConfigFile -FilePath $Filename -FileType 'XML'
        Write-Verbose   "$Timestamp : LOG   : Imported Channel configuration from XML."
    } Catch {
        Write-Error     "$Timestamp : ERROR : Could not import configuration from XML."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Import failed on configuration file"
        $Boolean_Exit   = $True
    }
}

##Collect SPF-Record to PSObject
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {        
    Try {
        $Record = Get-PRTGSPFRecord -URL $URL -NameServers $NameServers
        Write-Verbose   "$TimeStamp : LOG   : Collected SPF-record for $URL"
        Write-Verbose   "$TimeStamp : LOG   : $($Record.record)"
    } Catch {
        Write-Error     "$Timestamp : ERROR : Could not collect SPF record."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Syntax error on SPF-record"
        $Boolean_Exit   = $True
    }
}

##Resolve IP-blocks to individual addresses
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) {        
    Foreach ($Block in $Record.IPv4Block) {
        Try {
            $Record.IPv4 += Get-PRTGIPAddressesInSubnet -IP $($Block.Split('/')[0]) -Subnet $($Block.Split('/')[1])
            Write-Verbose   "$TimeStamp : LOG   : Added IPv4 block $Block to IPv4."
        } Catch {
            Write-Error     "$Timestamp : ERROR : Could not resolve $Block. (IPv4)"
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Output_Message = "Resolving IPv4-blocks failed"
            $Boolean_Exit   = $True
        }
    }
    Foreach ($Block in $Record.IPv6Block) {
        Try {
            $Record.IPv6 += Get-PRTGIPAddressesInSubnet -IP $($Block.Split('/')[0]) -Subnet $($Block.Split('/')[1]) -Ipv6
            Write-Verbose   "$TimeStamp : LOG   : Added IPv6 block $Block to IPv6."
        } Catch {
            Write-Error     "$Timestamp : ERROR : Could not resolve $Block. (IPv6)"
            Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
            $Output_Message = "Resolving IPv6-blocks failed"
            $Boolean_Exit   = $True
        }
    }
}

##Writing results to PRTG
[String] $Timestamp = Get-Date -format yyyy.MM.dd_hh:mm
If ($Boolean_Exit -eq $False) { 
    Try {
        ## Is there a DNS record
        [String] $ChannelName = 'Is there a SPF-record in DNS?'
        [String] $ChannelMinError   = $null
        [String] $ChannelMinWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMinError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMinError
        $ChannelMinWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMinWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMinError (Error) & $channelminwarning (Warning)"

        ##Setting values
        If ($Record.DNSRecord -eq $True) {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 1
            Write-Verbose    "$TimeStamp : WRITE : Channel '$ChannelName' : 1"
        } Else {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 0
            Write-Verbose    "$TimeStamp : WRITE : Channel '$ChannelName' : 0"
        }

        ##Setting Error- and warningstate
        If ( ($ChannelMinError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.DNSRecord) -eq $False) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "No SPF record found in DNS"
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMinWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.DNSRecord) -eq $False) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "No SPF record found in DNS"
            $Boolean_Warning = $True
        }
 
        ## How many SPFRecords are available in TXT format?
        [String] $ChannelName       = 'Are there multiple DNS records?'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning        
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        If ($Record.MultipleDNS -eq $True) {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 1
            Write-Verbose    "$TimeStamp : WRITE : Channel '$ChannelName' : 1"
        } Else {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 0
            Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : 0"
        }

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.MultipleDNS) -eq $True) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "Multiple SPF records found in DNS"
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.MultipleDNS) -eq $True) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "Multiple SPF records found in DNS"
            $Boolean_Warning = $True
        }

        ## Does SPF record start with V=SPF1?
        [String] $ChannelName       = 'Does the record start with V=SPF1?'
        [String] $ChannelMinError   = $null
        [String] $ChannelMinWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMinError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMinError
        $ChannelMinWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMinWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMinError (Error) & $channelminwarning (Warning)"

        ##Setting values
        If ($Record.StartwVSPF1 -eq $True) {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 1
            Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : 1"
        } Else {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 0
            Write-Verbose    "$TimeStamp : WRITE : Channel '$ChannelName' : 0"
        }

        ##Setting Error- and warningstate
        If ( ($ChannelMinError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.StartwVSPF1) -eq $False ) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "SPF record does not start with V=SPF1"
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } ElseIf ( ($ChannelMinWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.StartwVSPF1) -eq $False ) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "SPF record does not start with V=SPF1"
            $Boolean_Warning = $True
        }

        ## What kind of 'All'-statement is in place (Deny, suspicious, do nothing, not defined)?
        [String] $ChannelName       = 'What kind of ALL statement is used?'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $($Record.All)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $($Record.ALL)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.All) -gt $ChannelMaxError) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "ALL-Statement does not block domains not in SPF"
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.All) -gt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "ALL-Statement only marks as suspect domains not in SPF"
            $Boolean_Warning = $True
        }

        ## Are there records after All
        [String] $ChannelName       = 'Are there records after the ALL-statement?'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelmaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        If ($Record.AfterAll -eq $True) {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 1
            Write-Verbose    "$TimeStamp : WRITE : Channel '$ChannelName' : 1"
        } Else {
            $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value 0
            Write-Verbose    "$TimeStamp : WRITE : Channel '$ChannelName' : 0"
        }

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.AfterAll) -eq $True) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "Records found after the ALL-statement are dismissed."
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        }
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.AfterAll) -eq $True) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "Records found after the ALL-statement are dismissed."
            $Boolean_Warning = $True
        }

        ## Is String-length of a single string below 256?
        [String] $ChannelName       = 'Length of a single string'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $($Record.StringLength)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $($Record.StringLength)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.StringLength) -gt $ChannelMaxError ) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "Stringlength of a single string can be max. 255."
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.StringLength) -gt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "Stringlength of a single string can be max. 255."
            $Boolean_Warning = $True
        }

        ## Are there PTR-records in use?
        [String] $ChannelName       = 'Pointer-records (depricated)'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $(($Record.PTRrecord).Count)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $(($Record.PTRrecord).Count)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($(($Record.PTRrecord).Count) -gt $ChannelMaxError ) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "Pointer-records are deprecated."
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } ElseIf ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($(($Record.PTRrecord).Count) -gt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "Pointer-records are deprecated."
            $Boolean_Warning = $True
        }

        ## Are there less than 10 named records?
        [String] $ChannelName       = 'Named record count'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $($Record.RecordCount)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $($Record.RecordCount)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.RecordCount) -gt $ChannelMaxError ) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "A maximum of 10 named records is recommended."
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.RecordCount) -gt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "A maximum of 10 named records is recommended."
            $Boolean_Warning = $True
        }

        ## Does NSLookup fail on more than 2 records?
        [String] $ChannelName       = 'Do all records resolve in DNS?'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $($Record.Lookupfails)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $($Record.LookupFails)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.LookupFails) -gt $ChannelMaxError ) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "DNS Lookup should not fail on more than 2 records on the SPF."
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } ElseIf ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.LookupFails) -gt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "DNS Lookup should not fail on more than 2 records on the SPF.."
            $Boolean_Warning = $True
        }

        ## TTL
        [String] $ChannelName       = 'TTL'
        [String] $ChannelMinError   = $null
        [String] $ChannelMinWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMinError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMinError
        $ChannelMinWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMinWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMinError (Error) & $channelminwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $($Record.TTL)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $($Record.TTL)"
        
        ##Setting Error- and warningstate
        If ( ($ChannelMinError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.TTL) -gt $ChannelMinError ) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "TTL is to low."
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } ElseIf ( ($ChannelMinWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.TTL) -gt $ChannelMinWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "TTL is to low"
            $Boolean_Warning = $True
        }

        ## No of IPv4 Addresses (do we allow the whole world?)
        [String] $ChannelName       = 'IPv4 Addresses'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $(($Record.IPv4).Count)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $(($Record.IPv4).Count)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.IPv4) -lt $ChannelMaxError) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "Too many IPv4 addresses in SPF"
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.IPv4) -lt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "Too many IPv4 addresses in SPF"
            $Boolean_Warning = $True
        }

        ## No of IPv6 Addresses (do we allow the whole world?)
        [String] $ChannelName       = 'IPv6 Addresses'
        [String] $ChannelMaxError   = $null
        [String] $ChannelMaxWarning = $null
        Write-Verbose "$TimeStamp : $('_'*70)"
        Write-Verbose "$TimeStamp : LOG   : Channel $ChannelName"

        $ChannelMaxError   = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxError
        $ChannelMaxWarning = ($Configuration.prtg.result | Where-Object -Filterscript {$_.Channel -eq $ChannelName}).LimitMaxWarning
        Write-Verbose "$TimeStamp : LOG   : Collected limitvalues $ChannelMaxError (Error) & $channelmaxwarning (Warning)"

        ##Setting values
        $Configuration = Write-PRTGresult -Configuration $Configuration -Channel $ChannelName -Value $(($Record.IPv6).Count)
        Write-Verbose "$TimeStamp : WRITE : Channel '$ChannelName' : $(($Record.IPv6).Count)"

        ##Setting Error- and warningstate
        If ( ($ChannelMaxError -gt 0) -and ($Boolean_Error -eq $False) -and ($($Record.IPv6) -lt $ChannelMaxError) ) {
            Write-Verbose      "$TimeStamp : LOG   : Triggered errorvalue on Channel $ChannelName"
            $Output_Message  = "Too many IPv6 addresses in SPF"
            $Boolean_Warning = $True
            $Boolean_Error   = $True
        } 
        If ( ($ChannelMaxWarning -gt 0) -and ($Boolean_Error -eq $False) -and ($Boolean_Warning -eq $False) -and ($($Record.IPv6) -lt $ChannelMaxWarning) ){
            Write-Verbose      "$TimeStamp : LOG   : Triggered warningvalue on Channel $ChannelName"
            $Output_Message  = "Too many IPv6 addresses in SPF"
            $Boolean_Warning = $True
        }
    } Catch {
        Write-Error     "$Timestamp : ERROR : Could not write to PRTG."
        Write-Error     "$TimeStamp : ERROR : $($_.Exception.Message)."
        $Output_Message = "Could not write results to PRTG"
        $Boolean_Exit   = $True
    }
}

If ($Boolean_Exit -eq $True) { $Configuration.prtg.error = '2' }

## Set Errormessage and write output
$Configuration.prtg.text = $Output_Message
Write-Verbose "$timeStamp : LOG   : $Output_Message given."
Return $Configuration.OuterXml