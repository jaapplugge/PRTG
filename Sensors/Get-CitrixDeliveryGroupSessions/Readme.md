# **.SENSOR** Get-CitrixDeliveryGroupSessions

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-CitrixDeliveryGroupSessions/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to the odata-monitoringfeed running typically running on the Citrix DeliveryController.
It will collect all usersessions in a DeliveryGroup, both for the last 24 hours, and for the last hour.
It will report on:

* Active sessions
* Terminated sessions
* Disconnected sessions
* NonBrokered sessions
* Pending & preparing sessions

This result can be used as an indicator whether enough servers are available in a deliveryGroup. By setting
errorvalues on the channels, you can alert on certain sessions occuring (eg. nonbrokered sessions).

This sensor uses a serviceAccount to login to the Citrix Odatafeed. For this, an account with readOnly
administrator rights should be created in Citrix Studio.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-CitrixDeliveryGroupSessions_Sensor.ps1
* Get-CitrixDeliveryGroupSessions_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.08.2022 initial upload.
