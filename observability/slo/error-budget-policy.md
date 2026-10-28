# Error Budget Policy: Robot Shop Availability

> Project-created one-page policy (not instructor-provided). Applies to the SLO in [robot-shop-availability-slo.md](robot-shop-availability-slo.md): 99% of cart and catalogue requests succeed over a rolling 24h window.

## Purpose

The error budget (1% of requests, about 14 minutes of full outage per day) is how much unreliability we accept. This policy sets what the team does as the budget is used up. Decisions follow the measured number, not opinion.

## Measurement

- Budget remaining: `robotshop:availability_error_budget_remaining:ratio24h`, reviewed on the **Robot Shop Golden Signals** dashboard.
- Fast-burn page: `RobotShopAvailabilitySLOBurn` → Slack, with a runbook linked.

## Policy by budget remaining

| Budget remaining (24h) | State | What we do |
|---|---|---|
| **> 50%** | Healthy | Normal delivery. Releases, config changes and experiments (including chaos drills) are allowed. |
| **25–50%** | Caution | Releases continue, but each change needs a tested rollback (`helm rollback`) and someone watching the dashboard for 15 minutes afterwards. No planned drills. |
| **0–25%** | At risk | Only fixes and reliability work. Feature changes wait. Investigate the top error source (service, route, status). |
| **Exhausted (≤ 0%)** | Frozen | Change freeze for the rest of the window, except fixes that reduce errors. Write a postmortem for any single incident that used more than 20% of the budget. |

## When the alert fires

1. The on-call engineer acknowledges in Slack and follows the linked runbook.
2. **Mitigate first** (scale back, restart, roll back), then find the root cause.
3. Note start, detection, mitigation and recovery times as they happen.
4. Write a blameless postmortem within 2 working days if the incident used more than 20% of the daily budget or lasted more than 15 minutes.

## Exceptions

- **Planned drills** count against the budget. They may only run when the budget is above 50%, and must be announced beforehand.
- **Synthetic payment errors** from the load generator (`ERROR="1"`) are outside this SLO and never trigger this policy.
- Failures caused by the lab platform itself (Kind or WSL restarts, laptop sleep) are recorded but may be excluded after review.

## Ownership and review

- **Owner:** Robot Shop team (capstone author).
- **Review:** after every incident or drill, and whenever the SLO, the SLI query or the load profile changes.
