# Netatmo Weather Station Shell Script
A Linux Shell / Bash script for querying the data of your Netatmo weather station(s). This script only uses the public Netatmo API. Just specify your username and password from your Netatmo account.


## Usage

	netatmo.sh -h
	
	netatmo.sh [-u <user>] [-p <pass>] -D
	
	netatmo.sh [OPTIONS]

 
General options
---------------
<b>-h</b><br>
Display this help message and exit
 
<b> -u [username]</b><br>
User to use (default is set in the configuration area of this script).
A guest user is sufficient.
 
<b>-p [password]</b><br>
Passwordassword to use (default is set in the configuration area of this script)
 
<b>-D</b><br>
Don't fetch data, but get device info and current readings.
If jq is available, it's used to format and pretty-print the output.
 
Additional general options for data fetching (not -D) mode only
---------------------------------------------------------------
<b> -x</b><br> Get the data as Excel, not as CSV
 
<b> -i</b><br>  In the output filename, use the module's ID instead of it's name
 
<b> -o  [directory]</b><br>
     Directory to put the received files in (defaults to the current directory)
 
Date/time selection options (not for -D mode)
---------------------------------------------
<b> -s [date time]</b><br>
Start time (format: 'YYYY-MM-DD HH:MM:SS')
Defaults to now - 3600 seconds
 
<b> -e [date time]</b><br>
End time (format: 'YYYY-MM-DD HH:MM:SS')
Defaults to now
 
Date/time selection shortcuts (not for -D mode)
-----------------------------------------------
<b>-n [seconds]</b><br>
     Get data for the last <seconds> seconds
 
<b>-y</b><br>  Get yesterday's data
  
<b>-t</b><br>  Get today's data (00:00:00 until now)
  
<b>-d [yyyy-mm-dd]</b><br>
     Get historical data for the specified day
  
<b>-T</b><br>  Get this month' data
 
<b>-L</b><br>  Get last month' data
  
<b>-M [yyyy-mm]</b><br>
     Get data for the specified month
 
Output
------
In -D mode, netatmo.sh prints out the received JSON object to STDOUT.
 
In data fetching mode, netatmo.sh generates a separate output file
for each sensor. For the main module e.g. you'll get five different files,
one for temperature, humidity, co2, noise and pressure each.
 
The files will be placed in your current directory (or in whatever directory
you specified using the -o option).
 
Filenames are 
    [module]_[sensor]_[time or timerange].[extension]
 
    [module]
        Is the module's name as given in your configuration, or it's
        ID ('aa:bb:cc:dd:ee:ff') if requested via -i.
 
    [sensor]
        Is the name of the sensor as defined by NetAtmo 
        (co2, humidity, noise, pressure, rain, temperature etc.)
 
    [time or timerange]
        Depends on your request.
 
        If you request data for a specific day (-d, -y, -t), it will be
        the day (e.g. '2016-01-16'). For today, where you don't get a
        whole day's worth of data (but only from midnight to now),
        a '-(partially)' is added (-] '2016-01-17-(partially)').
 
        If you request data for a specific month (-M, -L, -T), it will be
        the month (2016-01). For 'this month', where you don't get a whole
        month' worth of data (but only from the 1st to now), a '-(partially)'
        is added (-] '2016-01-(partially)').
 
        In any other case, it will be the exact timerange as time span
        like '[2016-01-17-10-00-00_2016-01-18-13-42-51]'
         
    [extension]
        Is 'csv' for csv files, 'xls' for Excel (if requested using -x)
 
    Some filename examples:
 
    livingroom_temperature_2016-02-16-13-31-57_2016-02-17-11-41-57.csv
    (generic)
 
    aa:bb:cc:dd:ee:ff_temperature_2016-02-16-13-31-57_2016-02-17-11-41-57.csv
    (generic with -i)
 
    livingroom_temperature_2016-01.csv
    livingroom_temperature_2016-02-(partially).csv
    (specific day)
 
    livingroom_temperature_2016-02-16.csv
    livingroom_temperature_2016-02-17-(partially).csv
    (specific month)
 
Examples
--------
 
### netatmo.sh -h
Get the help screen
 
### netatmo.sh -D
 
  Fetch device information
 
### netatmo.sh
 
  Get data for the last hour
 
### netatmo.sh -n 1800
 
  Get data for the last half hour (= 1800s)
 
### netatmo.sh -t
 
  Get data since midnight until now
 
### netatmo.sh -T
 
  Get data since the 1st of the current month until now
 
### netatmo.sh -y
 
  Get data for yesterday
 
### netatmo.sh -L
 
  Get data for the last month
 
### netatmo.sh -d 2016-02-17
 
  Get data for February 17th 2016
 
### netatmo.sh -M 2016-02
 
  Get data for February 2016
 
### netatmo.sh -s '2016-05-03 17:31:15' -e '2016-05-04 12:21:17'
 
  Get data from 2016-05-03 17:31:15 to 2016-05-04 12:21:17
 
### netatmo.sh-s '2016-08-30 17:31:15'
 
  Get data from 2016-08-30 17:31:15 until now