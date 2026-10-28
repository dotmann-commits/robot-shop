# Screenshots

> Project-created (not instructor-provided). Save the screenshots here with these names, so the links in `CAPSTONE2.md` and `SUBMISSION-EVIDENCE.md` resolve. Run `bash observability/port-forward-uis.sh` first.

| File | What it must show | Where |
|---|---|---|
| `01-pods-helm.png` | `kubectl get pods -A` and `helm list -A`, everything Running and deployed | terminal |
| `02-grafana-golden-signals.png` | Robot Shop Golden Signals with live data: requests, error ratio, latency | http://localhost:3000 → Dashboards → "Robot Shop — Golden Signals (Request Rate, Error Rate, Latency)" (last 30 min) |
| `03-grafana-drill-window.png` | Same dashboard over the drill (2026-10-28 19:45–21:00 UTC): two error spikes | Grafana time picker |
| `04-prometheus-targets.png` | Targets page with cart, catalogue, payment and web UP | http://localhost:9090/targets (filter "robot-shop") |
| `05-prometheus-rules.png` | `robot-shop-availability-slo` rule groups healthy | http://localhost:9090/rules |
| `06-prometheus-slo-graph.png` | `robotshop:availability_error_ratio:rate5m` across the drills | http://localhost:9090/graph |
| `07-loki-search.png` | Explore → Loki: `{namespace="robot-shop", service="catalogue", level="error"}` | Grafana Explore |
| `08-loki-no-instana.png` | `sum by (service) (count_over_time({namespace="robot-shop", service=~"cart\|catalogue"} \|= "Agent cannot be contacted" [5m]))` dropping to 0 after 21:45 UTC | Grafana Explore |
| `09-jaeger-trace-payment-cart.png` | A `payment` trace showing payment → cart spans | http://localhost:16686 |
| `10-jaeger-trace-cart-catalogue.png` | A `cart` trace showing cart → catalogue spans | http://localhost:16686 |
| `11-slack-firing.png` | Slack **[FIRING]** RobotShopAvailabilitySLOBurn (about 20:46 UTC) | Slack |
| `12-slack-resolved.png` | Slack **[RESOLVED]** message (about 20:52 UTC) | Slack |
| `13-alertmanager.png` (optional) | Alertmanager UI / receivers | http://localhost:9093 |
