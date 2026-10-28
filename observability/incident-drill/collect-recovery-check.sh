#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Read-only post-drill check: separates "errors still happening" (1m rate) from the
# lagging 5m SLI window, around the run-2 alert resolution, and checks current health.
# Output: evidence/run2-slack/06-recovery-check.txt
DRILL_RUN=run2-slack source "$(dirname "$0")/drill-lib.sh"
range() {  # $1 = PromQL, prints one value per 30s step from 20:47:00 to 20:56:00 UTC
  local enc
  enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1")
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-prometheus:$PROM_PORT/proxy/api/v1/query_range?query=$enc&start=2026-10-28T20:47:00Z&end=2026-10-28T20:56:00Z&step=30s" \
    | python3 -c 'import json,sys,datetime
for r in json.load(sys.stdin)["data"]["result"]:
    print("  ", {k:v for k,v in r["metric"].items() if k!="__name__"} or "{}")
    for t,v in r["values"]:
        print("     ", datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime("%H:%M:%S"), "%.4f" % float(v))'
}
{
  echo "== generated $(ts)"
  echo "## 5xx per second by service (1m window: are errors still occurring?)"
  range 'sum by (service) (rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue", status=~"5.."}[1m]))'
  echo "## error ratio, 1m window"
  range '(sum(rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue", status=~"5.."}[1m])) or vector(0)) / sum(rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue"}[1m]))'
  echo "## error ratio, 5m window (SLI used by the alert)"
  range 'robotshop:availability_error_ratio:rate5m'
  echo "## NOW"
  echo "ratio5m=$(promq robotshop:availability_error_ratio:rate5m)"
  echo "5xx/s last 5m by service, route=$(promq 'sum by (service, route) (rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue", status=~"5.."}[5m]))')"
  echo "sli requests/s=$(promq robotshop:sli_requests:rate5m)"
  echo "alert=$(alert_state)"
  echo "## dependencies"
  kubectl -n $NS get pods -l 'service in (catalogue,cart,mongodb,redis,web,load)' -o wide --no-headers | awk '{print $1, $2, $3, "restarts=" $4, $5}'
  echo "catalogue MongoError lines since 20:49Z: $(kubectl -n $NS logs deploy/catalogue --since-time=2026-10-28T20:49:00Z | grep -c MongoError)"
  echo "catalogue log lines with statusCode 5xx since 20:49Z: $(kubectl -n $NS logs deploy/catalogue --since-time=2026-10-28T20:49:00Z | grep -c '"statusCode":5')"
  echo "cart error-level lines since 20:49Z: $(kubectl -n $NS logs deploy/cart --since-time=2026-10-28T20:49:00Z | grep -c '"level":"error"')"
  echo "redis PING: $(kubectl -n $NS exec redis-0 -- redis-cli ping 2>&1)"
  echo "mongodb ping: $(kubectl -n $NS exec deploy/mongodb -- mongo --quiet --eval 'db.adminCommand({ping:1}).ok' 2>&1 | tail -1)"
} 2>&1 | tee "$EVID/06-recovery-check.txt"
