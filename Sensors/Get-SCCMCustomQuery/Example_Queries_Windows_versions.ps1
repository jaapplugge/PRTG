<# Example queries - Windows versions
Some example queries for SCCM, for sensor Get-SCCMCustomQuery_Sensor.ps1

These queries will list all recent Windows versions

#Source: https://docs.microsoft.com/en-us/windows/desktop/sysinfo/operating-system-version
#Source: https://www.microsoft.com/en-us/itpro/windows-10/release-information
#>

$Query_Computers_with_OS_Windows_7 = @"
select 
    SMS_R_System.ResourceId
    ,SMS_R_System.ResourceType
    ,SMS_R_System.Name
    ,SMS_R_System.SMSUniqueIdentifier
    ,SMS_R_System.Client 
from  
    SMS_R_System 
where 
    SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.1"
"@

$Query_Computers_with_OS_Windows_80 = @"
select 
    SMS_R_System.ResourceId
    ,SMS_R_System.ResourceType
    ,SMS_R_System.Name
    ,SMS_R_System.SMSUniqueIdentifier
    ,SMS_R_System.Client 
from  
    SMS_R_System 
where 
    SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.2"
"@

$Query_Computers_with_OS_Windows_81 = @"
select 
    SMS_R_System.ResourceId
    ,SMS_R_System.ResourceType
    ,SMS_R_System.Name
    ,SMS_R_System.SMSUniqueIdentifier
    ,SMS_R_System.Client 
from  
    SMS_R_System 
where 
    SMS_R_System.OperatingSystemNameandVersion = "Microsoft Windows NT Workstation 6.3"
"@

$Query_Computers_with_OS_Windows_10_1803 = @"
select 
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_OPERATING_SYSTEM 
on 
    SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId 
where 
    SMS_G_System_OPERATING_SYSTEM.BuildNumber = "17134"
"@

$Query_Computers_with_OS_Windows_10_1709 = @"
select 
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_OPERATING_SYSTEM 
on 
    SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId 
where 
    SMS_G_System_OPERATING_SYSTEM.BuildNumber = "16299"
"@

$Query_Computers_with_OS_Windows_10_1703 = @"
select 
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_OPERATING_SYSTEM 
on 
    SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId 
where 
    SMS_G_System_OPERATING_SYSTEM.BuildNumber = "15063"
"@

$Query_Computers_with_OS_Windows_10_1607 = @"
select 
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_OPERATING_SYSTEM 
on 
    SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId 
where 
    SMS_G_System_OPERATING_SYSTEM.BuildNumber = "14393"
"@

$Query_Computers_with_OS_Windows_10_1507 = @"
select 
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_OPERATING_SYSTEM 
on 
    SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId 
where 
    SMS_G_System_OPERATING_SYSTEM.BuildNumber = "10240"
"@