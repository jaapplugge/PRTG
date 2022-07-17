# **.SENSOR** Read-EventlogCollectorUnique

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Read-EventlogCollectorUnique/Screenshot_01.PNG)

## **.DESCRIPTION**

This sensor is very similar to the Read-EventlogCollector sensor; it has been written to
monitor eventlogs on a remote eventlog-collector, a Windows server with an eventlogcollector
service configured. It connects to that server using a powershell session, and queries the
evenlog through an XPath query. This can be used for any events you would like (and have
configured in the eventlogCollector).

The difference with the Read-EvenlogCollector is, that this sensor will return the number of
computers an event has occured on, not the number of occurences of a given event.

Examples are given to monitor McAfee; to monitor:

* License activation issues *(on a hybrid situation, Office not recognising users' license)*
* Applocker events *(user attempting to start a disallowed application)*
* BSOD's
* Drivemappings *(a drivemapping from GPO does not connect)*
* NTFS errors
* VPN-errors *(for AlwaysOn VPN, monitoring broken ipsec-tunnels)*

Combined with an eventlogcollector, this can provide a lot of insight to the working of your
client-computers. Any events can be read, based on XPath queries you define in the Channel
Configuration XML. (as long as they are collected by the eventlogcollector)

With a 50 channels maximum, you can query the occurence of 50 events at once, with a single sensor.
But although XPath is quite quick, make sure not to overload your server, this sensor is quite
resource-heavy.

## **.IMPORTANT**

This sensor does not show how often a certain event is listed in the eventlogCollector total. A single
computer can have multiple entries, this sensor counts every computer *once*. If you are looking for
how many times an event has happened, use the sensor Read-EventlogCollector.

## **.FILES**

This sensor contains two files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Read-EventlogCollector_Sensor.ps1
* Read-EventlogCollector_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.
A sensorconfiguration for monitoring McAfee Antivirus and McAfee Updates events are included:

* Read-EventlogCollectorUnique_LicenseActivation.xml
* Read-EventlogCollectorUnique_Applocker.xml
* Read-EventlogCollectorUnique_BSOD.xml
* Read-EventlogCollectorUnique_Drivemapping.xml
* Read-EventlogCollectorUnique_NTFS.xml
* Read-EventlogCollectorUnique_VPN.xml

## **.PREREQUISITES**

The following prerequisites should be met:

* The PRTG service-account shoud have read-access rights to the remote server running the eventlogcollector
* The PRTG service-account shoud have rights to connect to this remote server using PSSession

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 28.11.2018 initial upload.
* v. 1.2 - 14.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
