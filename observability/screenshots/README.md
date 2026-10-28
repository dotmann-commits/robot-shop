# Screenshots

> Project-created (not instructor-provided). Run `bash observability/port-forward-uis.sh` first. Times are UTC on 2026-10-28.

**How they were captured:** shots 04, 05, 06, 09 and 10 are headless Microsoft Edge screenshots of the live UIs through the port-forwards (about 21:59–22:01). Shot 01 is live `kubectl`/`helm` output rendered to a page and captured at 22:01:10; it is labeled as a rendering, not a terminal window. The Grafana shots need a Grafana login and the Slack shots need the Slack workspace, so the author captures those by hand.

| File | Shows | Status |
|---|---|---|
| `01-pods-helm.png` | `helm list -A` (3 releases deployed) and `kubectl get pods -A` (all Running, Grafana 3/3) | ✅ captured |
| `02-grafana-golden-signals.png` | "Robot Shop — Golden Signals (Request Rate, Error Rate, Latency)", last 30 min in UTC, about 23:40: all four targets UP, request rates by service and route, 5xx panels (those include payment's deliberate load-generator errors). The flat gap from about 23:12 to 23:28 is host Modern Standby (Windows System log: 23:11:40 to 23:28:27 UTC), not a service fault | ✅ captured by the author |
| `02b-grafana-errors-latency.png` | Lower half of the same dashboard (last 30 min, UTC): 5xx rate and ratio by service, with **cart and catalogue at 0%** and only payment showing errors (about 49% mean, its deliberate load-generator `ERROR="1"` traffic, outside the SLO); p95 and p50/p95/p99 latency. The latency spike at about 23:29 follows the host waking from standby at 23:28:27 | ✅ captured by the author |
| `03-grafana-drill-window.png` | Same dashboard, time range 19:45–21:00: two error spikes (drills about 19:53 and 20:40) | ⬜ author |
| `04-prometheus-targets.png` | Targets: cart, catalogue, payment (robot-shop-app-services 3/3) and web (robot-shop-web-nginx 1/1) all UP | ✅ captured |
| `05-prometheus-rules.png` | `robot-shop-availability-slo.alerts` and `.recording` groups, all rules OK | ✅ captured |
| `06-prometheus-slo-graph.png` | `robotshop:availability_error_ratio:rate5m` 19:00–22:00: two drill spikes to 1.0, recovery to 0, and the host-sleep gap at about 20:57–21:21 | ✅ captured |
| `07-loki-search.png` | Explore → Loki: `{namespace="robot-shop", service="catalogue", level="error"}` | ⬜ author |
| `08-loki-no-instana.png` | Explore → Loki, last 1h: `sum by (service) (count_over_time({namespace="robot-shop", service=~"cart\|catalogue"} \|= "Agent cannot be contacted" [5m]))` dropping to 0 after 21:45 | ⬜ author |
| `09-jaeger-trace-payment-cart.png` | Trace `659e8bf`: payment `POST /pay/:id` → user, paypal, RabbitMQ publish, payment `DELETE` → cart (2 services, 6 spans) | ✅ captured |
| `10-jaeger-trace-cart-catalogue.png` | Trace `bd474a3`: cart `GET /add/:id/:sku/:qty` → catalogue `GET /product/:sku` (2 services, 3 spans) | ✅ captured |
| `11-slack-firing.jpg` | Slack #tickets, "Robot Shop DevOps Alerts" app, 20:45: **[FIRING]** RobotShopAvailabilitySLOBurn (critical), 100%, runbook link, started 20:45:21.724 UTC | ✅ captured by the author (Slack mobile app) |
| `12-slack-resolved.jpg` | Same thread, 20:51: **[RESOLVED]**. The 5.428% shown is the alert's last value while firing, which Alertmanager repeats in the resolved notice; it is not the error rate at recovery (see the postmortem) | ✅ captured by the author (Slack mobile app) |

The optional Alertmanager shot was left out on purpose: its Status page prints the full config, including the Slack receiver.

**Grafana time zone:** set the dashboard time zone to UTC (Dashboard settings → Time zone) so the times match the evidence logs.
