# **.SENSOR** Get-SCCMSiteSystemStatus

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMSiteSystemStatus/Screenshot_01.JPG)

## **.DESCRIPTION**

This script is supposed to be used as PRTG-sensor. It connects to the WMI of an SCCM
Siteserver, and collects the status of the SCCM SiteSystems listed in the ChannelConfiguration XML

It collects (basically) the green checkmarks you can see in the SCCM console,
System status - Site status. If checkmark is not green, sensor will post error. The sensor
**does not** collect reason why, or errormessage; your SCCM admin will have to look for himself in the
errorlog. Don't worry, he is used to it.

![Screenshot](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMSiteSystemStatus/Screenshot_02.JPG)

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-SCCMSiteSystemStatus_Sensor.ps1
* Get-SCCMSiteSystemStatus_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.PREREQUISITES**

The following prerequisites should be met:

* The SCCM Siteserver can be reached from the PRTG Probe. This sensor reads the Siteservers WMI, NOT the Wsus- or Updatemanagement server
* The serviceAccount must have read-access to WMI on the Siteserver
* The serviceAccount must be at least "ReadOnly Analyst" in SCCM. (Buildin role)

![Screenshot prereq](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMSiteSystemStatus/Screenshot_03.JPG)

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 07.12.2017 initial upload.
* v. 1.1 - 22.07.2018 added readme, synopsys
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
