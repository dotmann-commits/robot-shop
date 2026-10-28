# Postmortem: Catalogue outage after MongoDB loss (controlled drill)

> Project-created, blameless postmortem (not instructor-provided). Capstone 2, Step 6.
> Every time and number below comes from the evidence files in [`evidence/`](evidence/), gathered live by the drill scripts in this folder. All times are UTC on 2026-10-28.

| | |
|---|---|
| **Type** | Planned, controlled drill, self-run (no instructor-injected fault) |
| **Scope** | Namespace `robot-shop` only. Capstone 1 (`default` namespace) checked before and after; unchanged |
| **Severity** | Critical (SLO burn alert) |
| **Duration of customer-facing errors** | about 10 minutes (first MongoError log 19:53–19:54 → last catalogue 5xx before 20:03:12) |
| **Alert** | `RobotShopAvailabilitySLOBurn`: pending 19:57:21, **firing 19:59:21**, resolved between 20:04:39 and 20:04:57 |
| **Error budget used** | Run 1: about **19.4%** of the 24h budget (`budget_remaining` = 0.806 at 20:06:42). Run 2: about **19.6%** (0.849 → 0.653). Both runs together: about 35%, so the budget stays in the policy's "Healthy" band (> 50%) |
| **Runs** | Run 1, 19:52–20:06: alert verified, Slack **not** configured. Run 2, 20:39–20:52: same fault, **Slack delivery verified** (see [Run 2](#run-2-slack-delivery-verification)) |

## Summary

To test the new availability SLO alert, the MongoDB deployment in `robot-shop` was scaled to 0 replicas. Catalogue stayed Running but answered `/products` with HTTP 500 (`MongoError`). That stopped the shopping journey before customers reached the cart. The SLO alert fired 6 min 24 s after the fault. Restoring MongoDB **did not** fix catalogue: it kept returning 500s for 2 more minutes, until it was restarted. Service was then fully healthy again.

## Impact

- Product listing (`GET /products`) failed for every request. The load generator's journey (browse → add to cart → checkout) ends at that call, so cart, shipping and payment traffic fell away too.
- The SLI's request rate fell from **7.30 req/s** to about **0.09–0.12 req/s**. The SLI therefore **under-counts** impact: requests that were never made are invisible to a server-side ratio.
- No data loss of note. MongoDB's catalogue and user data are baked into the `rs-mongodb` image and were reseeded when the pod was recreated.
- Payment's own synthetic 500s (load generator `ERROR="1"`) continued as usual and are not part of this incident.

## Timeline (UTC)

| Time | Event | Source |
|---|---|---|
| 19:52:55 | Healthy baseline: all robot-shop pods 1/1 Running, 0 restarts; SLI 7.30 req/s, error ratio 0, budget remaining 1.0; alert inactive | `01-baseline.txt` |
| **19:52:57** | **Fault injected:** `kubectl -n robot-shop scale deploy/mongodb --replicas=0` | `02-inject-detect.log` |
| 19:53:14 | MongoDB pod gone; catalogue still 1/1 Running | `02` |
| 19:53–19:54 | First `MongoError` lines from catalogue in Loki | `04-loki-catalogue-errors.txt` |
| 19:53:47 | 5m error ratio starts rising (0.47%); SLI traffic starts falling (6.28 req/s) | `02` |
| 19:57:21 | Error ratio passes 5% (6.96%) → alert **pending** | `02` |
| 19:58:12 | Error ratio 100%; SLI traffic about 0.09 req/s | `02` |
| **19:59:21** | Alert **firing**; Alertmanager receives it (receiver `null`, see "Slack" below) | `02` |
| 19:59:48 | Detection confirmed by responder; catalogue logs show `MongoError` and HTTP 500 on `/products` | `02` |
| **20:00:26** | **Mitigation 1:** `kubectl -n robot-shop scale deploy/mongodb --replicas=1` | `03-mitigate-recover.log` |
| 20:00:36 | MongoDB rollout complete, pod 1/1 Running | `03` |
| 20:00:36–20:02:36 | Catalogue **still** returning 5xx on `/products` (0.04–0.18 req/s); error ratio stays about 97–100% | `03`, `04` |
| **20:02:37** | **Mitigation 2 (runbook step):** `kubectl -n robot-shop rollout restart deploy/catalogue` | `03` |
| 20:02:40 | New catalogue pod Ready | `03` |
| 20:03:12 | No catalogue/cart 5xx any more; traffic recovering | `03` |
| 20:04:39 → 20:04:57 | Error ratio drops below 5% (5.14% → 4.90%); alert **resolved**, gone from Alertmanager | `03` |
| **20:06:42** | **Recovered:** 5m error ratio 0.92% (< 1% SLO); all pods Running; Capstone 1 pods unchanged | `03` |

**Time to detect** (fault → firing): 6 min 24 s. **Time to mitigate** (firing → last fix applied): 3 min 16 s. **Time to recover** (fault → errors stop): about 10 min.

## Root cause

**Trigger:** loss of the catalogue service's data store (MongoDB scaled to 0, simulating a crashed or deleted database pod).

**Why the outage lasted beyond the database's return:** catalogue does not recover its MongoDB connection by itself. In `catalogue-server.js`, `mongoLoop()` sets `mongoConnected = true` once at startup and never checks again. After MongoDB came back, the existing client kept failing with `MongoError` until the process restarted. The 2 minutes of 5xx after MongoDB was Ready (20:00:36–20:02:36) are the evidence for this. (The drill did not test whether catalogue would recover by itself given longer.)

**Why Kubernetes did not heal it:** the catalogue deployment has **no readiness or liveness probe**. Its `/health` endpoint reports the same stale `mongoConnected` flag, so even a probe on it would have passed.

## Detection: what went well, what didn't

- ✅ The SLO alert fired with no false positives during baseline and resolved by itself after recovery.
- ✅ Logs were searchable by service and level in Loki (`{namespace="robot-shop", service="catalogue"} |= "MongoError"`), which pointed straight at the dependency.
- ⚠️ **Slow detection (6.4 min).** Traffic collapsed together with the errors, so the 5-minute ratio only rose as the earlier healthy requests aged out of the window. An alert based on a ratio cannot see "nobody can get far enough to make requests".
- ⚠️ `level="error"` lines from catalogue also appear at baseline (11–13 per minute before the fault), so the `MongoError` text, not the level label, was the useful signal.
- ❌ **Run 1 only: Slack delivery was not set up.** No Slack Incoming Webhook was available when run 1 started. The `alertmanager-slack-webhook` Secret did not exist (checked at 19:53:24 and 20:00:14). The Slack routing was therefore not applied, and Alertmanager routed the alert to its default `null` receiver. This was fixed before run 2.

## Action items

| # | Action | Type | Owner |
|---|---|---|---|
| 1 | Make catalogue's `/health` actually ping MongoDB, and add readiness and liveness probes to the catalogue deployment, so Kubernetes restarts it after a lost connection | Prevent | Robot Shop team |
| 2 | Add a traffic-drop alert (for example, SLI request rate below 30% of its 1h average for 3m), or an `absent`/`up` check, to catch failures that suppress traffic instead of producing errors | Detect | Robot Shop team |
| 3 | Add a MongoDB availability alert (`kube_deployment_status_replicas_available{deployment="mongodb"} < 1` for 1m) for faster, more direct detection | Detect | Robot Shop team |
| 4 | Create the Slack webhook Secret, apply `alertmanager-slack-config.yaml`, and re-run the drill to verify Slack delivery | Process | **Done (run 2)** |
| 5 | Add a "restart dependents after the data store returns" note to the runbook (done: runbook section 3) | Mitigate | Done |

## Run 2: Slack delivery verification

Before run 2, a **new** Slack Incoming Webhook was created (the earlier one had been exposed and was not reused). It was entered through a masked local dialog and stored in the existing Secret `robot-shop/alertmanager-slack-webhook`, which was updated in place, not deleted. Checked without revealing the value: 81 bytes, Slack webhook prefix, no whitespace. `alertmanager-slack-config.yaml` was applied at 20:38:34, and the generated Alertmanager config showed the `robot-shop/robot-shop-slack/slack-robot-shop` route. Pre-drill: error ratio 0, budget remaining 0.849, Slack sent/failed 0/0.

| Time (UTC) | Event | Source |
|---|---|---|
| 20:39:44 | Fault injected (same as run 1: MongoDB → 0 replicas) | `evidence/run2-slack/02-inject-detect.log` |
| 20:43:21 | Alert pending | `run2-slack/02` |
| **20:45:21** | Alert **firing**; Alertmanager routes it to receiver `robot-shop/robot-shop-slack/slack-robot-shop` | `run2-slack/02`, `05-alertmanager-slack-delivery.txt` |
| 20:45:57 → 20:46:06 | **Slack FIRING notification sent:** `alertmanager_notifications_total{integration="slack"}` 0 → 1; all failure counters 0 | `run2-slack/02`, `03` |
| 20:46:08 | Mitigation 1: MongoDB scaled back to 1 (Ready 20:46:10) | `run2-slack/03` |
| 20:46:10–20:48:24 | Catalogue **still** returning 5xx (up to 0.27 req/s), reproducing run 1's root cause | `run2-slack/03` |
| 20:48:25 | Mitigation 2: `rollout restart deploy/catalogue` (Ready 20:48:27) | `run2-slack/03` |
| 20:50:23 → 20:50:39 | Alert resolved (error ratio 5.4% → 4.3%) | `run2-slack/03` |
| 20:51:47 → 20:52:04 | **Slack RESOLVED notification sent:** counter 1 → 2; failures still 0 | `run2-slack/03` |
| 20:52:40 | Recovered: 5m error ratio 0.80%; budget remaining 0.653 | `run2-slack/03` |

Time to detect: 5 min 37 s. Mitigation, from firing to last fix: 3 min 4 s.

### Was the service healthy when the alert resolved?

At 20:50:23 the alert still showed 5.43%, and it cleared at 20:50:39 at 4.30%. Both are above the 1% SLO. A post-drill check (`evidence/run2-slack/06-recovery-check.txt`) separated "errors still happening" from "errors still in the 5-minute window":

| Time (UTC) | 5xx/s (1m) | Error ratio (1m) | Error ratio (5m, alert input) |
|---|---|---|---|
| 20:48:30 | 0.27 | 100% | 100% |
| 20:49:00 | 0.08 | 9.2% | 59.8% |
| 20:49:30 | none | **0%** | 13.0% |
| 20:50:30 | none | 0% | 5.4% (alert clears between 20:50:23 and 20:50:39) |
| 20:51:00 | none | 0% | 3.5% (alert inactive) |
| 20:52:30 | none | 0% | 1.2% |
| 20:53:30 | none | 0% | **0%** |

**Real errors stopped at about 20:49:00, within 30 seconds of the catalogue restart.** The alert resolved about 1.5 minutes later, which is lag from the 5-minute window, not an early "all clear". There is one threshold (5%) for both firing and resolving; there is no separate recovery threshold. Recovery against the SLO (5m ratio < 1%) was reached at 20:52:40 and 0% at 20:53:30. At 21:23–21:24, no catalogue `MongoError` or 5xx log lines and no cart error lines had appeared since 20:49, Redis answered `PONG` and MongoDB answered `ping` = 1. The runbook's "Verify recovery" step now spells this out.

**Monitoring gap after the drill (not a service fault):** the Windows System log shows the host entered Modern Standby at 20:46:31 and left it at 21:21:42. Prometheus kept a full set of scrapes until about 20:54 (20 of 20 per 5 min), so run 2's evidence is complete. After that, scrapes stopped from about 20:57 to 21:21. Right after wake, the 5-minute request rate briefly read 2.4–2.6 req/s because its window straddled the gap. The 2-minute rate at 21:24 was 5.77 req/s (cart 2.83, catalogue 2.94), in line with pre-drill traffic (`evidence/run2-slack/07-traffic-check.txt`).

**What "verified" means here:** Alertmanager's own counters show two Slack sends (firing and resolved), each accepted by Slack's webhook endpoint, with zero failures of any kind. The message as it appears in the channel is to be confirmed by the author's screenshot. A search through the Claude Slack connector found no matching message (cause not confirmed; possibly a different workspace or search indexing).

## Lessons

Recovery of a dependency is not recovery of the service. Check the user-facing signal (the error ratio), not just pod status. All pods showed `Running` throughout this incident.
