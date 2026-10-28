#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Read-only: count catalogue MongoError log lines in Loki per minute across the drill window.
# Output: evidence/04-loki-catalogue-errors.txt
source "$(dirname "$0")/drill-lib.sh"
LOKI_PORT=$(kubectl -n monitoring get svc loki -o jsonpath='{.spec.ports[0].name}')
OUT="$EVID/04-loki-catalogue-errors.txt"
start=$(date -u -d '2026-10-28T19:50:00Z' +%s)000000000
end=$(date -u -d '2026-10-28T20:08:00Z' +%s)000000000
{
  echo "== Loki labels available $(ts)"
  kubectl get --raw "/api/v1/namespaces/monitoring/services/loki:$LOKI_PORT/proxy/loki/api/v1/labels"; echo
  for q in 'sum by (service) (count_over_time({namespace="robot-shop", service="catalogue"} |= "MongoError" [1m]))' \
           'sum by (service, level) (count_over_time({namespace="robot-shop", service="catalogue", level="error"} [1m]))'; do
    echo "## $q"
    enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$q")
    kubectl get --raw "/api/v1/namespaces/monitoring/services/loki:$LOKI_PORT/proxy/loki/api/v1/query_range?query=$enc&start=$start&end=$end&step=60" \
      | python3 -c 'import json,sys,datetime
d=json.load(sys.stdin)
r=d.get("data",{}).get("result",[])
if not r: print("   (empty)", d.get("status"))
for s in r:
    print("  ", s["metric"])
    for t,v in s["values"]:
        print("     ", datetime.datetime.fromtimestamp(float(t), datetime.timezone.utc).strftime("%H:%M:%SZ"), v)'
  done
} 2>&1 | tee "$OUT"
