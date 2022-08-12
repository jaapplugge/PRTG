# **.SENSOR** Get-CitrixAvgLoginTime

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-CitrixAvgLoginTime/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to the odata-monitoringfeed running typically running on the Citrix DeliveryController.
It will collect all machines active in a DeliveryGroup, and for each, it will collect all logged in sessions.
It will calculate average logintime for the user for each server individually, and for all machines in the
deliveryGroup combined.

This result can be used as an indicator whether userexperience for a Citrix Desktop is within norm. By setting
errorvalues on the channels, you can alert on averages above a certain level (e.g. a minut). Channelvalues
and errorlevels are measured in seconds.

Slowest login will be prompted in the returnmessage of the sensor.

Sensor will do this for every device defined in the ChannelConfiguration XML file. There is a theoretical
max for 50 channels, so max 50 devices per sensor. You have to create an entry for each server in the Channel-
Configuration, so this sensor cannot be used to monitor quick changing DeliveryGroups!!

This sensor uses a serviceAccount to login to the Citrix Odatafeed. For this, an account with readOnly
administrator rights should be created in Citrix Studio.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-CitrixAvgLoginTime_Sensor.ps1
* Get-CitrixAvgLoginTime_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.08.2022 initial upload.
