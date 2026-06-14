"""
Kubernetes Log Generator
========================
Generates synthetic K8s-structured log records based on the OpenObserve
sample K8s log schema:
https://zinc-public-data.s3.us-west-2.amazonaws.com/zinc-enl/sample-k8s-logs/k8slog_json.json.zip

Writes one JSON record per line to stdout.
Pipe to Fluent Bit or redirect to a file.

Usage:
    # Single generator writing to file
    python3 k8s_gen.py > /tmp/k8s_logs.json

    # Multiple parallel generators (recommended for high throughput)
    for i in $(seq 1 15); do
        python3 k8s_gen.py >> /tmp/k8s_logs.json &
    done

    # Pipe directly into Fluent Bit
    python3 k8s_gen.py | fluent-bit -c fluentbit/fluent-bit.conf
"""

import json
import time
import random
import sys

# Fixed seed for reproducibility
# Both ES and O2 receive identical data distribution across runs
random.seed(42)

# ── Field definitions ────────────────────────────────────────────────────────
# 20 namespaces, 30 containers, 200 hosts, 10 roles
# Higher cardinality than typical demos for realistic compression testing

NAMESPACES = [f"namespace-{i}" for i in range(20)]
NODES = [
    f"ip-10-{random.randint(0,255)}-{random.randint(0,255)}-{random.randint(0,255)}.us-east-2.compute.internal"
    for _ in range(200)
]
CONTAINERS = [f"container-{i}" for i in range(30)]
APPS = CONTAINERS
ROLES = [f"role-{i}" for i in range(10)]
STREAMS = ["stderr", "stdout"]

LOG_TEMPLATES = [
    "provide_credentials; provider=default_chain request_id={}",
    "failed to list *v1.Pod: pods is forbidden token={} user={}",
    "Starting reconciliation loop iteration={} duration={}ms",
    "Scrape failed: context deadline exceeded target={} elapsed={}ms",
    "Successfully synced configmap name={} namespace={}",
    "HTTP request completed method={} path={} status={} duration={}ms",
    "Connection established peer={} port={} protocol={}",
    "Retrying failed request attempt={} backoff={}ms error={}",
    "Cache miss fetching from storage key={} size={}bytes",
    "Compaction completed successfully files={} duration={}ms size={}mb",
    "Authentication failed user={} ip={} reason={}",
    "New pod scheduled node={} pod={} namespace={}",
    "Resource quota exceeded namespace={} resource={} limit={}",
    "Health check passed endpoint={} latency={}ms",
    "Certificate expiring in {}days domain={}",
    "Rate limit exceeded client={} limit={} window={}s",
    "Garbage collection completed freed={}mb duration={}ms",
    "Config reloaded version={} hash={}",
    "Metrics exported endpoint={} count={} duration={}ms",
    "Disk usage warning path={} used={}% threshold={}%",
]


def make_log():
    app = random.choice(APPS)
    role = random.choice(ROLES)
    pod_hash = f"{random.randint(100000, 999999)}"
    pod_id = f"{random.randint(10000, 99999)}"
    template = random.choice(LOG_TEMPLATES)
    placeholders = [
        random.choice([
            str(random.randint(1, 9999)),
            f"val-{random.randint(1, 100)}",
            f"host-{random.randint(1, 200)}",
            f"path-{random.randint(1, 50)}",
        ])
        for _ in range(template.count("{}"))
    ]
    return {
        "_timestamp": int(time.time() * 1_000_000),
        "kubernetes_annotations_kubernetes_io_psp": "eks.privileged",
        "kubernetes_container_image": f"058694856476.dkr.ecr.us-east-2.amazonaws.com/{app}:v0.0.{random.randint(1,50)}",
        "kubernetes_container_name": app,
        "kubernetes_host": random.choice(NODES),
        "kubernetes_labels_app": app,
        "kubernetes_labels_name": f"{app}-{role}",
        "kubernetes_labels_pod_template_hash": pod_hash,
        "kubernetes_labels_role": role,
        "kubernetes_namespace_name": random.choice(NAMESPACES),
        "kubernetes_pod_id": f"pod-{random.randint(1, 1000000)}",
        "kubernetes_pod_name": f"{app}-{role}-{pod_hash}-{pod_id}",
        "log": f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ')}] {template.format(*placeholders)}",
        "stream": random.choice(STREAMS),
    }


BATCH_SIZE = 1000
total = 0
start = time.time()
sys.stderr.write("Starting K8s log generation...\n")

while True:
    for _ in range(BATCH_SIZE):
        print(json.dumps(make_log()), flush=True)
    total += BATCH_SIZE
    if total % 100000 == 0:
        elapsed = time.time() - start
        sys.stderr.write(f"Generated {total:,} logs | {total/elapsed:,.0f} logs/sec\n")
