# **.SENSOR** Get-McAfeeStatus

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-McAfeeStatus/Screenshot_01.jpg)

## **.DESCRIPTION**

This sensor is written to monitor the status of a McAfee ePo client installation. It connects to
WMI, and reads the current versions from registry on the remote computer. Through this sensor, you
can read if ePo is functioning, without a login on the ePolicy Orchastrator.
([https://www.mcafee.com/...](https://www.mcafee.com/enterprise/en-us/products/epolicy-orchestrator.html))
The sensor does NOT alert for virusses on the server; it just checks if the client is functioning properly.
For this, it read the following registypaths:

* HKLM:\SOFTWARE\McAfee\
* HKLM:\SOFTWARE\WOW6432Node\McAfee

Since these are x64, this sensor needs powershell x64 to run. The Get-McAfeeStatus_runner.ps1 starts the x64 process.

For monitoring Virus-alerts, a configurationtemplate is added to the Read-Eventlog sensor, listing the events to monitor
through eventlog-monitoring.

![Screenshot macafee](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Get-McAfeeStatus/Screenshot_02.jpg)

## **.FILES**

This sensor contains three files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Get-McAfeeStatus_Sensor.ps1
* Get-McAfeeStatus_Runner.ps1
* Get-McAfeeStatus_ChannelConfiguration.xml

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 03.08.2020 initial upload.
* v. 2.0 - 14.11.2021 moved functions to PRTG Module
* v. 2.1 - 10.07.2022 moved to Github
