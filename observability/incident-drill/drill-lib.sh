# Project-Created File (NOT Instructor-Provided)
# Shared helpers for the Capstone 2 Step 6 incident drill. Read-only queries only.
NS=robot-shop
# DRILL_RUN (optional) keeps each run's evidence separate, e.g. DRILL_RUN=run2-slack.
EVID="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/evidence${DRILL_RUN:+/$DRILL_RUN}"
mkdir -p "$EVID"
PROM_PORT=$(kubectl -n monitoring get svc kp-stack-prometheus -o jsonpath='{.spec.ports[?(@.port==9090)].name}')
AM_PORT=$(kubectl -n monitoring get svc kp-stack-alertmanager -o jsonpath='{.spec.ports[?(@.port==9093)].name}')

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

promq() {
  local enc
  enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1")
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-prometheus:$PROM_PORT/proxy/api/v1/query?query=$enc" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)["data"]["result"]
print("; ".join("%s=%s" % ({k:v for k,v in r["metric"].items() if k!="__name__"}, r["value"][1]) for r in d) or "(empty)")'
}

alert_state() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-prometheus:$PROM_PORT/proxy/api/v1/alerts" \
    | python3 -c 'import json,sys
a=[x for x in json.load(sys.stdin)["data"]["alerts"] if x["labels"].get("alertname")=="RobotShopAvailabilitySLOBurn"]
print(" ".join("%s(activeAt=%s,value=%s)" % (x["state"], x.get("activeAt"), x.get("value")) for x in a) or "inactive")'
}

am_alerts() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-alertmanager:$AM_PORT/proxy/api/v2/alerts?filter=alertname%3D%22RobotShopAvailabilitySLOBurn%22" \
    | python3 -c 'import json,sys
a=json.load(sys.stdin)
print(" ".join("%s(startsAt=%s,receivers=%s)" % (x["status"]["state"], x["startsAt"], [r["name"] for r in x["receivers"]]) for x in a) or "none")'
}

snapshot() {
  echo "[$(ts)] ratio5m=$(promq 'robotshop:availability_error_ratio:rate5m') | sli_req=$(promq 'robotshop:sli_requests:rate5m') | alert=$(alert_state) | alertmanager=$(am_alerts)"
  echo "    5xx by route: $(promq 'sum by (service, route) (rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue", status=~"5.."}[1m]))')"
  echo "    alertmanager slack sent/failed: $(promq 'sum(alertmanager_notifications_total{integration="slack"})') / $(promq 'sum(alertmanager_notifications_failed_total{integration="slack"})')"
  echo "    pods:$(kubectl -n $NS get pods -l 'service in (mongodb,catalogue,cart)' --no-headers 2>&1 | awk '{print $1" "$2" "$3" r="$4}' | paste -sd',')"
}
