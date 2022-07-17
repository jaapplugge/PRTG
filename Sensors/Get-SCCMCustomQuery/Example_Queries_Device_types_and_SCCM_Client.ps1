<# Example queries - Device types and SCCM client
Some example queries for SCCM, for sensor Get-SCCMCustomQuery_Sensor.ps1

These queries will list all active and inactive clients. For active clients, is will list whether
it is a Laptop, VM, Desktop, Server and/or VM based on System_G_Enclosure
#>
$All_devices_without_an_SCCM_Client = @"
select
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client
from
    SMS_R_System
where
    (SMS_R_System.Client is null or SMS_R_System.Client = 0)
order by
    SMS_R_System.Name
"@

$All_Clients_with_an_Active_SCCM_Client = @"
select
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client
from
    SMS_R_System
where
    SMS_R_System.Client = 1
@"

$All_VMs_with_an_SCCM_Client = @"
select
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client
    SMS_R_SYSTEM.IsVirtualMachine
from
    SMS_R_System
where
    SMS_R_System.Client = 1
and
    SMS_R_SYSTEM.IsVirtualMachine = true
"@

$All_laptops_with_an_SCCM_Client = @"
select         
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client  
from  
    SMS_R_System
inner join 
    SMS_G_System_SYSTEM_ENCLOSURE 
on 
    SMS_G_System_SYSTEM_ENCLOSURE.ResourceId = SMS_R_System.ResourceId 
where 
    (
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "8" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "9" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "10" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "11" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "12" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "14" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "18" or
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "21"
    )
and
    SMS_R_System.Client = 1
"@

$All_desktops_with_an_SCCM_Client = @"
select         
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client  
from  
    SMS_R_System
inner join 
    SMS_G_System_SYSTEM_ENCLOSURE 
on 
    SMS_G_System_SYSTEM_ENCLOSURE.ResourceId = SMS_R_System.ResourceId 
where 
    (
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "3" or
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "4" or
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "5" or
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "6" or
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "7" or
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "15" or
        SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "16" 
    )
and
    SMS_R_System.Client = 1
"@

$All_servers_with_an_SCCM_Client = @"
select         
    SMS_R_SYSTEM.ResourceID,
    SMS_R_SYSTEM.ResourceType,
    SMS_R_SYSTEM.Name,
    SMS_R_SYSTEM.SMSUniqueIdentifier,
    SMS_R_SYSTEM.Client  
from  
    SMS_R_System
inner join 
    SMS_G_System_SYSTEM_ENCLOSURE 
on 
    SMS_G_System_SYSTEM_ENCLOSURE.ResourceId = SMS_R_System.ResourceId 
where 
    SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes = "23"
and
    SMS_R_System.Client = 1
"@