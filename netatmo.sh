#!/bin/bash

# ####################################### #
# CONFIGURATION SECTION #
# ####################################### #

# Default NetAtmo credentials (a guest user is sufficient)
# can be overwritten using -u and -p
user="my.mailaddress@mailprovider.com"
pass="my secret password"

# ID of the main station
master="aa:bb:cc:dd:ee:ff"

# available modules and their sensors
sensors_config=(
    #"<module id>;<module name>;<sensor 1>;...;<sensor n>"
    "aa:bb:cc:dd:ee:ff;room_x;temperature;humidity;co2;noise;pressure"
    "aa:bb:cc:dd:ee:ff;room_y;temperature;humidity;co2"
    "aa:bb:cc:dd:ee:ff;rain_meter;rain"
)

# by default, if called without any modifyer,
# we fetch the data for the last $period seconds
period=3600

# default output directory
# outdirectory=~/netatmo_download
outdirectory='.'

# use module id or name in the filenames?
# possible values are 'id' and 'name',
# can be overwritten using -i
module_in_filename='id'

# how often do we try to fetch a specific file and what's
# the expected min size (will be reset for daily and monthly downloads)
max_download_tries=3
min_file_size=140

# ####################################### #
# NO MORE CONFIGURATION BEYOND THIS POINT #
# ####################################### #

#------------------------------------------------------------------------------
usage () 
{
cat <<END_OF_HELP

Usage: $(basename $0) -h

       $(basename $0) [-u <user>] [-p <pass>] -D

       $(basename $0) [OPTIONS]

Thsi scripts downloads data from the NetAtmo website.

You should first edit the configuration section of this script (the first 40
lines), add a valid user and password if you don't want to use the -u and -p
parameter with each call. A guest user, not able to change the configuration
at the WebAtmo site, is sufficient.

Then fetch the device information using -D.

With the information given there, complete the configuration in the config
section ("master" and "sensors_config"), and the script is ready for daily
use.

General options
---------------
 -h  Display this help message and exit

 -u <username>
     User to use (default is set in the configuration area of this script)

     A guest user is sufficient.

 -p <password>
     Password to use (default is set in the configuration area of this script)

 -D  Don't fetch data, but get device info and current readings.
     If jq is available, it's used to format and pretty-print the output.

Additional general options for data fetching (not -D) mode only
---------------------------------------------------------------
 -x  Get the data as Excel, not as CSV

 -i  By default, the output filenames are containing the module's
     ${module_in_filename}. Use -i to switch between id and name

 -o  <directory>
     Directory to put the received files in (defaults to the current directory)

Date/time selection options (not for -D mode)
---------------------------------------------
 -s <date time>
     Start time (format: 'YYYY-MM-DD HH:MM:SS')

     Defaults to now - $period seconds

 -e <date time>
     End time (format: 'YYYY-MM-DD HH:MM:SS')

     Defaults to now

Date/time selection shortcuts (not for -D mode)
-----------------------------------------------
 -n <seconds>
     Get data for the last <seconds> seconds

 -y  Get yesterday's data
 
 -t  Get today's data (00:00:00 until now)
 
 -d <yyyy-mm-dd>
     Get historical data for the specified day
 
 -T  Get this (calendar) month' data

 -L  Get last (calendar) month' data
 
 -M <yyyy-mm>
     Get data for the specified month

Output
------

In -D mode, $(basename $0) prints out the received JSON object to STDOUT.

In data fetching mode, $(basename $0) generates a separate output file
for each sensor. For the main module e.g. you'll get five different files,
one for temperature, humidity, co2, noise and pressure each.

The files will be placed in your current directory (or in whatever directory
you specified using the -o option).

Filenames are 
    <module>_<sensor>_<time or timerange>.<extension>

    <module>
        Is the module's name as given in your configuration, or it's
        ID ('aa:bb:cc:dd:ee:ff') if requested via -i.

    <sensor>
        Is the name of the sensor as defined by NetAtmo 
        (co2, humidity, noise, pressure, rain, temperature etc.)

    <time or timerange>
        Depends on your request.

        If you request data for a specific day (-d, -y, -t), it will be
        the day (e.g. '2016-01-16'). For today, where you don't get a
        whole day's worth of data (but only from midnight to now),
        a '-(partially)' is added (-> '2016-01-17-(partially)').

        If you request data for a specific month (-M, -L, -T), it will be
        the month (2016-01). For 'this month', where you don't get a whole
        month' worth of data (but only from the 1st to now), a '-(partially)'
        is added (-> '2016-01-(partially)').

        In any other case, it will be the exact timerange as time span
        like '<2016-01-17-10-00-00_2016-01-18-13-42-51>'
        
    <extension>
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

$ $(basename $0) -h

  Get the help screen

$ $(basename $0) -D

  Fetch device information

$ $(basename $0)

  Get data for the last hour

$ $(basename $0) -n 1800

  Get data for the last half hour (= 1800s)

$ $(basename $0) -t

  Get data since midnight until now

$ $(basename $0) -T

  Get data since the 1st of the current month until now

$ $(basename $0) -y

  Get data for yesterday

$ $(basename $0) -L

  Get data for the last month

$ $(basename $0) -d 2016-02-17

  Get data for February 17th 2016

$ $(basename $0) -M 2016-02

  Get data for February 2016

$ $(basename $0) -s '2016-05-03 17:31:15' -e '2016-05-04 12:21:17'

  Get data from 2016-05-03 17:31:15 to 2016-05-04 12:21:17

$ $(basename $0)-s '2016-08-30 17:31:15'

  Get data from 2016-08-30 17:31:15 until now
END_OF_HELP
}

#------------------------------------------------------------------------------
getmeasurecsv() {

    # shameless stolen from Michael Miklis, 
    # https://www.michaelmiklis.de/export-netatmo-weather-station-data-to-csv-excel/
    
    # ------------------------------------------------------
    # Help
    # ------------------------------------------------------
    # usage: getmeasurecsv <USER> <PASSWORD> <DEVICE_ID> <MODULE_ID> <TYPE> <STARTDATE> <ENDDATE> <FORMAT>
    #
    # USER + PASSWORD -> your NetAtmo Website login
    # DEVICE_ID -> Base Station ID
    # MODULE_ID -> Module ID
    # TYPE -> Comma-separated list of sensors (Temperature,Humidity,etc.)
    # STARTDATE -> Begin export date in format YYYY-mm-dd HH:MM
    # ENDDATE -> End export date in format YYYY-mm-dd HH:MM
    # FORMAT -> csv or xls
 
    # ------------------------------------------------------
    # Parsing Arguments
    # ------------------------------------------------------
    USER=$1
    PASS=$2
 
    DEVICE_ID=$3
    MODULE_ID=$4
    TYPE=$5
    DATETIMEBEGIN=$6
    DATETIMEEND=$7
    FORMAT=$8
 
    # ------------------------------------------------------
    # Define some constants
    # ------------------------------------------------------
    URL_LOGIN="https://auth.netatmo.com/en-us/access/login"
    URL_POSTLOGIN="https://auth.netatmo.com/access/postlogin"
    API_GETMEASURECSV="https://api.netatmo.com/api/getmeasurecsv"
    SESSION_COOKIE="cookie_sess.txt"
 
 
    # ------------------------------------------------------
    # Convert start and end date to timestamp
    # ------------------------------------------------------
    DATEBEGIN="$(date --date="$DATETIMEBEGIN" "+%d.%m.%Y")"
    TIMEBEGIN="$(date --date="$DATETIMEBEGIN" "+%H:%M")"
    DATE_BEGIN="$(date --date="$DATETIMEBEGIN" "+%s")"
    DATEEND="$(date --date="$DATETIMEEND" "+%d.%m.%Y")"
    TIMEEND="$(date --date="$DATETIMEEND" "+%H:%M")"
    DATE_END="$(date --date="$DATETIMEEND" "+%s")"
 
 
    # ------------------------------------------------------
    # URL encode the user entered parameters
    # ------------------------------------------------------
    USER="$(urlencode $USER)"
    PASS="$(urlencode $PASS)"
    DEVICE_ID="$(urlencode $DEVICE_ID)"
    MODULE_ID="$(urlencode $MODULE_ID)"
    TYPE="$(urlencode $TYPE)"
    DATEBEGIN="$(urlencode $DATEBEGIN)"
    TIMEBEGIN="$(urlencode $TIMEBEGIN)"
    DATEEND="$(urlencode $DATEEND)"
    TIMEEND="$(urlencode $TIMEEND)"
    FORMAT="$(urlencode $FORMAT)"
 
 
    # ------------------------------------------------------
    # Now let's fetch the data
    # ------------------------------------------------------
 

    # get token from hidden <input> field
    TOKEN="$(curl --silent -c $SESSION_COOKIE $URL_LOGIN | sed -n '/token/s/.*name="_token"\s\+value="\([^"]\+\).*/\1/p')"

    # and now we can login using cookie, id, user and password
    curl --silent -d "_token=$TOKEN&email=$USER&password=$PASS" -b $SESSION_COOKIE -c $SESSION_COOKIE $URL_POSTLOGIN > /dev/null

    # next we extract the access_token from the session cookie
    ACCESS_TOKEN="$(cat $SESSION_COOKIE | grep netatmocomaccess_token | cut -f7)"
 
    # build the POST data
    PARAM="access_token=$ACCESS_TOKEN&device_id=$DEVICE_ID&type=$TYPE&module_id=$MODULE_ID&scale=max&format=$FORMAT&datebegin=$DATEBEGIN&timebegin=$TIMEBEGIN&dateend=$DATEEND&timeend=$TIMEEND&date_begin=$DATE_BEGIN&date_end=$DATE_END"
 
    # now download data as csv
    retrieved_data=$(curl -d $PARAM $API_GETMEASURECSV)
    if [ $? -eq 0 ];then
        echo "${retrieved_data}"
    fi
 
    # clean up
    rm $SESSION_COOKIE
}

#------------------------------------------------------------------------------
listDevices() {

    # shameless stolen from Michael Miklis, 
    # https://www.michaelmiklis.de/read-netatmo-weather-station-data-via-script/
    
    # ------------------------------------------------------
    # Help
    # ------------------------------------------------------
    # usage: listdevices <USER> <PASSWORD>
    #
    # USER + PASSWORD -> your NetAtmo Website login
 
    # ------------------------------------------------------
    # Parsing Arguments
    # ------------------------------------------------------
    USER=$1
    PASS=$2
 
 
    # ------------------------------------------------------
    # Define some constants
    # ------------------------------------------------------
    URL_LOGIN="https://auth.netatmo.com/en-us/access/login"
    URL_POSTLOGIN="https://auth.netatmo.com/access/postlogin"
    API_GETMEASURECSV="https://api.netatmo.com/api/devicelist"
    SESSION_COOKIE="cookie_sess.txt"
 
 
    # ------------------------------------------------------
    # URL encode the user entered parameters
    # ------------------------------------------------------
    USER="$(urlencode $USER)"
    PASS="$(urlencode $PASS)"
 
 
    # ------------------------------------------------------
    # Now let's fetch the data
    # ------------------------------------------------------

    # get token from hidden <input> field
    TOKEN="$(curl --silent -c $SESSION_COOKIE $URL_LOGIN | sed -n '/token/s/.*name="_token"\s\+value="\([^"]\+\).*/\1/p')"

    # and now we can login using cookie, id, user and password
    curl --silent -d "_token=$TOKEN&email=$USER&password=$PASS" -b $SESSION_COOKIE -c $SESSION_COOKIE $URL_POSTLOGIN > /dev/null

    # next we extract the access_token from the session cookie
    ACCESS_TOKEN="$(cat $SESSION_COOKIE | grep netatmocomaccess_token | cut -f7)"
 
    # build the POST data
    PARAM="access_token=$ACCESS_TOKEN"
 
    # now download json data
    curl -d $PARAM $API_GETMEASURECSV
 
    # clean up
    rm $SESSION_COOKIE
}

#------------------------------------------------------------------------------
urlencode() {
    # ------------------------------------------------------
    # urlencode function from mrubin
    # https://gist.github.com/mrubin
    #
    # usage: urlencode <string>
    # ------------------------------------------------------
    local length="${#1}"
 
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
 
        case $c in [a-zA-Z0-9.~_-])
            printf "$c" ;;
            *) printf '%%%02X' "'$c"
            esac
    done
}

#------------------------------------------------------------------------------
# main
#------------------------------------------------------------------------------

# calculate the default start and end time
now=$(date '+%s')
past=$(expr ${now} - ${period} )
start_time=$(date -d @${past} '+%Y-%m-%d %H:%M:%S')
end_time=$(date -d @${now}    '+%Y-%m-%d %H:%M:%S')

# parsing options
list_devices=0
id_in_filename=0
file_type="csv"
filename_mode='NORMAL'
OPTIND=1
while getopts "d:De:iLM:n:o:p:s:tTu:xy?h" opt; do
    case "$opt" in
    d)  # date selection: specified day
        start_time="${OPTARG} 00:00:00"
        start_in_seconds_since_epoche=$(date -d "${start_time}" '+%s')
        start_plus_24h=$(expr ${start_in_seconds_since_epoche} + 1 + 86400)
        end_time_text=$(date -d @${start_plus_24h} '+%Y-%m-%d 00:00:00')
        end_time_in_seconds=$(date -d "${end_time_text}" '+%s')
        end_time_minus_one=$(expr ${end_time_in_seconds} - 1 )
        end_time=$(date -d @${end_time_minus_one} '+%Y-%m-%d %H:%M:%S')
        filename_mode='DAY'
	min_file_size=10000
        ;;
    D)  # get device list/current readings, no historical data
        list_devices=1
        ;;
    e)  # date selection: end date/time
        end_time=${OPTARG} 
	min_file_size=140
        ;;
    i)  # use module ID instead of name in outfile name
        if [ "${module_in_filename}" == 'id' ] ; then
            module_in_filename='name'
        else
            module_in_filename='id'
        fi
        ;;
    L)  # date selection: last month
        start_time=$(date -d 'last month' '+%Y-%m-01 00:00:00')
        end_time_text=$(date '+%Y-%m-01 00:00:00')
        end_time_in_seconds=$(date -d "${end_time_text}" '+%s')
        end_time_minus_one=$(expr ${end_time_in_seconds} - 1 )
        end_time=$(date -d @${end_time_minus_one} '+%Y-%m-%d %H:%M:%S')
        filename_mode='MONTH'
	min_file_size=300000
        ;;
    M)  # date selection: specified month
        start_time="${OPTARG}-01 00:00:00"
        start_in_seconds_since_epoche=$(date -d "${start_time}" '+%s')
        start_plus_31_days=$(expr ${start_in_seconds_since_epoche} + 1 + 2678400) # 31 days + 1s after start
        end_time_text=$(date -d @${start_plus_31_days} '+%Y-%m-01 00:00:00')
        end_time_in_seconds=$(date -d "${end_time_text}" '+%s')
        end_time_minus_one=$(expr ${end_time_in_seconds} - 1 )
        end_time=$(date -d @${end_time_minus_one} '+%Y-%m-%d %H:%M:%S')
        filename_mode='MONTH'
	min_file_size=300000
        ;;
    n)  # retrieve data for the last X seconds
        period=${OPTARG}
        past=$(expr ${now} - ${period} )
        start_time=$(date -d @${past} '+%Y-%m-%d %H:%M:%S')
	min_file_size=140
        ;;
    o)  # output directory
        outdirectory=${OPTARG} 
        ;;
    p)  # NetAtmo user credentials: Password
        pass=${OPTARG}
        ;;
    s)    # date selection: start date/time
        start_time=${OPTARG}
	min_file_size=140
        ;;
    t)  # date selection: today
        start_time=$(date '+%Y-%m-%d 00:00:00')
        end_time=$(date -d @${now}    '+%Y-%m-%d %H:%M:%S')
        filename_mode='PARTIALLY_DAY'
	min_file_size=140
        ;;
    T)  # date selection: this month
        start_time=$(date -d 'this month' '+%Y-%m-01 00:00:00')
        end_time=$(date -d @${now}    '+%Y-%m-%d %H:%M:%S')
        filename_mode='PARTIALLY_MONTH'
	min_file_size=140
        ;;
    u)  # NetAtmo user credentials: Username
        user=${OPTARG}
        ;;
    x)  # request excel, not csv
        file_type="xls"
        ;;
    y)  # date selection: yesterday
        end_time=$(date '+%Y-%m-%d 00:00:00')
        end_in_seconds_since_epoche=$(date -d "${end_time}" '+%s')

        end_time_minus_one=$(expr ${end_in_seconds_since_epoche} - 1 )
        end_time=$(date -d @${end_time_minus_one} '+%Y-%m-%d %H:%M:%S')

        end_minus_24_hours=$(expr ${end_in_seconds_since_epoche} - 86400)
        start_time=$(date -d @${end_minus_24_hours} '+%Y-%m-%d 00:00:00')
        filename_mode='DAY'
	min_file_size=10000
        ;;
    h|\?) # help
        usage
        exit 0
        ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = '--' ] && shift

#------------------------------------------------------------------------------
# device list requested
if [ "${list_devices}" == "1" ] ; then
    if hash jq >/dev/null 2>&1 ; then
        listDevices "${user}" "${pass}" | jq '.'
    else
        listDevices "${user}" "${pass}"
    fi
    exit 0
fi

#------------------------------------------------------------------------------
# fetch data (for all configured sensors)
echo "Will fetch data from $start_time until $end_time"

if [ ! -d "${outdirectory}" ]; then
    echo "Output directory [${outdirectory}] does not exist (or is not a directory)"
    exit 1
fi

error_files=''
for sensorline in "${sensors_config[@]}"; do
    OFS=$IFS
    IFS=';'
    read -ra fields <<< "$sensorline"
    IFS=$OFS
    sensor_id=${fields[0]}
    sensor_name=${fields[1]}
    sensors=(${fields[@]:2})
    module_filename_component="${sensor_name}"
    if [ "${module_in_filename}" == "id" ]; then
        module_filename_component="${sensor_id}"
    fi
    for sensor in "${sensors[@]}"; do
        case "${filename_mode}" in
        MONTH)
            month=$(date -d "${start_time}" '+%Y-%m')
            outfilename="${module_filename_component}_${sensor}_${month}.${file_type}"
            ;;
        PARTIALLY_MONTH)
            month=$(date -d "${start_time}" '+%Y-%m')
            outfilename="${module_filename_component}_${sensor}_${month}-(partially).${file_type}"
            ;;
        DAY)
            day=$(date -d "${start_time}" '+%Y-%m-%d')
            outfilename="${module_filename_component}_${sensor}_${day}.${file_type}"
            ;;
        PARTIALLY_DAY)
            day=$(date -d "${start_time}"    '+%Y-%m-%d')
            outfilename="${module_filename_component}_${sensor}_${day}-(partially).${file_type}"
            ;;
        *)
            outfilename="${module_filename_component}_${sensor}_${start_time//[ :]/-}_${end_time//[ :]/-}.${file_type}"
            ;;
        esac
        outfilename="${outdirectory%%+(/)}/${outfilename}" # ${1%%+(/)}
        
        echo
        echo "${sensor_name} - ${sensor} -> ${outfilename}"

        try=0
        while [ "${try}" -lt "${max_download_tries}" ]
        do

	        # download
                getmeasurecsv        \
                    "${user}"        \
                    "${pass}"        \
                    "${master}"      \
                    "${sensor_id}"   \
                    "${sensor}"      \
                    "${start_time}"  \
                    "${end_time}"    \
                    "${file_type}"   \
                    > "${outfilename}"

                # check file size
	        filesize=$(stat -c%s "${outfilename}")
                if [ "${filesize}" -lt "${min_file_size}" ]; then
                        echo "### ### ### Retrieved file too small. Expected ${min_file_size}, got ${filesize} bytes. Retrying. ### ### ###"
                        /bin/rm "${outfilename}"
                        try=$(($try+1))
                else
                        echo "file size ok"
                        break
                fi

        done

        if [ ! -e "${outfilename}" ]; then
                echo "########### Giving up on this file after ${max_download_tries} tries"
                error_files="${error_files}${sensor_id} - ${sensor}\n"
        fi
    done
done

if [ "${error_files}" != '' ]; then
        echo "###############################################################################"
        echo "Errors fetcheíng these files:"
        echo "-------------------------------------------------------------------------------"
        echo -en ${error_files}
        echo "###############################################################################"
else
        echo "###############################################################################"
	echo "All downloads successfully completed"
        echo "###############################################################################"
fi

