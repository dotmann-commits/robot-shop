#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Capstone 2 Step 6, phase 1: record a healthy baseline, induce the fault (MongoDB scaled to 0 in
# robot-shop only), then poll until RobotShopAvailabilitySLOBurn fires or 12 minutes pass.
# Output: evidence/01-baseline.txt, evidence/02-inject-detect.log
source "$(dirname "$0")/drill-lib.sh"

{
  echo "== Healthy baseline captured $(ts)"
  kubectl config current-context
  kubectl -n $NS get pods
  kubectl -n $NS get deploy mongodb catalogue cart
  echo "-- SLI"
  for q in robotshop:sli_requests:rate5m robotshop:availability_error_ratio:rate5m robotshop:availability_error_ratio:rate1h robotshop:availability_error_budget_remaining:ratio24h; do
    echo "$q = $(promq $q)"
  done
  echo "alert = $(alert_state)"
  echo "alertmanager = $(am_alerts)"
  echo "-- default namespace (Capstone 1, read only)"
  kubectl -n default get pods
} > "$EVID/01-baseline.txt" 2>&1
cat "$EVID/01-baseline.txt"

LOG="$EVID/02-inject-detect.log"
{
  echo "[$(ts)] INJECT: kubectl -n robot-shop scale deploy/mongodb --replicas=0"
  kubectl -n $NS scale deploy/mongodb --replicas=0
  for i in $(seq 1 48); do
    snapshot
    if alert_state | grep -q '^firing'; then
      echo "[$(ts)] DETECTED: RobotShopAvailabilitySLOBurn is firing"
      sleep 20
      snapshot
      echo "-- catalogue logs (last 15 lines) $(ts)"
      kubectl -n $NS logs deploy/catalogue --tail=15
      exit 0
    fi
    sleep 15
  done
  echo "[$(ts)] TIMEOUT: alert did not fire within 12 minutes"
} 2>&1 | tee "$LOG"
