# **.SENSOR** Read-Eventlog

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Read-Eventlog/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor is written to monitor eventlogs on remote servers. Is connects to a server using a
powershell session, and queries the evenlog through an XPath query. This can be used for any
events you would like.

Examples are given to monitor McAfee; to monitor definitionupdates, virusalerts etc on remote
servers (without the use of an McAfee ePO-server). But it can be used to query any events you
would like to be alerted on.

Definition of the alerts are given in the ChannelConfiguration XML. For all channels added, you
can provide EventID, Eventlog and Source, to define what event to query for. And a timeframe, to
list how far back sensor should check. The number of events returned are listed in the PRTG-channel.

You can then put error- and warninglevels on it as needed. Custom errormessages and warningmessages
can be added in the XML.

With a 50 channels maximum, you can query the occurence of 50 events at once, with a single sensor.
But although XPath is quite quick, make sure not to overload your server, this sensor is quite
resource-heavy.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Read-Eventlog_Sensor.ps1
* Read-Eventlog_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.
A sensorconfiguration for monitoring McAfee Antivirus and McAfee Updates events are included:

* Read-Eventlog_McAfee_Updates.xml
* Read-Eventlog_McAfee_Antivirus.xml

## **.PREREQUISITES**

The following prerequisites should be met:

* The PRTG service-account shoud have read-access rights to the remote servers eventlog
* The PRTG service-account shoud have rights to connect to the remote server using PSSession

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 03.08.2020 initial upload.
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
