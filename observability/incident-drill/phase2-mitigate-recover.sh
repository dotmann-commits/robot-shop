#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Capstone 2 Step 6, phase 2: mitigate per the runbook (restore MongoDB to 1 replica), restart
# catalogue only if it is still failing 2 minutes after MongoDB is Ready, then poll until the alert
# resolves and the 5m error ratio is back under the 1% SLO (or 15 minutes pass).
# Output: evidence/03-mitigate-recover.log
source "$(dirname "$0")/drill-lib.sh"
LOG="$EVID/03-mitigate-recover.log"
{
  snapshot
  echo "[$(ts)] MITIGATE: kubectl -n robot-shop scale deploy/mongodb --replicas=1"
  kubectl -n $NS scale deploy/mongodb --replicas=1
  kubectl -n $NS rollout status deploy/mongodb --timeout=180s
  echo "[$(ts)] MongoDB deployment reports Ready"
  ready_at=$(date +%s)
  restarted=0
  for i in $(seq 1 60); do
    snapshot
    errs=$(promq 'sum(rate(http_requests_total{namespace="robot-shop", service="catalogue", status=~"5.."}[1m]))' | sed 's/.*=//')
    if [ $restarted -eq 0 ] && [ $(( $(date +%s) - ready_at )) -ge 120 ] && python3 -c "import sys; sys.exit(0 if float('${errs:-0}' if '${errs}' != '(empty)' else 0) > 0.05 else 1)"; then
      echo "[$(ts)] catalogue still returning 5xx ${errs}/s two minutes after MongoDB Ready -> runbook step: rollout restart catalogue"
      kubectl -n $NS logs deploy/catalogue --tail=10
      kubectl -n $NS rollout restart deploy/catalogue
      kubectl -n $NS rollout status deploy/catalogue --timeout=180s
      echo "[$(ts)] catalogue restarted and Ready"
      restarted=1
    fi
    if alert_state | grep -q '^inactive' && python3 -c "import sys; v='$(promq robotshop:availability_error_ratio:rate5m | sed 's/.*=//')'; sys.exit(0 if v!='(empty)' and float(v) < 0.01 else 1)"; then
      echo "[$(ts)] RECOVERED: alert inactive and 5m error ratio below 1%"
      snapshot
      echo "alertmanager now: $(am_alerts)"
      echo "budget remaining (24h): $(promq robotshop:availability_error_budget_remaining:ratio24h)"
      echo "error ratio 1h: $(promq robotshop:availability_error_ratio:rate1h)"
      kubectl -n $NS get pods
      kubectl -n default get pods
      exit 0
    fi
    sleep 15
  done
  echo "[$(ts)] TIMEOUT: recovery criteria not met within 15 minutes"
} 2>&1 | tee "$LOG"
