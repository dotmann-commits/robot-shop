# Screenshots

> Project-created (not instructor-provided). Run `bash observability/port-forward-uis.sh` first. Times are UTC on 2026-10-28.

**How they were captured:** shots 04, 05, 06, 09 and 10 are headless Microsoft Edge screenshots of the live UIs through the port-forwards (about 21:59–22:01). Shot 01 is live `kubectl`/`helm` output rendered to a page and captured at 22:01:10; it is labeled as a rendering, not a terminal window. The Grafana shots need a Grafana login and the Slack shots need the Slack workspace, so the author captures those by hand.

| File | Shows | Status |
|---|---|---|
| `01-pods-helm.png` | `helm list -A` (3 releases deployed) and `kubectl get pods -A` (all Running, Grafana 3/3) | ✅ captured |
| `02-grafana-golden-signals.png` | "Robot Shop — Golden Signals (Request Rate, Error Rate, Latency)" with live data, last 30 min | ⬜ author: http://localhost:3000 |
| `03-grafana-drill-window.png` | Same dashboard, time range 19:45–21:00: two error spikes (drills about 19:53 and 20:40) | ⬜ author |
| `04-prometheus-targets.png` | Targets: cart, catalogue, payment (robot-shop-app-services 3/3) and web (robot-shop-web-nginx 1/1) all UP | ✅ captured |
| `05-prometheus-rules.png` | `robot-shop-availability-slo.alerts` and `.recording` groups, all rules OK | ✅ captured |
| `06-prometheus-slo-graph.png` | `robotshop:availability_error_ratio:rate5m` 19:00–22:00: two drill spikes to 1.0, recovery to 0, and the host-sleep gap at about 20:57–21:21 | ✅ captured |
| `07-loki-search.png` | Explore → Loki: `{namespace="robot-shop", service="catalogue", level="error"}` | ⬜ author |
| `08-loki-no-instana.png` | Explore → Loki, last 1h: `sum by (service) (count_over_time({namespace="robot-shop", service=~"cart\|catalogue"} \|= "Agent cannot be contacted" [5m]))` dropping to 0 after 21:45 | ⬜ author |
| `09-jaeger-trace-payment-cart.png` | Trace `659e8bf`: payment `POST /pay/:id` → user, paypal, RabbitMQ publish, payment `DELETE` → cart (2 services, 6 spans) | ✅ captured |
| `10-jaeger-trace-cart-catalogue.png` | Trace `bd474a3`: cart `GET /add/:id/:sku/:qty` → catalogue `GET /product/:sku` (2 services, 3 spans) | ✅ captured |
| `11-slack-firing.png` | Slack **[FIRING]** RobotShopAvailabilitySLOBurn (about 20:46) | ⬜ author: Slack |
| `12-slack-resolved.png` | Slack **[RESOLVED]** (about 20:52) | ⬜ author: Slack |

The optional Alertmanager shot was left out on purpose: its Status page prints the full config, including the Slack receiver.

**Grafana time zone:** set the dashboard time zone to UTC (Dashboard settings → Time zone) so the times match the evidence logs.
