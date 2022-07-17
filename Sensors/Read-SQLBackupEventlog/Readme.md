# **.SENSOR** Read-SQLBackupEventlog

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Read-SQLBackupEventlog/Screenshot_01.PNG)

## **.DESCRIPTION**

This sensor is written to monitor SQL Backup and logtruncation on an SQL-instance. It will read the
Application eventlog, for Events with source *MSSQLSERVER*, and EventID's:

* 3041 - *Backup failure*
* 18264 - *Database backup has completed successfully
* 18265 - *Transaction log backup has completed successfully*
* 18270 - *Differential database backup has completed successfully*

These events are filtered to the databasenames in the ChannelConfiguration XML-file.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Read-SQLBackupEventlog_Sensor.ps1
* Read-SQLBackupEventlog_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 19.08.2019 initial upload.
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
