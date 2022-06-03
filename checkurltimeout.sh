#! /bin/bash
# Detects the response time of the specified Url, Support set the threshold of response time
# author: isme@lyinlong.me

# The request url
url=""

# The critical time for the request to respond to an exception
claim=10

# Intervals
time=5

start(){

    commond="curl -o /dev/null -s -w %{time_total} ${url}"

    while true ;
      do
        currentTime=$(date +%Y-%m-%d\ %H:%M:%S)
        timeout=`${commond}`

        echo "------------------------------------------------------------------"
        echo ${currentTime}

        if  [ `echo "$timeout > $claim" | bc` -eq 1 ]; 
        then
            echo -e "\033[31m   INFO : >> 请求总耗时为：${timeout} \033[0m"
        else
            echo -e "\033[32m   INFO : >> 请求总耗时为：${timeout} \033[0m"
        fi

        echo "------------------------------------------------------------------"
        echo ""
        sleep $time 

    done

}

help(){
cat << EFO
Check the url response time 
-c : The critical time for the request to respond to an exception
-u : Detected request 
-t : Interval for each test
author: isme@lyinlong.me
EFO
}

clear

while getopts "c:u:t:h" opt
do
    case $opt in
        t ) 
            time=$OPTARG;;
        u )
            url=$OPTARG;;
        c )
            claim=$OPTARG;;
        h )
            help
            exit
    esac
done

if [ -z "$url" ]; then
    help
    echo -e "\033[31mError : The requested url is wrong  \033[0m"
    exit
fi

echo "params "
echo "    URL: ${url} "
echo "    critical time: ${claim}s"
echo "    Interval for each test: ${time} "
echo ""

start
