#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Read-only final validation of the Capstone 2 deployment. Writes evidence/final-validation.txt.
source "$(dirname "$0")/incident-drill/drill-lib.sh"
OUT="$(dirname "$0")/incident-drill/evidence/final-validation.txt"
{
  echo "== Final validation $(ts)  context=$(kubectl config current-context)"
  echo "== GitHub master: $(GIT_TERMINAL_PROMPT=0 git -C "$(dirname "$0")/.." ls-remote origin refs/heads/master | cut -c1-7)   local HEAD: $(git -C "$(dirname "$0")/.." rev-parse --short HEAD)"
  echo; echo "== helm list -A"; helm list -A
  echo; echo "== kubectl get pods -A"; kubectl get pods -A
  echo; echo "== kubectl get svc -A"; kubectl get svc -A
  echo; echo "== kubectl get endpoints -n robot-shop,monitoring (ready addresses)"
  for ns in robot-shop monitoring; do kubectl -n $ns get endpoints 2>/dev/null; done
  echo; echo "== Not-Running pods (all namespaces)"; kubectl get pods -A --no-headers | awk '$4!="Running" && $4!="Completed"' | grep . || echo "   none"
  echo; echo "== Known Kind limitation: web Service type LoadBalancer has no external IP"
  kubectl -n robot-shop get svc web --no-headers
  echo "   Access is via NodePort/port-forward; <pending> is expected on Kind (no cloud load balancer)."
  echo; echo "== Prometheus targets (robot-shop)"
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-prometheus:$PROM_PORT/proxy/api/v1/targets?state=active" | python3 -c '
import json,sys
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    l=t["labels"]
    if l.get("namespace")=="robot-shop":
        print("  ", l.get("job"), t["scrapeUrl"], t["health"].upper(), t["lastError"] or "")'
  echo; echo "== SLI and alert"
  echo "   requests/s (5m): $(promq robotshop:sli_requests:rate5m)"
  echo "   error ratio 5m:  $(promq robotshop:availability_error_ratio:rate5m)   (SLO target < 0.01; alert fires > 0.05 for 2m)"
  echo "   budget remaining 24h: $(promq robotshop:availability_error_budget_remaining:ratio24h)"
  echo "   alert: $(alert_state)"
  echo "   rule groups: $(kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-prometheus:$PROM_PORT/proxy/api/v1/rules" | python3 -c 'import json,sys; print(", ".join("%s=%s" % (g["name"], "ok" if all(r["health"]=="ok" for r in g["rules"]) else "ERR") for g in json.load(sys.stdin)["data"]["groups"] if g["name"].startswith("robot-shop")))')"
  echo; echo "== Alertmanager Slack route and counters"
  kubectl -n robot-shop get alertmanagerconfig robot-shop-slack --no-headers
  echo "   $(kubectl get --raw "/api/v1/namespaces/monitoring/services/kp-stack-alertmanager:$AM_PORT/proxy/metrics" | grep -E '^alertmanager_notifications_total\{integration="slack"\}')"
  echo; echo "== Grafana dashboard ConfigMap"; kubectl -n monitoring get cm robot-shop-golden-signals-dashboard --show-labels --no-headers
  echo; echo "== Loki: robot-shop log lines per service, last 10m; Instana warnings last 10m"
  LP=$(kubectl -n monitoring get svc loki -o jsonpath='{.spec.ports[0].name}')
  for q in 'sum by (service) (count_over_time({namespace="robot-shop"}[10m]))' 'sum by (service) (count_over_time({namespace="robot-shop"} |= "Agent cannot be contacted" [10m]))'; do
    enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$q")
    echo "   $q"
    kubectl get --raw "/api/v1/namespaces/monitoring/services/loki:$LP/proxy/loki/api/v1/query?query=$enc" | python3 -c '
import json,sys
r=json.load(sys.stdin)["data"]["result"]
print("     ", "; ".join("%s=%s" % (x["metric"].get("service"), x["value"][1]) for x in r) or "(none)")'
  done
  echo; echo "== Jaeger: services and a recent multi-service trace"
  JP=$(kubectl -n monitoring get svc jaeger-query -o jsonpath='{.spec.ports[0].name}')
  kubectl get --raw "/api/v1/namespaces/monitoring/services/jaeger-query:$JP/proxy/api/services" | python3 -c 'import json,sys; print("   services:", sorted(json.load(sys.stdin)["data"]))'
  for s in payment cart; do
    kubectl get --raw "/api/v1/namespaces/monitoring/services/jaeger-query:$JP/proxy/api/traces?service=$s&limit=50&lookback=15m" | python3 -c '
import json,sys
for t in json.load(sys.stdin)["data"]:
    svcs=sorted({p["serviceName"] for p in t["processes"].values()})
    if len(svcs)>1:
        root=min(t["spans"], key=lambda s: s["startTime"])
        print("   '"$s"' trace", t["traceID"], "services", svcs, "spans", len(t["spans"]), "root", root["operationName"]); break'
  done
  echo; echo "== Capstone 1 (default namespace, read only)"; kubectl -n default get pods; helm -n default status my-vote-release | grep -E 'STATUS|REVISION'
} 2>&1 | tee "$OUT"
