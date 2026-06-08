# Benchmarks

## Files

- `query_benchmark.sh` — Main query benchmark script (cold + warm cache)
- `QUERIES.md` — Full reference of all 15 queries with ES JSON and O2 SQL

## Usage

```bash
# Edit query_benchmark.sh first — set ES and O2 IPs and timestamps

# Run both systems
bash query_benchmark.sh

# Run O2 only
bash query_benchmark.sh O2

# Run ES only
bash query_benchmark.sh es
```

## Before Running

Clear caches on both machines:

**Elasticsearch:**
```bash
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
curl -X POST "http://localhost:9200/logs_bench/_cache/clear"
```

**OpenObserve:**
```bash
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

## Output

Results saved to `/tmp/query_bench_<timestamp>_<mode>.csv` with columns:
`system, query_name, query_type, cache, response_time_ms, took_ms, status`
