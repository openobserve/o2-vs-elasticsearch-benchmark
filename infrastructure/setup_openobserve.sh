#!/bin/bash
# ============================================================
# OpenObserve Setup Script
# Run on the OpenObserve instance (r7gd.2xlarge ARM)
# ============================================================
set -e

echo "=== Mounting NVMe ==="
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /mnt/nvme
sudo mount /dev/nvme1n1 /mnt/nvme
sudo mkdir -p /mnt/nvme/openobserve
sudo chown -R root:root /mnt/nvme/openobserve

echo "=== Downloading OpenObserve Enterprise v0.90.3 (ARM64) ==="
curl -L -o /mnt/nvme/oo.tar.gz \
  https://downloads.openobserve.ai/releases/o2-enterprise/v0.90.3/openobserve-ee-v0.90.3-linux-arm64.tar.gz
tar -xzf /mnt/nvme/oo.tar.gz -C /tmp/
sudo cp /tmp/openobserve /usr/local/bin/openobserve
rm -f /mnt/nvme/oo.tar.gz /tmp/openobserve

echo "=== Configuring OpenObserve ==="
sudo tee /etc/openobserve.env << 'OOEOF'
ZO_ROOT_USER_EMAIL="admin@bench.com"
ZO_ROOT_USER_PASSWORD="Bench1234!"
ZO_DATA_DIR="/mnt/nvme/openobserve"
ZO_COMPACT_MAX_FILE_SIZE=5120
OOEOF

sudo tee /usr/lib/systemd/system/openobserve.service << 'SVCEOF'
[Unit]
Description=The OpenObserve server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
LimitNOFILE=65535
EnvironmentFile=/etc/openobserve.env
ExecStart=/usr/local/bin/openobserve
ExecStop=/bin/kill -s QUIT $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
SVCEOF

echo "=== Starting OpenObserve ==="
sudo systemctl daemon-reload
sudo systemctl enable openobserve
sudo systemctl start openobserve
sleep 5
curl http://localhost:5080/healthz

echo ""
echo "=== OpenObserve setup complete! ==="
echo "UI available at http://<O2_IP>:5080"
echo "Login: admin@bench.com / Bench1234!"
