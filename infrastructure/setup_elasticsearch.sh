#!/bin/bash
# ============================================================
# Elasticsearch Setup Script
# Run on the Elasticsearch instance (m7gd.4xlarge ARM)
# ============================================================
set -e

echo "=== Mounting NVMe ==="
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /mnt/nvme
sudo mount /dev/nvme1n1 /mnt/nvme
sudo chown ubuntu:ubuntu /mnt/nvme

echo "=== Installing Elasticsearch ==="
sudo apt update -y
sudo apt install -y openjdk-17-jdk
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
  sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update && sudo apt install -y elasticsearch

echo "=== Configuring Elasticsearch ==="
sudo tee /etc/elasticsearch/elasticsearch.yml << 'ESEOF'
cluster.name: bench
node.name: bench-node
network.host: 0.0.0.0
discovery.type: single-node
xpack.security.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.security.http.ssl.enabled: false
path.data: /mnt/nvme/elasticsearch
ESEOF

sudo tee /etc/elasticsearch/jvm.options.d/heap.options << 'JVMEOF'
-Xms16g
-Xmx16g
JVMEOF

sudo mkdir -p /mnt/nvme/elasticsearch
sudo chown -R elasticsearch:elasticsearch /mnt/nvme/elasticsearch
sudo mkdir -p /usr/share/elasticsearch/logs
sudo chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/logs

echo "=== Starting Elasticsearch ==="
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
sleep 20
curl http://localhost:9200

echo "=== Raising disk watermarks ==="
curl -X PUT "http://localhost:9200/_cluster/settings" \
  -H "Content-Type: application/json" \
  -d '{
    "persistent": {
      "cluster.routing.allocation.disk.watermark.low": "95%",
      "cluster.routing.allocation.disk.watermark.high": "97%",
      "cluster.routing.allocation.disk.watermark.flood_stage": "99%"
    }
  }'

echo "=== Creating index ==="
curl -X PUT "http://localhost:9200/logs_bench" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.mapping.ignore_malformed": true
    }
  }'

curl http://localhost:9200/_cat/indices?v
echo ""
echo "=== Elasticsearch setup complete! ==="
