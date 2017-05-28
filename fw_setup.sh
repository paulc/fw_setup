#!/bin/sh

## Configure firewall - assumes basic installation completed (external network up)
##
## re0 - external
## re1 - internal

umask 022 || exit 1

echo "[+] motd"
ex -Fs /etc/motd <<'EOM' || exit 1
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
pkg_add pstree freedt dnscrypt-proxy curl tor torsocks || exit 1

echo "[+] rc.local.conf"

rcctl disable sndiod || exit 1

rcctl enable sshd || exit 1
rcctl set sshd flags "-o PermitRootLogin=prohibit-password -o PasswordAuthentication=no" || exit 1

rcctl enable dhcpd || exit 1
install -o root -g wheel files/dhcpd/dhcpd.conf /etc || exit 1
rcctl set dhcpd flags "re1 vlan2 vlan3 vlan4 vlan5" || exit 1

rcctl enable nsd || exit 1
rcctl enable unbound || exit 1

rcctl enable dnscrypt_proxy || exit 1
rcctl set dnscrypt_proxy flags "-d -a 127.0.0.1:8053 -R cisco" || exit 1

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
mkdir /var/svc.d || exit 1
mkdir /service || exit 1

/usr/local/bin/mkservice root root /var/svc.d/dhcp-monitor || exit 1
install -o root -g wheel -m 755 files/svc.d/dhcp-monitor/dhcp-monitor.sh /var/svc.d/dhcp-monitor/ || exit 1
install -o root -g wheel -m 755 files/svc.d/dhcp-monitor/run /var/svc.d/dhcp-monitor/ || exit 1
install -o root -g wheel -m 755 files/svc.d/dhcp-monitor/log/run /var/svc.d/dhcp-monitor/log/ || exit 1
install -o root -g wheel files/svc.d/dhcp-monitor/*.awk /var/svc.d/dhcp-monitor/ || exit 1

cat >>/etc/newsyslog.conf <<'EOM'
/var/log/dhcp-monitor.log               644  3     250  *     Z "svc -h /service/dhcp-monitor/log"
EOM

mkdir /var/svc.d/ddns
install -o root -g wheel -m 755 files/svc.d/ddns/ddns.sh /var/svc.d/ddns.sh || exit 1
install -o root -g wheel -m 755 files/svc.d/ddns/run /var/svc.d/run 1

ln -s /var/svc.d/dhcp-monitor /service || exit 1
ln -s /var/svc.d/ddns /service || exit 1

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

