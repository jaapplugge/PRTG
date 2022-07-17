# **.SENSOR** Get-SCCMADRAlert

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMADRAlert/Screenshot_01.JPG)

## **.DESCRIPTION**

This script is ment to be used as a PRTG-server. It connects to an SCCM Siteserver through
WMI, and collects all active alerts for the Automatic Deployment Rules. Automatic Reployment
Rules are rules SCCM uses to power WSUS, and decide what computer installes which updates at
what time.

To use this sensor, the ADR's must be enabled to generate alerts in the SCCM console (as shown
in screenshot). The displayname of the ADR must be added as channel in the ChannelConfiguration
XML-file. This is used to filter alerts to the correct channel. Sensor will only consider *enabled*
ADR's. Sensor does *not* show why a sensor is red; it will not show errormessage or logging.
The SCCM-admin will have to figure the reason out himself.

![Screenshot adr](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMADRAlert/Screenshot_02.JPG)

## **.IMPORTANT**

Sensor will keep alert-status / error-status until either:

* The ADR has finished successfully.
* The ADR has been disabled or renamed.
* The Errorlimit has been removed in PRTG.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-SCCMADRAlert_Sensor.ps1
* Get-SCCMADRAlert_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.PREREQUISITES**

The following prerequisites should be met:

* The SCCM Siteserver can be reached from the PRTG Probe. This sensor reads the Siteservers WMI, NOT the Wsus- or Updatemanagement server
* The serviceAccount must have read-access to WMI on the Siteserver
* The serviceAccount must be at least "ReadOnly Analyst" in SCCM. (Buildin role)

![Screenshot prereq](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMADRAlert/Screenshot_03.JPG)

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 11.08.2019 initiele upload.
* v. 1.1 - 18.11.2019 moved to ADO
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
