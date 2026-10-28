# Capstone 2: Submission Evidence Checklist

> Project-created checklist (not instructor-provided). Status values reflect what was actually checked on 2026-10-28; nothing is marked verified without evidence.

## Hand In (brief, slide 8)

| Item | Location | Status |
|---|---|---|
| Dashboard exported as code | `observability/grafana/robot-shop-golden-signals.json` (+ ConfigMap) | Present; ConfigMap `robot-shop-golden-signals-dashboard` is in the cluster |
| Logging config | `observability/logging/` (Fluent Bit, Loki, Grafana Loki datasource) | Present; fluent-bit and loki pods Running |
| Tracing config | `observability/tracing/jaeger.yaml`, `otel-collector.yaml` | Present; pods Running. **`grafana-jaeger-datasource.yaml` named in the handover is missing** |
| SLO document with error budget | `observability/slo/robot-shop-availability-slo.md`, `observability/slo/error-budget-policy.md` | Written |
| Blameless postmortem | `observability/incident-drill/POSTMORTEM.md` | Written from evidence of both drill runs (2026-10-28 19:52–20:06 and 20:39–20:52 UTC) |

## Done Means (brief, slide 8)

| Criterion | Evidence | Status |
|---|---|---|
| The alert fires during the drill | `observability/incident-drill/evidence/02-inject-detect.log` | **Verified:** pending 19:57:21, firing 19:59:21, received by Alertmanager, resolved by 20:04:57 UTC |
| Alert delivered to Slack | `evidence/run2-slack/03-mitigate-recover.log`, `05-alertmanager-slack-delivery.txt` + channel screenshot | **Verified (run 2):** Alertmanager Slack notifications 0 → 1 (firing, ~20:46) → 2 (resolved, ~20:52), 0 failures. Run 1 had no Slack set up |
| One request is traced | `screenshots/09-jaeger-trace-payment-cart.png`, `10-jaeger-trace-cart-catalogue.png`; `evidence/final-validation.txt` | **Verified:** payment → cart (6 spans) and cart → catalogue (3 spans); fresh traces again at 23:07 UTC |
| Logs searchable by service and level | Loki labels `service` and `level`; `evidence/final-validation.txt` | **Verified by API** (23:07 UTC: `{namespace="robot-shop", service="catalogue", level="error"}` returned 105 lines in 10 min). Grafana Explore screenshots 07/08 are added by hand |
| Runbook linked from the alert | `runbook_url` annotation in `observability/alerting/robot-shop-slo-rules.yaml` → `observability/runbooks/robot-shop-availability-slo.md` | **Verified:** the link is in the Slack message template, and the GitHub URL returns HTTP 200 |

## Instana removal (brief, slide 6)

- Helm templates: all `INSTANA_AGENT_HOST` env vars and the EUM settings removed (commit `d8160cf`).
- Project ConfigMap `robot-shop-metrics-instrumentation`: the upstream Instana code is removed from cart and catalogue (`@instana/collector` start-up and the `instana.currentSpan()` middleware) and from payment (`import instana`). Deployed as Helm revision 12 on 2026-10-28 at 21:45 UTC. Before the change, most catalogue and cart log lines were Instana "Agent cannot be contacted" warnings. Afterwards there were 0 Instana log lines, Prometheus targets were up, the SLI error ratio was 0, and Jaeger received OpenTelemetry traces for cart→catalogue and payment→cart.
- **Known leftover:** the upstream `robotshop/rs-web` image builds an Instana nginx OpenTracing sensor into its own `nginx.conf` (via its entrypoint), which is why `x-instana-*` headers appear on proxied requests. No Instana agent is configured. Removing it would mean overriding the gateway's nginx configuration, and it was left as is for the deadline.

## Post-drill recovery verification

- `observability/incident-drill/evidence/run2-slack/06-recovery-check.txt`: 1m vs 5m error ratios around the alert resolving, current health, and dependency checks (Redis `PONG`, MongoDB `ping`).
- `observability/incident-drill/evidence/run2-slack/07-traffic-check.txt`: traffic by service; shows the monitoring gap from host Modern Standby (20:46:31–21:21:42 UTC per the Windows System log, with scrapes missing from about 20:57).

## Final validation

- `observability/final-validation.sh` writes `observability/incident-drill/evidence/final-validation.txt` (run 2026-10-28 21:52 UTC).
- That run found Grafana unready (2/3, 18 restarts) because of its 200m CPU / 256Mi limits. Fixed by raising them to 1000m / 512Mi in `kube-prometheus-stack-values.yaml` (kube-prometheus-stack revision 4, 21:53 UTC). The new pod was 3/3 Ready with 0 restarts.
- **Re-run 2026-10-28 23:07 UTC** (the file now holds this run):
  - Helm: robot-shop revision 12, kube-prometheus-stack revision 4 and my-vote-release revision 4, all `deployed`. No pod outside Running; Grafana 3/3, 0 restarts.
  - Prometheus: cart, catalogue, payment and web targets UP; both SLO rule groups ok.
  - SLI: error ratio 0, alert inactive, 24h budget remaining 0.77.
  - Slack notifications: 2. Jaeger: fresh multi-service traces. Capstone 1 unchanged.

## Screenshots

Status of every shot (captured or still needed) and how each was taken: [screenshots/README.md](screenshots/README.md).

## Delivery

All configuration, scripts, evidence and documents are committed and pushed to `https://github.com/dotmann-commits/robot-shop` (`master`). The Slack webhook lives only in the cluster Secret `robot-shop/alertmanager-slack-webhook`, never in Git.
