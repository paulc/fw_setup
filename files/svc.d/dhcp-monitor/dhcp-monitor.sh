#!/bin/sh

SVC="$(basename $(pwd))"
LEASES="/var/db/dhcpd.leases"
DOMAIN="pchak.net."
LOCALZONE="/var/nsd/zones/master/pchak.net"
DHCPZONE="/var/nsd/zones/master/pchak.net-dhcp"
REVERSE="/var/nsd/zones/master/*.arpa"

log() {
    echo "$SVC: $@"
}

log monitoring $LEASES

mtime=0

while :
do 
    _mtime=$(stat -f %m $LEASES)
    if [ $_mtime -gt $mtime ]
    then
        log $LEASES updated
        mtime=$_mtime

        log updating domain $DOMAIN
        awk -f parse-leases.awk $LEASES | sort +3 > $DHCPZONE

        for rev in $REVERSE
        do
            log updating reverse domain $rev
            awk -v Z=$DHCPZONE -v D=$DOMAIN -v R=$rev -f parse-reverse.awk > \
                "${rev}-dhcp"
            touch $rev
        done

        log reloading nsd
        touch $LOCALZONE
        nsd-control reload
        log flushing unbound
        unbound-control flush_zone $DOMAIN
        for rev in $REVERSE
        do
            unbound-control flush_zone $(basename $rev)
        done
    fi
    sleep 10
done
