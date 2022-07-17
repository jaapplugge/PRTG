# **.REPO** PRTG-Sensoren

This repository contains PRTG-sensors I've written the last couple of years. They are all powershell based sensors, written for monitoring
Window-based enviroments. A lot of them are SCCM / clientmanagement oriented.

Most of the sensors are EXE/XML sensors, and use an XML-formatted ChannelConfigurationfile, next to a powershell-script.

All sensors are written by Jaap Plugge, OGD ict-diensten, unless readme says otherwise. Free to use, no support provided.

Jaap

## Module

The folder **Module** contains a powershell module, with all functions used in my sensors. This module must be loaded to run the sensors.
To install, copy module-files to **C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules**

## Sensors

This repo contains all PRTG-sensors I've written the last years, for monitoring Windows enviroments.

* **Check-SPFRecord**
    *This sensor checks the SPF of an emailaddress based on checks performed by [MXToolbox](https://mxtoolbox.com), and returns result to PRTG.*
* **Get-ADUserQuery**
    *This sensor connects to an ActiveDirectory domain, and looks for users matching an ldap-query. This sensor is especially usefull for monitoring (abuse of) adminAccounts in an ActiveDirectory domain.*
* **Get-DellWaranty_Multiple_sensor**
    *This sensor uses the Dell Techsupport api to monitor how many days of support are left on Dell serverhardware*
* **Get-DHCPScopeStatus**
    *This sensor monitors the usage of DHCP-scopes on a windows-based DHCP-server*
* **Get-IntuneDEPcert**
    *This sensor connects to Graph API, and monitors how many days until expiration ot the DEP certificate*
* **Get-IntuneApplePushcert**
    *This sensor connects to Graph API, and monitors how many days until expiration ot the Apple Push certificate*
* **Get-LoggedInUser**
    *This sensor monitors if a certain user has een interactive login on multiple pc's*
* **Get-MacAfeeStatus**
    *This sensor monitors the status and patchlevel of the mcAfee client on a computer*
* **Get-MSOL_License**
    *This sensor monitors the number of free licenses on an O365 tennant through MSOnline powershell module*
* **Get-PingStatus**
    *This sensor monitors if the computers in the configurationfile are still responding to ping.*
* **Get-RunningProcesses**
    *This sensor monitors if the computers in the configurationfile are running a certain process.*
* **Get-SCCMADR_Alert**
    *This sensor monitors the SCCM Automatic Deployment Rules given in the configurationfile.*
* **Get-SCCMBaselineStatus**
    *This sensor monitors the SCCM Baseline objects given in the configurationfile.*
* **Get-SCCMComponentStatus**
    *This sensor monitors whether the SCCM Components are all functioning.*
* **Get-SCCMCustomQuery**
    *This sensor runs Custom Query objects in SCCM, and returns their results.*
* **Get-SCCMSCEP_Alerts**
    *This sensor monitors if SCCM has detected a virus in one of his clients in an SCCM infrastructure (Defender/Scep)*
* **Get-SCCMSCEP_ClientHealthStatus**
    *This sensor monitors through SCCM whether the SCEP / Defender installation on the clients are still healthy.*
* **Get-SCCMSCEP_DefinitionStatus**
    *This sensor monitors through SCCM whether the SCEP / Defender installtions on the clients are sill receiving their definition updates.*
* **Get-SCCMSiteSystemStatus**
    *This sensor monitors whether the SCCM Site Systems are all functioning.*
* **Get-SCCMTasksequenceStatus**
    *This sensor monitors if SCCM tasksequences in the configuration file are finishing successfully.*
* **Get-SCCMUptime**
    *This sensor monitors if the SCCM managed server it is set on, has properly rebooted in its planned maintenancewindow.*
* **Get-SCCMUpdateStatus**
    *This sensor monitors if the SCCM managed server it is set on, has properly installed its updates in its planned maintenancewindow.*
* **Read-Eventlog**
    *Sensor for reading a clients Eventlog. Returns the number of occurences of a certain event. Can be used to monitor McAfee virusalerts.*
* **Read-EventlogCollector**
    *Sensor for reading an Eventlogcollector-server. Returns the number of occurences of a certain event.*
* **Read-EventlogCollectorUnique**
    *Sensor for reading an Eventlogcollector-server. Returns the number of clients on which a certain event has taken place.*
* **Read-ScheduledTaskResult**
    *Sensor for reading the result of a scheduled task scheduled in the TaskScheduler of a Windows server.*
* **Read-SQLBackupEventlog**
    *Sensor for reading the status of an SQL backup through the evenlog of a Windows server.*
