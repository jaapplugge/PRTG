# **.SENSOR** Get-CitrixLoadIndex

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-CitrixLoadIndex/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to the odata-monitoringfeed running typically running on the Citrix DeliveryController.
It will collect all servers in a DeliveryGroup, and lists the current load-index for each server.

The loadindex is a numerical value between 0 and 80.000. Maximum value is determined by who many factors are
weight in when determining loadindex: no of users, cpu-usage, ram-usage, disk io. You can set errorvalues
via the channelsetting matching your enviroment.

Sensor will do this for every device defined in the ChannelConfiguration XML file. There is a theoretical
max for 50 channels, so max 50 devices per sensor. You have to create an entry for each server in the Channel-
Configuration, so this sensor cannot be used to monitor quick changing DeliveryGroups!!

This sensor uses a serviceAccount to login to the Citrix Odatafeed. For this, an account with readOnly
administrator rights should be created in Citrix Studio.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-CitrixLoadIndex_Sensor.ps1
* Get-CitrixLoadIndex_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.08.2022 initial upload.
