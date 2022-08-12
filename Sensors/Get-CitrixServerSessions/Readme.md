# **.SENSOR** Get-CitrixServerSessions

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-CitrixServerSessions/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor can be connected to an individual citrix-server. It does not connect to the server itself,
instead it connects to the odata-monitoringfeed running typically running on the Citrix DeliveryController.
It will collect all usersessions for the server the sensor is connected to, and will return:

* Active sessions
* Disconnected sessions
* Terminated sessions
* etc

For both the last 24 hours and the last hour. (these numbers do not add up.. since users can connect,
disconnect, reconnect, etc, the last 24 "hour"-result are not the same as the current 24h)

This sensor uses a serviceAccount to login to the Citrix Odatafeed. For this, an account with readOnly
administrator rights should be created in Citrix Studio. If you need Windows Credentials in PRTG as well as
this sensor, you can use eg. Linux-credentials to store two different credentialsets.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-CitrixServerSessions_Sensor.ps1
* Get-CitrixServerSessions_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 02.08.2022 initial upload.
