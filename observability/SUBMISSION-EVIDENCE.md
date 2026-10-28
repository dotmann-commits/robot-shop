# Capstone 2: Submission Evidence Checklist

> Project-created checklist (not instructor-provided). Status values reflect what was actually checked on 2026-10-28; nothing is marked verified without evidence.

## Hand In (brief, slide 8)

| Item | Location | Status |
|---|---|---|
| Dashboard exported as code | `observability/grafana/robot-shop-golden-signals.json` (+ ConfigMap) | Present; ConfigMap `robot-shop-golden-signals-dashboard` is in the cluster |
| Logging config | `observability/logging/` (Fluent Bit, Loki, Grafana Loki datasource) | Present; fluent-bit and loki pods Running |
| Tracing config | `observability/tracing/jaeger.yaml`, `otel-collector.yaml` | Present; pods Running. **`grafana-jaeger-datasource.yaml` named in the handover is missing** |
| SLO document with error budget | `observability/slo/robot-shop-availability-slo.md`, `observability/slo/error-budget-policy.md` | Written |
| Blameless postmortem | `observability/incident-drill/POSTMORTEM.md` | Written from drill evidence (2026-10-28 19:52–20:06 UTC) |

## Done Means (brief, slide 8)

| Criterion | Evidence | Status |
|---|---|---|
| The alert fires during the drill | `observability/incident-drill/evidence/02-inject-detect.log` | **Verified:** pending 19:57:21, firing 19:59:21, received by Alertmanager, resolved by 20:04:57 UTC |
| Alert delivered to Slack | `evidence/run2-slack/03-mitigate-recover.log`, `05-alertmanager-slack-delivery.txt` + channel screenshot | **Verified (run 2):** Alertmanager Slack notifications 0 → 1 (firing, ~20:46) → 2 (resolved, ~20:52), 0 failures. Run 1 had no Slack set up |
| One request is traced | Jaeger: checkout (payment → cart), add to cart (cart → catalogue) | Reported earlier; screenshots needed |
| Logs searchable by service and level | Grafana Explore, Loki: `{namespace="robot-shop", service="catalogue"} \|= "error"` | Reported earlier; screenshot needed |
| Runbook linked from the alert | `runbook_url` annotation in `observability/alerting/robot-shop-slo-rules.yaml` → `observability/runbooks/robot-shop-availability-slo.md` | Linked; URL resolves only after the files are pushed to the fork |

## Post-drill recovery verification

- `observability/incident-drill/evidence/run2-slack/06-recovery-check.txt`: 1m vs 5m error ratios around the alert resolving, current health, and dependency checks (Redis `PONG`, MongoDB `ping`).
- `observability/incident-drill/evidence/run2-slack/07-traffic-check.txt`: traffic by service; shows the monitoring gap from host Modern Standby (20:46:31–21:21:42 UTC per the Windows System log, with scrapes missing from about 20:57).

## Screenshots to capture

1. `kubectl -n robot-shop get pods` (all Running) and `helm list -A`.
2. Grafana Golden Signals dashboard, healthy, and during the drill window (19:52–20:15 UTC on 2026-10-28).
3. Prometheus **Alerts** page with `RobotShopAvailabilitySLOBurn` FIRING, and the **Rules** page showing the SLO group as healthy.
4. Prometheus graph of `robotshop:availability_error_ratio:rate5m` covering the drill.
5. Alertmanager UI with the alert received.
6. Loki query showing catalogue errors during the drill.
7. Jaeger traces (checkout, add to cart).
8. Slack channel: the **[FIRING]** (about 20:46 UTC) and **[RESOLVED]** (about 20:52 UTC) `RobotShopAvailabilitySLOBurn` messages from run 2.

## Files created or changed in this step (uncommitted)

- `observability/alerting/robot-shop-slo-rules.yaml`: applied to the cluster.
- `observability/alerting/alertmanager-slack-config.yaml`: applied 2026-10-28 20:38:34 UTC. The webhook lives only in the cluster Secret `robot-shop/alertmanager-slack-webhook`, never in Git.
- `observability/runbooks/robot-shop-availability-slo.md`
- `observability/slo/robot-shop-availability-slo.md`, `observability/slo/error-budget-policy.md`
- `observability/incident-drill/` (drill scripts, evidence logs, postmortem)
