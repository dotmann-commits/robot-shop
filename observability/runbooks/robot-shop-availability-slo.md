# Runbook: RobotShopAvailabilitySLOBurn

> Project-created runbook (not instructor-provided). Linked from the alert's `runbook_url` annotation.

## What fired

More than 5% of HTTP requests to **cart** and **catalogue** in namespace `robot-shop` returned 5xx over the last 5 minutes, sustained for 2 minutes. The SLO allows 1% (see [SLO document](../slo/robot-shop-availability-slo.md)). At 5% the 24-hour error budget is gone in under 5 hours.

## 1. Confirm (2 minutes)

```bash
kubectl -n robot-shop get pods
kubectl -n monitoring port-forward svc/kp-stack-prometheus 9090:9090
```

In Prometheus, run:

```promql
robotshop:availability_error_ratio:rate5m
sum by (service, route, status) (rate(http_requests_total{namespace="robot-shop", status=~"5.."}[5m]))
```

Grafana: **Robot Shop Golden Signals** dashboard → HTTP errors panel.

## 2. Find the failing dependency

| Failing service | Depends on | Check |
|---|---|---|
| catalogue | MongoDB (`mongodb`) | `kubectl -n robot-shop get deploy mongodb` and `kubectl -n robot-shop logs deploy/catalogue --tail=50` |
| cart | Redis (`redis-0`), catalogue | `kubectl -n robot-shop get pod redis-0` and `kubectl -n robot-shop logs deploy/cart --tail=50` |

Logs in Grafana Explore (Loki):

```logql
{namespace="robot-shop", service="catalogue"} |= "error"
```

Recent changes: `kubectl -n robot-shop get events --sort-by=.lastTimestamp | tail -20` and `helm -n robot-shop history robot-shop`.

## 3. Mitigate first

| Cause | Mitigation |
|---|---|
| Data store scaled to 0 or crashed | `kubectl -n robot-shop scale deploy/mongodb --replicas=1` (or the affected store), then wait for `1/1 Running` |
| Service still failing after its data store is back (stale DB connection) | `kubectl -n robot-shop rollout restart deploy/catalogue` |
| Bad release | `helm -n robot-shop rollback robot-shop <previous-revision>` |

Do **not** touch the `default` namespace (Capstone 1 voting app).

## 4. Verify recovery

**RESOLVED in Slack is not the same as healthy.** The alert clears once the 5-minute error ratio drops below its **5%** firing threshold. The SLO target is **1%**. Because the 5-minute window still holds the outage's errors, the alert can clear while the ratio reads, for example, 4%. Declare recovery only when all of the following hold:

1. **Errors have stopped now.** The 1-minute ratio is 0 or close to it:
   ```promql
   (sum(rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue", status=~"5.."}[1m])) or vector(0))
   / sum(rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue"}[1m]))
   ```
2. `robotshop:availability_error_ratio:rate5m` is back under **0.01** (the SLO).
3. **Traffic is back to normal.** `robotshop:sli_requests:rate5m` is near its pre-incident level (about 5–7 req/s with the default load generator). Low traffic can hide a failure that stops users from getting as far as cart and catalogue.
4. No new 5xx or `MongoError` in the catalogue and cart logs, Redis answers `PING`, and MongoDB answers `ping`.

If Prometheus shows a gap with no scrapes (for example after the laptop sleeps), 5-minute rates next to the gap read low. Use 1–2 minute rates until the window fills again.

## 5. Afterwards

Record the timeline and evidence, then write a blameless postmortem. Work out how much error budget was used: `robotshop:availability_error_budget_remaining:ratio24h`.

## Known noise

Payment HTTP 500s are expected. The load generator runs with `ERROR="1"` and deliberately posts to `/pay/partner-57`. Payment is not part of this SLO.
