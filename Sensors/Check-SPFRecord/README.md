# **.SENSOR** Check-SPFRecord_Sensor

![Screenshot header](Screenshot_01.jpg)

## **.DESCRIPTION**

This script is meant to be used as EXE/XML PRTG-sensor. It will call for an SPF-record through a
DNS-resolve on domains TXT-records, containing 'SPF'. On this record, sensor will perform checks
based on MXToolbox:

* Is there a DNS-record present?
* Is there a SPF-record present?
* Is SPF-record 'TXT'-formatted?
* Is there only one record present?
* Does the record start with v=spf1?
* Are there characters after the ALL statement?
* What ALL statement is used? ~, - of ?
* Are there pointer-records present (deprecated)
* No more than 10 Include-domainen should be resolved
* No more than 2 domains in SPF cannot be resolved.
* Is SPF string less than 255 characters long?
* How many IPv4 adressen are in SPF
* How many IPv6 adressen are in SPF

Whether the syntax of the record is correct, will follow from checks performed (if check cannot be
completed, syntax is incorrect)

If in error, first error will be shown in text. If no errors, first warning. Every result will be posted in a
seperate channel (based on channel configuration XML file)

![Screenshot](./Screenshot_02.jpg)

## **.TO-DO**

This script is version 1.0; some improvements can be made:

* According to RFC, it is possible to use CIDR for IPv6 address blocks; script cannot count the number of addresses in an ipv6 block. It will only use first address.
* Checking on 10 lookups max should be recursive lookup. Script will not check recursively.
* Script does not check for local ip-addresses in the ipv4 or ipv6 block. 99 / 100 a local address should not be listed (sysadmin error); would like to check for those
* +Characters in string are not yet ignored. Have never seen this in real life.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Check-SPFRecord_Sensor.ps1
* Check-SPFRecord_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 10.12.2019: initiele upload.
* v. 2.0 - 14-11-2021: Moved functions to PRTG Module
* v. 2.1 - 10-07-2022: Upload to github
