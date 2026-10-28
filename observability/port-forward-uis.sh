#!/usr/bin/env bash
# Project-Created File (NOT Instructor-Provided)
# Expose the monitoring UIs on localhost for demos and screenshots. Ctrl+C stops all forwards.
#   Grafana      http://localhost:3000   (admin password: kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d)
#   Prometheus   http://localhost:9090
#   Alertmanager http://localhost:9093
#   Jaeger       http://localhost:16686
#   Robot Shop   http://localhost:8080   (web Service is type LoadBalancer; its external IP stays <pending> on Kind)
trap 'kill 0' EXIT
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
kubectl -n monitoring port-forward svc/kp-stack-prometheus 9090:9090 &
kubectl -n monitoring port-forward svc/kp-stack-alertmanager 9093:9093 &
kubectl -n monitoring port-forward svc/jaeger-query 16686:16686 &
kubectl -n robot-shop port-forward svc/web 8080:8080 &
wait
