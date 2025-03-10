#!/bin/bash

# filepath: /Users/gleb/code/personal/setup_vpn_pihole_unbound.sh

# Variables
WIREGUARD_PORT=51820
SSH_PORT=43764
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

# Create a new sudo user
useradd -m -s /bin/bash -G sudo $ADMIN_USER

# sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
systemctl restart ssh

# Install and configure WireGuard
curl -o /root/wireguard-install.sh https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh
chmod +x /root/wireguard-install.sh
/root/wireguard-install.sh auto

# Extract WireGuard keys
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/publickey)
wg genkey | tee /root/client_privatekey | wg pubkey > /root/client_publickey
CLIENT_PRIVATE_KEY=$(cat /root/client_privatekey)
CLIENT_PUBLIC_KEY=$(cat /root/client_publickey)

# Generate WireGuard Client Configuration
cat <<EOF > /root/wg0-client.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.66.66.2/24
DNS = 10.66.66.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $(hostname -I | awk '{print $1}'):$WIREGUARD_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Install Pi-hole
curl -sSL https://install.pi-hole.net | bash

# Disable all Pi-hole logging
pihole logging off

# Set Pi-hole upstream DNS to Unbound
sed -i "s/^PIHOLE_DNS_1=.*/PIHOLE_DNS_1=$PIHOLE_DNS/" /etc/pihole/setupVars.conf
pihole restartdns

# Add ad-blocking lists to Pi-hole
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

# Firewall settings
ufw enable
ufw allow $SSH_PORT/tcp
ufw allow $WIREGUARD_PORT/udp
ufw reload