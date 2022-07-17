# **.SENSOR** Get-RunningProcesses

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-RunningProcesses/Screenshot_01.JPG)

## **.DESCRIPTION**

This sensor is written to monitor kiosk-pc's; NUC's taped to the back of TV-screens without user-interaction.
It monitors whether an instance of the designated process (eg. excel, a browser) given in the ChannelConfiguration
XML-file is running on the client.
It is part of a series of three sensors:

* Get-Pingstatus *-Are all kiosk-pc's turned on?*
* Get-LoggedInUser *-Is the pc locked or is the designated user logged in?*
* Get-RunningProcesses *-Is the designated process running?*

This sensor monitors more than 1 device; it has a channel for each designated kioskpc. For each pc, it will
check for the designated user in the ChannelConfiguration XML-file. This saves a lot of sensors and devices,
compared to adding all seperate kioskpc and adding 'normal' sensors. But it adds a lot of runtime to the sensor,
don't run this sensor to often/ only a couple of times a day.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-RunningProcesses_Sensor.ps1
* Get-RunningProcesses_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 11.08.2019 initiele upload.
* v. 1.1 - 18.11.2019 moved to ADO
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
