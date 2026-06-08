# Benchmark Queries Reference

Result limit: **100 records** for filter/FTS queries, **top 10** for aggregations.


## Query Table

| # | Query Name | Type | Elasticsearch Query | OpenObserve SQL |
|---|---|---|---|---|
| Q01 | Filter-Namespace | Simple Filter | `{"term": {"kubernetes_namespace_name.keyword": "namespace-1"}}` | `SELECT * FROM logs_bench WHERE kubernetes_namespace_name='namespace-1' LIMIT 100` |
| Q02 | Filter-Container | Simple Filter | `{"term": {"kubernetes_container_name.keyword": "container-1"}}` | `SELECT * FROM logs_bench WHERE kubernetes_container_name='container-1' LIMIT 100` |
| Q03 | Filter-Host | Simple Filter | `{"term": {"kubernetes_host.keyword": "ip-10-2-10-10.us-east-2.compute.internal"}}` | `SELECT * FROM logs_bench WHERE kubernetes_host='ip-10-2-10-10.us-east-2.compute.internal' LIMIT 100` |
| Q04 | Filter-Stream | Simple Filter | `{"term": {"stream.keyword": "stderr"}}` | `SELECT * FROM logs_bench WHERE stream='stderr' LIMIT 100` |
| Q05 | Filter-Role | Simple Filter | `{"term": {"kubernetes_labels_role.keyword": "role-1"}}` | `SELECT * FROM logs_bench WHERE kubernetes_labels_role='role-1' LIMIT 100` |
| Q06 | FTS-Failed | Full Text Search | `{"wildcard": {"log.keyword": {"value": "*failed*"}}}` | `SELECT * FROM logs_bench WHERE match_all('failed') LIMIT 100` |
| Q07 | FTS-Connection | Full Text Search | `{"wildcard": {"log.keyword": {"value": "*Connection*"}}}` | `SELECT * FROM logs_bench WHERE match_all('Connection') LIMIT 100` |
| Q08 | FTS-Scrape | Full Text Search | `{"wildcard": {"log.keyword": {"value": "*Scrape*"}}}` | `SELECT * FROM logs_bench WHERE match_all('Scrape') LIMIT 100` |
| Q09 | Agg-Namespace | Aggregation | `{"aggs": {"by_ns": {"terms": {"field": "kubernetes_namespace_name.keyword", "size": 10}}}}` | `SELECT kubernetes_namespace_name, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_namespace_name ORDER BY cnt DESC LIMIT 10` |
| Q10 | Agg-Container | Aggregation | `{"aggs": {"by_container": {"terms": {"field": "kubernetes_container_name.keyword", "size": 10}}}}` | `SELECT kubernetes_container_name, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_container_name ORDER BY cnt DESC LIMIT 10` |
| Q11 | Agg-Host | Aggregation | `{"aggs": {"by_host": {"terms": {"field": "kubernetes_host.keyword", "size": 10}}}}` | `SELECT kubernetes_host, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_host ORDER BY cnt DESC LIMIT 10` |
| Q12 | Filter+Agg | Combined | `{"query": {"term": {"kubernetes_namespace_name.keyword": "namespace-1"}}, "aggs": {"by_container": {"terms": {"field": "kubernetes_container_name.keyword", "size": 10}}}}` | `SELECT kubernetes_container_name, COUNT(*) as cnt FROM logs_bench WHERE kubernetes_namespace_name='namespace-1' GROUP BY kubernetes_container_name ORDER BY cnt DESC LIMIT 10` |
| Q13 | FTS+Filter | Combined | `{"query": {"bool": {"must": [{"wildcard": {"log.keyword": {"value": "*failed*"}}}, {"term": {"kubernetes_namespace_name.keyword": "namespace-1"}}]}}}` | `SELECT * FROM logs_bench WHERE match_all('failed') AND kubernetes_namespace_name='namespace-1' LIMIT 100` |
| Q14 | Count-All | Heavy | `{"size": 0, "track_total_hits": true, "query": {"match_all": {}}}` | `SELECT COUNT(*) as total FROM logs_bench` |
| Q15 | Agg-Role | Heavy | `{"aggs": {"by_role": {"terms": {"field": "kubernetes_labels_role.keyword", "size": 10}}}}` | `SELECT kubernetes_labels_role, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_labels_role ORDER BY cnt DESC LIMIT 10` |


## Full ES Query Structure (with time range filter)

Every ES query includes a time range filter applied via `bool` query:

```json
{
  "size": 100,
  "query": {
    "bool": {
      "must": [<query>],
      "filter": {
        "range": {
          "_timestamp": {
            "gte": <>,
            "lte": <>
          }
        }
      }
    }
  }
}
```

For aggregations (`size: 0`), the `must` clause is omitted and only the `filter` is applied.
For `Q14-Count-All`, `track_total_hits: true` is added to get accurate counts beyond the default 10,000 cap.


## Full O2 Query Structure (with time range)

Every O2 query includes `start_time` and `end_time` in microseconds, and `use_cache=true` as a URL parameter:

```bash
POST /api/default/_search?use_cache=true
{
  "query": {
    "sql": "<SQL query>",
    "start_time": <>,
    "end_time": <>,
    "from": 0,
    "size": 100
  }
}
```

## Query Type Descriptions

| Type | Description | ES Mechanism | O2 Mechanism |
|---|---|---|---|
| **Simple Filter** | Exact match on a single field | Inverted index term lookup | Columnar filter on indexed field |
| **Full Text Search** | Substring search across log messages | Wildcard on `log.keyword` | `match_all()` with Tantivy inverted index |
| **Aggregation** | GROUP BY with COUNT, top 10 results | Terms aggregation | SQL GROUP BY on columnar data |
| **Combined** | Filter or FTS + aggregation together | Bool query + terms agg | SQL WHERE + GROUP BY |
| **Heavy** | Full dataset scan / count | `match_all` + `track_total_hits` | `SELECT COUNT(*)` |


## Fairness Notes

- **Same time range** applied to both systems (microseconds)
- **Same result limit** (100 for filter/FTS, top 10 for aggregations)
- **FTS equivalence**: ES `wildcard *term*` ≈ O2 `match_all('term')` — both do substring/token search
- **Aggregation equivalence**: ES `terms size:10` ≈ O2 `GROUP BY ... ORDER BY cnt DESC LIMIT 10`
- **Count equivalence**: ES `track_total_hits: true` ≈ O2 `SELECT COUNT(*)`
