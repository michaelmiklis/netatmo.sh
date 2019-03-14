#!/bin/bash
 
listDevices() {
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
    API_GETMEASURECSV="https://api.netatmo.com/api/getmeasurecsv"
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
 
#____________________________________________________________________________________________________________________________________
 
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
 
#____________________________________________________________________________________________________________________________________
 
listDevices "user@email.com" "mySecretPassword"