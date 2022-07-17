# **.SENSOR** Get-SCCMCustomQuery

![Screenshot header](./Screenshot_01.jpg)

## **.DESCRIPTION**

This script is supposed to be used as PRTG-sensor. It connects to the WMI of an SCCM
Siteserver, and collects custom query-objects listed in the ChannelConfiguration XML

Custom queries are listed in Monitoring - Queries. They are listed in the WMI of the
siteserver, and can be used to create reports. But you can also use them to alert on
your SCCM enviroment. By using a prefix (I use PRTG) in SCCM, you can run multiple
(small) queries on yoour enviroment, one channel per query, to keep overview.

Sensor does not run the query Object. It collects the query-object, and runs the code/
query within. Results are counted and listed in the channels; you can set ErrorValues
or Warningvalues on it.

A number of usecases are in the example ps1 files. You can write any query you would like,
but keep in mind: sensor will run the query itself, and wait for it before results. This
can really slow down your PRTG.

## **.EXAMPLES**

* Example_Queries_Windows_versions.ps1 *- queries to collect all different versions of Windows (not uptodate)*
* Example_Queries_Device_types_and_SCCM_Client.ps1 *- a number of queries to collect and show devicetype: laptop, desktop, server etc*
* Example_Queries_SecurityCompliancy.ps1 *- Bitlocker, Defender, firewall etc*

Matching XML ChannelConfigurationfiles are included.

![Screenshot](./Screenshot_02.jpg)

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-SCCMComponentStatus_Sensor.ps1
* Get-SCCMComponentStatus_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.PREREQUISITES**

The following prerequisites should be met:

* The SCCM Siteserver can be reached from the PRTG Probe. This sensor reads the Siteservers WMI, NOT the Wsus- or Updatemanagement server
* The serviceAccount must have read-access to WMI on the Siteserver
* The serviceAccount must be at least "ReadOnly Analyst" in SCCM. (Buildin role)

![Screenshot prereq](./Screenshot_03.jpg)

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 07.30.2018 initial upload.
* v. 1.1 - 06.07.2019 added custom error messages
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
