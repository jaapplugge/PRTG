# **.SENSOR** Get-SCCMComponentStatus

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMComponentStatus/Screenshot_01.JPG)

## **.DESCRIPTION**

This script is supposed to be used as PRTG-sensor. It connects to the WMI of an SCCM
Siteserver, and collects the status of the SCCM components listed in the ChannelConfiguration XML

It collects (basically) the green checkmarks you can see in the SCCM console,
System status - Component status. If checkmark is not green, sensor will post error. The sensor
**does not** collect reason why, or errormessage; your SCCM admin will have to look for himself in the
errorlog. Don't worry, he is used to it.

## **.IMPORTANT**

On a maxxed out SCCM infrastructure, this sensor will contain 95 channels. Officially, this is
*not* supported by PRTG; 50 should be the absolute max. Sensor has been working on full sccm env.
for years, running on a 1h intervall.

If this channel is running on a full infrastructure, it tents to be quite loud. Depending on how
well the infrastructure is functioning.. I've heard complaints is it 'always in error'. In my
personal opinion, It is perfectly possible to keep the sensor green. But it might be handy to
remove errorvalues or channels you don't plan to act on. You can edit them in the XML. Or you
can just fix you servers.

![Screenshot](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMComponentStatus/Screenshot_02.JPG)

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-SCCMComponentStatus_Sensor.ps1
* Get-SCCMComponentStatus_Configuration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.PREREQUISITES**

The following prerequisites should be met:

* The SCCM Siteserver can be reached from the PRTG Probe. This sensor reads the Siteservers WMI, NOT the Wsus- or Updatemanagement server
* The serviceAccount must have read-access to WMI on the Siteserver
* The serviceAccount must be at least "ReadOnly Analyst" in SCCM. (Buildin role)

![Screenshot prereq](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMComponentStatus/Screenshot_03.JPG)

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 07.12.2017 initial upload.
* v. 1.1 - 18.11.2019 added readme, synopsys
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
