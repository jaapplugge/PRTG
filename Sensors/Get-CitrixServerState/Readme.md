# **.SENSOR** Get-CitrixServerState

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-CitrixServerState/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor can be connected to an individual citrix-server. It does not connect to the server itself,
instead it connects to the odata-monitoringfeed running typically running on the Citrix DeliveryController.
It will collect the serverstate for the server the sensor it is connected to, and will return:

* Whether the server is in Maintenance-mode
* Whether the server is turned off or on
* Whether the server is registered or not
* Or whether the server is acctually working as supposed to

This sensor uses a serviceAccount to login to the Citrix Odatafeed. For this, an account with readOnly
administrator rights should be created in Citrix Studio. If you need Windows Credentials in PRTG as well as
this sensor, you can use eg. Linux-credentials to store two different credentialsets.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-CitrixServerState_Sensor.ps1
* Get-CitrixServerState_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.08.2022 initial upload.
