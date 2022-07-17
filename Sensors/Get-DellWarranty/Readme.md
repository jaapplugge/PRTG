# **.SENSOR** Get-DellWarranty_Multiple_Sensor.ps1

![Screenshot header](./Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to the Dell TechApi v.5, collects a token with an apikey and shared secret,
and then asks the Dell Api the warrantydates; when will support expire. Sensor calculated how many
days left in support.

Sensor will do this for every device defined in the ChannelConfiguration XML file. There is a theoretical
max for 50 channels, so max 50 devices per sensor. The parameter "-useComputername" is added to show host-
name as channelname, purely for making it human readable.

Dell support does not like this sensor! Please configure this sensor to only run once a day. Support does
not expire that fast, and Dell does revoke keys which make 'a lot' of Api-calls. No idea how much 'a lot' is..

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-DellWarranty_Multiple_Sensor.ps1
* Get-DellWarranty_Multiple_Channelconfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 28.12.2018 initial upload.
* v. 1.1 - 17.06.2020 changed the 'select' for the enddate (Dell api changed)
* v. 2.0 - 14.11.2021 moved functions to PRTG Module
* v. 2.1 - 10.07.2022 moved to Github
