# **.SENSOR** Get-IntuneDEPCert

![Screenshot header](./Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor monitors the expiration of the DEP-certificate; Apple's Device Enrollment Program.
This certificate expires yearly, and must then be regenerated and uploaded. Without, no new iOS
devices can be added to the Intune portal.

The sensor connects to Graph Api through an app-registration, and calls the Graph-api for the expiration-date.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-IntuneDEPcert_sensor.ps1
* Get-IntuneDEPcert_channelconfiguration.xml

*Example_GraphApi_return.json* is added purely as reference; the desired respons by the GraphApi
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.
PRTG-module should be loaded in PRTG.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.02.2020 initiele upload.
* v. 2.0 - 14.11.2021 moved functions to PRTG Module
* v. 2.1 - 10.07.2022 moved to Github
