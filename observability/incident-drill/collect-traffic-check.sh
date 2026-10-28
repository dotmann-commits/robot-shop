#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Read-only: is the load generator still driving the full journey after the drills?
# Output: evidence/run2-slack/07-traffic-check.txt
DRILL_RUN=run2-slack source "$(dirname "$0")/drill-lib.sh"
range() {
  local enc
  enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1")
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-prometheus:$PROM_PORT/proxy/api/v1/query_range?query=$enc&start=2026-10-28T19:30:00Z&end=$(date -u +%Y-%m-%dT%H:%M:%SZ)&step=300s" \
    | python3 -c 'import json,sys,datetime
for r in json.load(sys.stdin)["data"]["result"]:
    print("  ", {k:v for k,v in r["metric"].items() if k!="__name__"} or "{}")
    print("     ", " ".join("%s=%.2f" % (datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime("%H:%M"), float(v)) for t,v in r["values"]))'
}
{
  echo "== generated $(ts)"
  echo "## requests/s by service (5m), 19:30 -> now"
  range 'sum by (service) (rate(http_requests_total{namespace="robot-shop"}[5m]))'
  echo "## nginx (web) requests/s"
  range 'sum(rate(nginx_http_requests_total{namespace="robot-shop"}[5m]))'
  echo "## load pod"
  kubectl -n $NS get pod -l service=load -o wide --no-headers
  kubectl -n $NS top pod -l service=load 2>&1 | tail -1
  echo "## load logs: last 40 lines"
  kubectl -n $NS logs deploy/load --tail=40
  echo "## load logs: counts in last 10 minutes"
  kubectl -n $NS logs deploy/load --since=10m > /tmp/load10m.txt
  for p in 'Order ' 'Final cart' 'User ' 'Error request' 'Traceback' 'Exception' 'JSONDecodeError' 'KeyError' 'IndexError' 'Starting'; do
    echo "  '$p': $(grep -c "$p" /tmp/load10m.txt)"
  done
} 2>&1 | tee "$EVID/07-traffic-check.txt"
