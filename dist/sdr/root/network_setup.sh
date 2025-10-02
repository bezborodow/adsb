#!/bin/sh
ip addr add 192.168.2.2/24 dev eth0
ip link set eth0 up
ip addr show eth0
ip route add default via 192.168.2.1

cat > /etc/systemd/network/10-eth0.network <<EOF
[Match]
Name=eth0

[Network]
Address=192.168.2.2/24
Gateway=192.168.2.1
DNS=8.8.8.8
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd
echo "eth0 configured with static IP 192.168.2.2/24 via systemd-networkd."

echo "nameserver 8.8.8.8" | tee /etc/resolv.conf
ip addr show
