#!/bin/bash

# Variables
WIREGUARD_PORT=
SSH_PORT=
SSH_PUBLIC_KEY="" # cat ~/.ssh/id_rsa.pub
PIHOLE_DNS="127.0.0.1#5335"
ADMIN_USER="gleb"
PIHOLE_ADLISTS=(
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://adaway.org/hosts.txt"
  "https://v.firebog.net/hosts/Easyprivacy.txt"
  "https://v.firebog.net/hosts/Prigent-Ads.txt"
  "https://v.firebog.net/hosts/AdguardDNS.txt"
)

# Update and install dependencies
apt update && apt upgrade -y
apt install -y curl wget ufw unbound wireguard sudo

################################################
############## WireGuard #######################
################################################
curl -o ./wireguard-install.sh https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh
chmod +x ./wireguard-install.sh
./wireguard-install.sh auto

# After installation client key would be available under two options:
# 1) QR code
# 2) /root/wg0-client-{client custom name}.conf 
# scp -P $SSH_PORT root@$IP_ADDRESS:/root/wg0-client.conf . # alternative is export via QR code

################################################
############## PI-HOLE #########################
################################################

sudo apt-get install --no-install-recommends curl git iproute2 procps lsof net-tools
curl -sSL https://install.pi-hole.net | bash

pihole logging off

# Go to admin interface and set DNS to 127.0.0.1#5335

pihole restartdns

# Add ad-blocking lists to Pi-hole or add them via the web interface
for adlist in "${PIHOLE_ADLISTS[@]}"; do
  pihole -a -l "$adlist"
done

# Update gravity (apply new blocklists)
pihole -g

# Configure Unbound for Pi-hole
cat <<EOF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    access-control: 127.0.0.0/8 allow
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    num-threads: 4
    msg-cache-size: 128m
    rrset-cache-size: 256m
    hide-identity: yes
    hide-version: yes
    root-hints: "/var/lib/unbound/root.hints"
EOF

# Download root DNS server list
curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
systemctl restart unbound

curl -O https://raw.githubusercontent.com/Nyr/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
./openvpn-install.sh
scp -P $SSH_PORT root@$VPS_IP:/root/$VPN_CLIENT_NAME.ovpn .
# TODO how to route openvpn through pi-hole?

################################################
############## Test if evertyhing works ########
###############################################
# 1) https://browserleaks.com
# 2) https://ipleak.net
# 3) https://dnsleaktest.com
# 4) systemctl status unbound
# 5) dig @127.0.0.1 -p 5335 google.com
# it should show:
# A NOERROR status
# An ANSWER SECTION with IP addresses
# A Query time (e.g., 10 msec)
# SERVER: 127.0.0.1#5335
# 6) dig @127.0.0.1 -p 5335 dnssec-failed.org +dnssec
# it should show:
# A SERVFAIL status

# debug:
# login into DigitalOcean console and fix config manually

################################################
############## SETUP NEW USER ##################
################################################

# Create a new sudo user
useradd -m -s /bin/bash -G sudo $ADMIN_USER
sudo passwd $ADMIN_USER

# add my public ssh key
mkdir -p /home/$ADMIN_USER/.ssh
chmod 700 /home/$ADMIN_USER/.ssh
echo $SSH_PUBLIC_KEY >> /home/$ADMIN_USER/.ssh/authorized_keys
chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh

################################################
############## SETUP SSH SERVER ################
################################################

sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

################################################
############## SETUP FIREWALL ##################
################################################

apt install -y ufw
ufw allow $SSH_PORT/tcp
ufw allow $SSH_PORT/udp
ufw allow $WIREGUARD_PORT/udp
ufw enable
ufw reload

################################################
############## RELOAD SSH SERVER ###############
################################################

# For changes to take effect, run:
systemctl daemon-reload
systemctl restart ssh
systemctl restart ssh.socket