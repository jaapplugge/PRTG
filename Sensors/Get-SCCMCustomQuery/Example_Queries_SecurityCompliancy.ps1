$Query_Computers_With_bitlocker_turned_off = @"
select 
    SMS_R_SYSTEM.ResourceID
    ,SMS_R_SYSTEM.ResourceType
    ,SMS_R_SYSTEM.Name
    ,SMS_R_SYSTEM.SMSUniqueIdentifier
    ,SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_BITLOCKER_DETAILS 
on 
    SMS_G_System_BITLOCKER_DETAILS.ResourceID = SMS_R_System.ResourceId 
where 
    SMS_G_System_BITLOCKER_DETAILS.Compliant = 0 
and 
    SMS_R_System.Client = 1
and
    SMS_R_SYSTEM.IsVirtualMachine = 0
"@

$Query_Computers_With_bitlocker_turned_on = @"
select 
    SMS_R_SYSTEM.ResourceID
    ,SMS_R_SYSTEM.ResourceType
    ,SMS_R_SYSTEM.Name
    ,SMS_R_SYSTEM.SMSUniqueIdentifier
    ,SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_BITLOCKER_DETAILS 
on 
    SMS_G_System_BITLOCKER_DETAILS.ResourceID = SMS_R_System.ResourceId 
where 
    SMS_G_System_BITLOCKER_DETAILS.Compliant = 1 
and 
    SMS_R_System.Client = 1
and
    SMS_R_SYSTEM.IsVirtualMachine = 0
"@

$Query_Computers_With_bitlocker_state_unknown = @"
select 
    SMS_R_SYSTEM.ResourceID
    ,SMS_R_SYSTEM.ResourceType
    ,SMS_R_SYSTEM.Name
    ,SMS_R_SYSTEM.SMSUniqueIdentifier
    ,SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_BITLOCKER_DETAILS 
on 
    SMS_G_System_BITLOCKER_DETAILS.ResourceID = SMS_R_System.ResourceId 
where 
    SMS_G_System_BITLOCKER_DETAILS.Compliant = 2 
and 
    SMS_R_System.Client = 1
and
    SMS_R_SYSTEM.IsVirtualMachine = 0
"@

$All_Cllients_With_Firewall_not_running = @"
select 
    SMS_R_SYSTEM.ResourceID
    ,SMS_R_SYSTEM.ResourceType
    ,SMS_R_SYSTEM.Name
    ,SMS_R_SYSTEM.SMSUniqueIdentifier
    ,SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_SERVICE 
on 
    SMS_G_System_SERVICE.ResourceID = SMS_R_System.ResourceId 
where 
    SMS_G_System_SERVICE.Name = "mpssvc" 
and 
    (
        SMS_G_System_SERVICE.StartMode IS NOT "Auto" -or
        SMS_G_System_SERVICE.Status    IS NOT "OK"
    )
and
    SMS_R_SYSTEM.IsVirtualMachine = 0
"@

$All_Cllients_With_WinDefend_not_running = @"
select 
    SMS_R_SYSTEM.ResourceID
    ,SMS_R_SYSTEM.ResourceType
    ,SMS_R_SYSTEM.Name
    ,SMS_R_SYSTEM.SMSUniqueIdentifier
    ,SMS_R_SYSTEM.Client 
from 
    SMS_R_System 
inner join 
    SMS_G_System_SERVICE 
on 
    SMS_G_System_SERVICE.ResourceID = SMS_R_System.ResourceId 
where 
    SMS_G_System_SERVICE.Name = "WinDefend" 
and 
    (
        SMS_G_System_SERVICE.StartMode IS NOT "Auto" -or
        SMS_G_System_SERVICE.Status    IS NOT "OK"
    )
and
    SMS_R_SYSTEM.IsVirtualMachine = 0
"@