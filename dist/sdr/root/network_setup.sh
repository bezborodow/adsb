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
LinkLocalAddressing=no
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd

cat > /usr/local/bin/fix_eth0_route.sh <<EOF
#!/bin/sh
# Force default route via host.
ip route del default dev eth0 2>/dev/null
ip route add default via 192.168.2.1
EOF
chmod +x /usr/local/bin/fix_eth0_route.sh

cat > /etc/systemd/system/fix-eth0-route.service <<EOF
[Unit]
Description=Force eth0 default route via host
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix_eth0_route.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable fix-eth0-route.service

echo "eth0 configured with static IP 192.168.2.2/24 via systemd-networkd."

echo "nameserver 8.8.8.8" | tee /etc/resolv.conf
ip addr show
