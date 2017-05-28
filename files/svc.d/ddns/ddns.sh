#!/bin/sh

NS=a.ns.joker.com
HOSTNAME=home.pchak.net
USERNAME=1d0f454de8bfeaae
PASSWORD=9865743b5c54a8da

while :
do
    
    DDNS=$(dig @$NS $HOSTNAME +short)
    IP=$(curl -s http://ifconfig.co) 
    
    if [ $IP != $DDNS ]
    then
        curl -s "http://svc.joker.com/nic/update?username=${USERNAME}&password=${PASSWORD}&hostname=${HOSTNAME}" | \
    		logger -t ddns -p alert
    else
        logger -t ddns -p alert No change: $IP
    fi 

    sleep 600

done
