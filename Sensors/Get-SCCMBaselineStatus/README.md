# **.SENSOR** Get-SCCMBaselineStatus

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMBaselineStatus/Screenshot_01.jpg)

## **.DESCRIPTION**

This script is supposed to be used as PRTG-sensor. It connects to the WMI of an SCCM
Siteserver, and collects the status of the baselines listed in the ChannelConfiguration XML

SCCM Baselines consist of one or more *Configuration Items*. Configuration Items are settings
(registry keys, WMI queries, scripts etc) which are pushed to the SCCM clients. By deploying a 
baseline to a group of clients or users, you can report or remediate on settings on those clients.
(remediation is possible with a remediation setting or script.)

This sensor collects the deployment of a baseline, looking at the current status (Compliant, 
NonCompliant, Error). It shows the numbers in seperate channels, both in number as in percentage.
Error- and warningstate can be set by settings errorvalues on the channels. These are based on:

* Errorstatus *- Baseline cannot be executed
* Warningstatus *- Client is not compliant to baseline

This sensor is especially usefull for making sure all Sccm-managed client have bitlocker enabled,
have deviceguard enabled, have Defender and Firewall service running etc.

![Screenshot Baselines](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMBaselineStatus/Screenshot_02.jpg)

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-SCCMBaselineStatus_Sensor.ps1
* Get-SCCMBaselineStatus_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.PREREQUISITES**

The following prerequisites should be met:

* The SCCM Siteserver can be reached from the PRTG Probe. This sensor reads the Siteservers WMI, NOT the Wsus- or Updatemanagement server
* The serviceAccount must have read-access to WMI on the Siteserver
* The serviceAccount must be at least "ReadOnly Analyst" in SCCM. (Buildin role)

![Screenshot prereq](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-SCCMBaselineStatus/Screenshot_03.jpg)

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 18.11.2018 initial upload.
* v. 1.1 - 18.11.2019 moved to ADO
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
