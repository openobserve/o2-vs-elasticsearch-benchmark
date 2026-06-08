#!/bin/bash
# ============================================================
# Fluent Bit Setup Script
# Run on the generator instance (c5.xlarge x86)
# ============================================================
set -e

echo "=== Installing Fluent Bit ==="
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh

echo "=== Installing Python dependencies ==="
sudo apt update -y
sudo apt install -y python3-pip
pip3 install requests --break-system-packages

echo "=== Fluent Bit installed ==="
fluent-bit --version

echo ""
echo "Next steps:"
echo "1. Edit fluentbit/fluent-bit.conf — replace <ES_IP> and <O2_IP>"
echo "2. Start generator: python3 generator/k8s_gen.py > /tmp/k8s_logs.json &"
echo "3. Start Fluent Bit: fluent-bit -c fluentbit/fluent-bit.conf"
