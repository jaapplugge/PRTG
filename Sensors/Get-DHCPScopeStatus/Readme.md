# **.SENSOR** Get-DHCPScopeStatus

![Screenshot header](./Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to a Windows DHCP server with powershell, and askes for each channel
listed in the ChannelConfiguration XML-file what the scopestatistics are for the DHCP-scope
Based on use / leases given out, error- and warningstatusses can be set.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-DHCPScopeStatus_Sensor.ps1
* Get-DHCPScopeStatus_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 09.06.2019 initial upload.
* v. 2.0 - 14.11.2021 Moved functions to PRTG Module
* v. 2.1 - 10.07.2022 move to Github
