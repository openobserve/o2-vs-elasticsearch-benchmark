# log-analytics-benchmark

A reproducible benchmark comparing **OpenObserve** and **Elasticsearch** on storage efficiency, ingestion speed, and query performance using synthetic Kubernetes-structured log data forwarded through Fluent Bit.

## Architecture

```
Python generator (k8s_gen.py)
        ↓ writes to stdout / file
Fluent Bit
        ↓ dual output
    ┌───────────────────┐
    │                   │
Elasticsearch       OpenObserve
```

## Results Summary

| Metric | Elasticsearch | OpenObserve | Advantage |
|---|---|---|---|
| Compression ratio | 3x | 28.5x | O2 9.5x better |
| Stored size (1TB raw) | 243 GB | 35.42 GB | O2 6.9x smaller |
| RAM (peak ingestion) | 19 GB | 1.9 GB | O2 10x less |
| CPU (sustained) | 96% | 15% | O2 6x less |
| Ingestion speed | ~71K docs/sec | ~95K docs/sec | O2 33% faster |
| Query benchmark | wins 1/15 | wins 14/15 | O2 dominates |

## Infrastructure

| Machine | Role | Instance |
|---|---|---|
| bench-generator | Log generator + Fluent Bit | c5.xlarge (x86) |
| bench-elasticsearch | Elasticsearch 8.19 | m7gd.4xlarge (16 vCPU, 128GB, 884GB NVMe) |
| bench-openobserve | OpenObserve v0.90.3 EE | r7gd.2xlarge (8 vCPU, 64GB, 474GB NVMe) |

## Prerequisites

- 3 AWS EC2 instances (see above)
- Python 3.8+
- Fluent Bit v3.x
- `pip3 install requests`

## Quick Start

### 1. Set up Elasticsearch
```bash
bash infrastructure/setup_elasticsearch.sh
```

### 2. Set up OpenObserve
```bash
bash infrastructure/setup_openobserve.sh
```

### 3. Start log generator
```bash
# Edit generator/k8s_gen.py — set OUTPUT_FILE path
python3 generator/k8s_gen.py > /tmp/k8s_logs.json
```

### 4. Start Fluent Bit
```bash
# Edit fluentbit/fluent-bit.conf — set ES_IP and O2_IP
fluent-bit -c fluentbit/fluent-bit.conf
```

### 5. Run query benchmark
```bash
# Edit benchmarks/query_benchmark.sh — set ES and O2 IPs + timestamps
bash benchmarks/query_benchmark.sh both   # run both
bash benchmarks/query_benchmark.sh O2     # O2 only
bash benchmarks/query_benchmark.sh es     # ES only
```

## Notes
- Generator uses `random.seed(42)` for reproducible identical data
- O2 queries use `?use_cache=true` for production-realistic caching
- Same time range applied to both systems for fair comparison
- See `benchmarks/QUERIES.md` for full query reference
