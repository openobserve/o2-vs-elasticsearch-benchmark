#!/bin/bash
# Usage:
#   bash query_benchmark.sh        -> run both ES and O2
#   bash query_benchmark.sh O2     -> run O2 only
#   bash query_benchmark.sh es     -> run ES only

MODE=${1:-both}

ES="http://<ES_IP>:9200"
O2="http://<O2_IP>:5080"
O2_AUTH="admin@bench.com:Bench1234!"
RESULTS="/tmp/query_bench_$(date +%Y%m%d_%H%M%S)_${MODE}.csv"

START_TIME=1780324592322527
END_TIME=1780380168673995

echo "system,query_name,query_type,cache,response_time_ms,took_ms,status" > $RESULTS

run_es() {
  local name=$1 type=$2 cache=$3 payload=$4
  [ "$MODE" = "O2" ] && return
  START=$(python3 -c "import time; print(int(time.time()*1000))")
  RESPONSE=$(curl -s --max-time 30 -X POST "$ES/logs_bench/_search" \
    -H "Content-Type: application/json" -d "$payload")
  END=$(python3 -c "import time; print(int(time.time()*1000))")
  RT=$(( END - START ))
  ERROR=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('type',''))" 2>/dev/null)
  if [ ! -z "$ERROR" ]; then
    echo "ES | $name | $cache | ${RT}ms | ERROR: $ERROR"
    echo "Elasticsearch,$name,$type,$cache,$RT,ERROR,ERROR" >> $RESULTS
    return
  fi
  TOOK=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('took','N/A'))" 2>/dev/null)
  echo "ES | $name | $cache | ${RT}ms | ${TOOK}ms | OK"
  echo "Elasticsearch,$name,$type,$cache,$RT,$TOOK,OK" >> $RESULTS
}

run_o2() {
  local name=$1 type=$2 cache=$3 sql=$4
  [ "$MODE" = "es" ] && return
  PAYLOAD="{\"query\":{\"sql\":\"$sql\",\"start_time\":$START_TIME,\"end_time\":$END_TIME,\"from\":0,\"size\":100}}"
  START=$(python3 -c "import time; print(int(time.time()*1000))")
  RESPONSE=$(curl -s --max-time 30 -X POST "$O2/api/default/_search" \
    -H "Content-Type: application/json" -u "$O2_AUTH" -d "$PAYLOAD")
  END=$(python3 -c "import time; print(int(time.time()*1000))")
  RT=$(( END - START ))
  ERROR=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null)
  if [ ! -z "$ERROR" ]; then
    echo "O2 | $name | $cache | ${RT}ms | ERROR: $ERROR"
    echo "OpenObserve,$name,$type,$cache,$RT,ERROR,ERROR" >> $RESULTS
    return
  fi
  TOOK=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('took','N/A'))" 2>/dev/null)
  echo "O2 | $name | $cache | ${RT}ms | ${TOOK}ms | OK"
  echo "OpenObserve,$name,$type,$cache,$RT,$TOOK,OK" >> $RESULTS
}

TIME_FILTER="\"filter\":{\"range\":{\"_timestamp\":{\"gte\":$START_TIME,\"lte\":$END_TIME}}}"

es_q() {
  local name=$1 type=$2 cache=$3 query=$4
  local payload="{\"size\":100,\"query\":{\"bool\":{\"must\":[$query],$TIME_FILTER}}}"
  run_es "$name" "$type" "$cache" "$payload"
}

es_agg() {
  local name=$1 type=$2 cache=$3 agg=$4
  local payload="{\"size\":0,\"query\":{\"bool\":{$TIME_FILTER}},$agg}"
  run_es "$name" "$type" "$cache" "$payload"
}

es_agg_filter() {
  local name=$1 type=$2 cache=$3 filter=$4 agg=$5
  local payload="{\"size\":0,\"query\":{\"bool\":{\"must\":[$filter],$TIME_FILTER}},$agg}"
  run_es "$name" "$type" "$cache" "$payload"
}

es_count() {
  local name=$1 type=$2 cache=$3
  local payload="{\"size\":0,\"track_total_hits\":true,\"query\":{\"bool\":{$TIME_FILTER}}}"
  run_es "$name" "$type" "$cache" "$payload"
}

run_queries() {
  local CACHE=$1

  # Simple Filters
  es_q "Q01-Filter-Namespace" "Simple Filter" "$CACHE" '{"term":{"kubernetes_namespace_name.keyword":"monitoring"}}'
  run_o2 "Q01-Filter-Namespace" "Simple Filter" "$CACHE" "SELECT * FROM logs_bench WHERE kubernetes_namespace_name='monitoring' LIMIT 100"

  es_q "Q02-Filter-Container" "Simple Filter" "$CACHE" '{"term":{"kubernetes_container_name.keyword":"prometheus"}}'
  run_o2 "Q02-Filter-Container" "Simple Filter" "$CACHE" "SELECT * FROM logs_bench WHERE kubernetes_container_name='prometheus' LIMIT 100"

  es_q "Q03-Filter-Host" "Simple Filter" "$CACHE" '{"term":{"kubernetes_host.keyword":"ip-10-2-10-10.us-east-2.compute.internal"}}'
  run_o2 "Q03-Filter-Host" "Simple Filter" "$CACHE" "SELECT * FROM logs_bench WHERE kubernetes_host='ip-10-2-10-10.us-east-2.compute.internal' LIMIT 100"

  es_q "Q04-Filter-Stream" "Simple Filter" "$CACHE" '{"term":{"stream.keyword":"stderr"}}'
  run_o2 "Q04-Filter-Stream" "Simple Filter" "$CACHE" "SELECT * FROM logs_bench WHERE stream='stderr' LIMIT 100"

  es_q "Q05-Filter-Role" "Simple Filter" "$CACHE" '{"term":{"kubernetes_labels_role.keyword":"querier"}}'
  run_o2 "Q05-Filter-Role" "Simple Filter" "$CACHE" "SELECT * FROM logs_bench WHERE kubernetes_labels_role='querier' LIMIT 100"

  # Full Text Search
  es_q "Q06-FTS-Failed" "Full Text Search" "$CACHE" '{"wildcard":{"log.keyword":{"value":"*failed*"}}}'
  run_o2 "Q06-FTS-Failed" "Full Text Search" "$CACHE" "SELECT * FROM logs_bench WHERE match_all('failed') LIMIT 100"

  es_q "Q07-FTS-Connection" "Full Text Search" "$CACHE" '{"wildcard":{"log.keyword":{"value":"*Connection*"}}}'
  run_o2 "Q07-FTS-Connection" "Full Text Search" "$CACHE" "SELECT * FROM logs_bench WHERE match_all('Connection') LIMIT 100"

  es_q "Q08-FTS-Scrape" "Full Text Search" "$CACHE" '{"wildcard":{"log.keyword":{"value":"*Scrape*"}}}'
  run_o2 "Q08-FTS-Scrape" "Full Text Search" "$CACHE" "SELECT * FROM logs_bench WHERE match_all('Scrape') LIMIT 100"

  # Aggregations
  es_agg "Q09-Agg-Namespace" "Aggregation" "$CACHE" '"aggs":{"by_ns":{"terms":{"field":"kubernetes_namespace_name.keyword","size":10}}}'
  run_o2 "Q09-Agg-Namespace" "Aggregation" "$CACHE" "SELECT kubernetes_namespace_name, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_namespace_name ORDER BY cnt DESC LIMIT 10"

  es_agg "Q10-Agg-Container" "Aggregation" "$CACHE" '"aggs":{"by_container":{"terms":{"field":"kubernetes_container_name.keyword","size":10}}}'
  run_o2 "Q10-Agg-Container" "Aggregation" "$CACHE" "SELECT kubernetes_container_name, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_container_name ORDER BY cnt DESC LIMIT 10"

  es_agg "Q11-Agg-Host" "Aggregation" "$CACHE" '"aggs":{"by_host":{"terms":{"field":"kubernetes_host.keyword","size":10}}}'
  run_o2 "Q11-Agg-Host" "Aggregation" "$CACHE" "SELECT kubernetes_host, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_host ORDER BY cnt DESC LIMIT 10"

  # Combined
  es_agg_filter "Q12-Filter+Agg" "Combined" "$CACHE" '{"term":{"kubernetes_namespace_name.keyword":"monitoring"}}' '"aggs":{"by_container":{"terms":{"field":"kubernetes_container_name.keyword","size":10}}}'
  run_o2 "Q12-Filter+Agg" "Combined" "$CACHE" "SELECT kubernetes_container_name, COUNT(*) as cnt FROM logs_bench WHERE kubernetes_namespace_name='monitoring' GROUP BY kubernetes_container_name ORDER BY cnt DESC LIMIT 10"

  es_q "Q13-FTS+Filter" "Combined" "$CACHE" '{"wildcard":{"log.keyword":{"value":"*failed*"}}},{"term":{"kubernetes_namespace_name.keyword":"production"}}'
  run_o2 "Q13-FTS+Filter" "Combined" "$CACHE" "SELECT * FROM logs_bench WHERE match_all('failed') AND kubernetes_namespace_name='production' LIMIT 100"

  # Heavy
  es_count "Q14-Count-All" "Heavy" "$CACHE"
  run_o2 "Q14-Count-All" "Heavy" "$CACHE" "SELECT COUNT(*) as total FROM logs_bench"

  es_agg "Q15-Agg-Role" "Heavy" "$CACHE" '"aggs":{"by_role":{"terms":{"field":"kubernetes_labels_role.keyword","size":10}}}'
  run_o2 "Q15-Agg-Role" "Heavy" "$CACHE" "SELECT kubernetes_labels_role, COUNT(*) as cnt FROM logs_bench GROUP BY kubernetes_labels_role ORDER BY cnt DESC LIMIT 10"
}

echo "Mode: $MODE"
echo "========================================"
echo "COLD CACHE"
echo "System | Query | Cache | Response | Took | Status"
echo "========================================"
run_queries "cold"

echo ""
echo "========================================"
echo "WARM CACHE"
echo "========================================"
run_queries "warm"

echo ""
echo "CSV saved to: $RESULTS"
cat $RESULTS
