# **.SENSOR** Get-SCCMTasksequenceStatus

![Screenshot header](./Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor connects to the WMI of the SCCM Siteserver, and collects the deployments listed
for the tasksequence listed in the parameter *Tasksequence* from SMC_DeploymentSummary.
Often, a tasksequence is deployed to more than one collection. (At least a collection for new
computers and one for redeployment). It adds up all collectionmembers for each deployment,
and lists:

* How many computers targetten in total,
* How many have successfully completed the tasksequence,
* How many are pending,
* How many failed
* How many status unknown

*(Important: it is possible to count computers twice, if they are listed to the deployment through
more than 1 collection. Easy solution: don't. Tasksequences are high risk deployments, and should be
specific)*

By setting error- and warningstatus in the ChannelConfiguration, you can alert on eg. status failed
and unknown.

Once a computer has failed a tasksequence, it will keep errorstatus until it has completed the
tasksequence through the same deployment. So it is possible to have false positives in the *failed*
channel. I don't have a fix for that (besides upping the errorvalue). Don't use this sensor to track
how many computers have been deployed to a specific OS, use Get-SCCMCustomQuery for that. Use this
sensor to see if nothing failes on your tasksequences.

![Screenshot](./Screenshot_02.jpg)

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-SCCMTasksequenceStatus_Sensor.ps1
* Get-SCCMTasksequenceStatus_ChannelConfiguration.xml

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

* v. 1.0 - 15.03.2019 initial upload.
* v. 1.1 - 18.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
