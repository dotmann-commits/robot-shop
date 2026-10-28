# Robot Shop Availability SLO

> Project-created document (not instructor-provided). Capstone 2, Step 5.

## Service and users

Robot Shop's browse-and-cart journey. A customer loads product categories and products (**catalogue**) and adds items to their basket (**cart**). Traffic comes from the in-cluster load generator (`load` deployment, 15 simulated clients).

## SLI: request availability

**Good events / valid events** over the window, where:

- **Valid event:** any HTTP request served by `cart` or `catalogue` in namespace `robot-shop` (metric `http_requests_total`, scraped every 15s).
- **Good event:** a valid event whose status is **not** 5xx. A 4xx such as "SKU not found" counts as good, because it is the client's error, not ours.

```promql
# error ratio (bad / valid), recorded as robotshop:availability_error_ratio:rate5m / rate1h / rate24h
sum(rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue", status=~"5.."}[5m]))
/
sum(rate(http_requests_total{namespace="robot-shop", service=~"cart|catalogue"}[5m]))
```

## SLO

**99% of cart and catalogue requests succeed over a rolling 24-hour window.**

The 24-hour window matches this lab's Prometheus retention (24h, `kube-prometheus-stack-values.yaml`). That makes the SLO fully measurable from data that actually exists. A production service would normally use 28 or 30 days.

## Error budget

- Budget = 1 − 0.99 = **1% of valid requests per 24h**.
- Baseline cart + catalogue traffic is about 7 req/s, roughly 600,000 requests a day. That allows about **6,000 failed requests a day**, or about **14.4 minutes of total outage**.
- Budget remaining: `robotshop:availability_error_budget_remaining:ratio24h` (1 = untouched, 0 = spent).

## Alert

`RobotShopAvailabilitySLOBurn` fires when the 5-minute error ratio stays above **5%** for **2 minutes**. That is a burn rate of 5×, which would spend the full day's budget in under 5 hours. Routing: Alertmanager → Slack (`observability/alerting/alertmanager-slack-config.yaml`). Runbook: [`observability/runbooks/robot-shop-availability-slo.md`](../runbooks/robot-shop-availability-slo.md).

## Exclusions and known limits

- **payment is excluded.** The load generator runs with `ERROR="1"` and deliberately posts to `/pay/partner-57`, which fails with HTTP 500. Those failures share the `/pay/:id` route label with real checkouts. Including payment would show about 47% "errors" that are synthetic by design.
- **Server-side measurement only.** If a service is completely down, it records no requests at all, so the SLI can under-count. Pod readiness and `up` should be watched alongside the SLI.
- **web (nginx)** is not in the SLI. Its exporter (`stub_status`) has no status-code breakdown.

## Error budget policy

See [error-budget-policy.md](error-budget-policy.md).
