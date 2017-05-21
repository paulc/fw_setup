#!/bin/sh

## Configure firewall - assumes basic installation completed (external network up)
##
## re0 - external
## re1 - internal

umask 022 || exit 1

echo "[+] motd"
ex -Fs motd <<'EOM' || exit 1
2,$d
wq
EOM

echo "[+] doas.conf"
cat >/etc/doas.conf <<EOM || exit 1
permit :wheel
permit nopass keepenv root as root
EOM

echo "[+] rc.local"
cat >/etc/rc.local <<EOM || exit 1
echo -n "Setting date/time: "
rdate pool.ntp.org
EOM

echo "[+] sysctl.conf"
echo "net.inet.ip.forwarding=1" >> /etc/sysctl.conf || exit 1

echo "[+] hostname.xxx"
echo "192.168.1.1/24" > /etc/hostname.re1 || exit 1
echo "192.168.2.1/24 parent re1 vnetid 2" > /etc/hostname.vlan2 || exit 1
echo "192.168.3.1/24 parent re1 vnetid 3" > /etc/hostname.vlan3 || exit 1
echo "192.168.4.1/24 parent re1 vnetid 4" > /etc/hostname.vlan4 || exit 1
echo "192.168.5.1/24 parent re1 vnetid 5" > /etc/hostname.vlan5 || exit 1

chmod 640 /etc/hostname.* || exit 1

echo "[+] dhclient.conf"
cat >>/etc/dhclient.conf <<EOM || exit 1
interface "re0" {
    prepend domain-name-servers 127.0.0.1;
}
EOM

echo "[+] packages"
for p in pstree freedt dnscrypt-proxy curl tor torsocks
do
    pkg_add $p || exit 1
done

echo "[+] rc.local.conf"

rcctl disable sndiod || exit 1

rcctl enable sshd || exit 1
rcctl set sshd flags "-o PermitRootLogin=prohibit-password -o PasswordAuthentication=no" || exit 1

rcctl enable dhcpd || exit 1
rcctl set dhcpd flags "re1 vlan0 vlan1 vlan2" || exit 1

rcctl enable nsd || exit 1
rcctl enable unbound || exit 1

rcctl enable dnscrypt-proxy || exit 1
rcctl set dnscrypt-proxy flags "-d -a 127.0.0.1:8053 -R cisco" || exit 1

rcctl enable svscan || exit 1
rcctl enable tor || exit 1

echo "[+] pf"
install -o root -g wheel files/pf/pf.conf /etc || exit 1

echo "[+] unbound"
install -o root -g wheel files/unbound/etc/unbound.conf /var/unbound/etc/ || exit 1

echo "[+] nsd"
install -o root -g _nsd files/nsd/etc/nsd.conf /var/nsd/etc/ || exit 1
install -o root -g _nsd files/nsd/zones/master/* /var/nsd/zones/master || exit 1

echo "[+] tor"
install -o root -g wheel files/tor/torrc /etc/tor/ || exit 1

echo "[+] freedt"
mkdir /var/svc.d 
/usr/local/bin/mkservice root root /var/svc.d/dhcp-monitor || exit 1
install -o root -g wheel -m 755 files/svc.d/dhcp-monitor/dhcp-monitor.sh /var/svc.d/dhcp-monitor/ || exit 1
install -o root -g wheel -m 755 files/svc.d/dhcp-monitor/run /var/svc.d/dhcp-monitor/ || exit 1
install -o root -g wheel -m 755 files/svc.d/dhcp-monitor/log/run /var/svc.d/dhcp-monitor/log/ || exit 1
install -o root -g wheel files/parse-leases.awk files/parse-reverse.awk /var/svc.d/dhcp-monitor/ || exit 1

ln -s /var/svc.d/dhcp-monitor /service || exit 1

echo "[+] Start services"
sh /etc/netstart 
pfctl -f /etc/pf.conf
rcctl restart sshd
rcctl start dhcpd
rcctl start unbound
rcctl start nsd
rcctl start dnscrypt-proxy
rcctl start tor
rcctl start svscan

