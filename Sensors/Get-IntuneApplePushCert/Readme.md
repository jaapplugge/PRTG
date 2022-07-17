# **.SENSOR** Get-IntuneApplePushCert

![Screenshot header](./Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor monitors certificate expiration for the Apple Push Notification certificate. This certificate expires
every year, and must be gerenerated and uploaded in the Intune Portal. Without, *no* settings and applications
can be pushed onto iOS devices.

The sensor connects to Graph Api through an app-registration, and calls the Graph-api for the expiration-date.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-IntuneApplePushcert_sensor.ps1
* Get-IntuneApplePushcert_channelconfiguration.xml

*Example_GraphApi_return.json* is added purely as reference; the desired respons by the GraphApi
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.
PRTG-module should be loaded in PRTG.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.02.2020 initial upload.
* v. 2.0 - 14.11.2021 Moved functions to PRTG Module
* v. 2.1 - 10.07.2022 move to Github
