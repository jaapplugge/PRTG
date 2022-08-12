# **.SENSOR** Get-CitrixDeliveryGroupServers

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-CitrixDeliveryGroupServers/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to the odata-monitoringfeed running typically running on the Citrix DeliveryController.
It will collect all machines active in a DeliveryGroup, and will report all server working, in maintenance,
unregistered and turned off.

This result can be used as an indicator whether enough servers are available in a deliveryGroup. By setting
errorvalues on the channels, you can alert on lack of servers.

This sensor uses a serviceAccount to login to the Citrix Odatafeed. For this, an account with readOnly
administrator rights should be created in Citrix Studio.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-CitrixDeliveryGroupServers_Sensor.ps1
* Get-CitrixDeliveryGroupServers_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.08.2022 initial upload.
