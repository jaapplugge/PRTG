# **.SENSOR** Read-ScheduledTaskResult

![Screenshot header](https://github.com/jaapplugge/PRTG/blob/main/Sensors/Read-ScheduledTaskResult/Screenshot_01.PNG)

## **.DESCRIPTION**

This sensor is placed on individual servers, to monitor the result of a scheduled task in the task-
scheduler. Taskscheduler is a very usefull means of automations, this sensor makes sure any scripts
you schedule are actually successfull. This does mean, that scripts you schedule, should post results
back to the taskscheduler. So using returnvalues in your scripts .. yes you should.

For scheduled tasks running in the taskscheduler; if a script (based on taskname) is in the Channel
Configuration XML-file, this sensor will collect result, and interpret agains errorCodes in the
Errorcode Json-file. Based on the returncodes, it will prompt Error or Warning.

Script ingnores scheduled tasks not listed in the ChannelConfiguration XML-file.

## **.FILES**

This sensor contains three files which should be placed in the **CustomSensors\EXEXML**-folder
in PRTG (usually \Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML):

* Read-ScheduledTaskResult_Sensor.ps1
* Read-ScheduledTaskResult_ChannelConfiguration.xml
* Read-ScheduledTaskResult_ErrorCodes.json

PRTG-module should be loaded in PRTG.
Configuration of the sensor object in PRTG is given in the synopsys of the sensor.

## **.ME**

This sensor is written by Jaap Plugge, OGD ict-diensten, for internal use @OGD.
It does not contain customer information. Free to use, no support provided

## **.VERSIONS**

* v. 1.0 - 09.06.2019 initial upload.
* v. 1.2 - 18.11.2021 moved functions to PRTG Module
* v. 2.0 - 10.07.2022 moved to Github
