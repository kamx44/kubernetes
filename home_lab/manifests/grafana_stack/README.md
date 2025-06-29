1. Prerequisites ✅
Ensure you have:

A working Kubernetes cluster on Proxmox (e.g. k3s, microk8s, kubeadm).

kubectl configured.

Helm 3 installed.

2. Create a Monitoring Namespace
bash
Kopiuj
Edytuj
kubectl create namespace monitoring
This keeps everything tidy and scoped. 
signoz.io
+14
medium.com
+14
medium.com
+14
signoz.io
+1
bigbinary.com
+1

3. Install Prometheus using Helm
bash
Kopiuj
Edytuj
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring
This deploys Prometheus, Alertmanager, node exporters, etc. 
spacelift.io

Verify:

bash
Kopiuj
Edytuj
kubectl get pods,svc -n monitoring
Access Prometheus dashboard:

bash
Kopiuj
Edytuj
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
Then visit http://localhost:9090 in your browser. 
betterstack.com

4. Install Grafana using Helm
bash
Kopiuj
Edytuj
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana --namespace monitoring
(Or use prometheus-community/grafana chart) 
grafana.com
+15
grafana.com
+15
betterstack.com
+15

Get admin password & access Grafana:

bash
Kopiuj
Edytuj
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" \
  | base64 --decode
kubectl port-forward svc/grafana -n monitoring 3000:80
Log in at http://localhost:3000 with admin and the above password. 
betterstack.com

5. Connect Grafana to Prometheus
From Grafana UI, go to Configuration → Data Sources → Add Prometheus.

Set the URL to either:

http://prometheus-server.monitoring.svc.cluster.local:80 (in-cluster), or

http://localhost:9090 (via port-forward).

Click Save & Test. 
signoz.io
+12
betterstack.com
+12
grafana.com
+12
spacelift.io

6. Import a Pre-built Dashboard
In Grafana, go to Dashboards → Import.

You could use template ID 1860 (official Kubernetes overview) or similar.

Select the Prometheus data source and click Import. 
medium.com
+7
betterstack.com
+7
grafana.com
+7

You'll now see visualizations for CPU, memory, pod usage, etc.

7. Try a Demo PromQL Query
In the Prometheus web UI under Graph, try:

arduino
Kopiuj
Edytuj
sum(rate(container_cpu_usage_seconds_total{image!="",container!="POD"}[5m])) by (namespace)
This shows CPU usage across namespaces in the last 5 minutes. You’ll see results plotted for your cluster.

8. (Optional) Custom Metrics & Grafana Agent
If you want to scrape metrics from custom pods, deployments, or services, either:

Edit Prometheus Helm values (values.yaml) to add extra scrape_configs,

Or use the Grafana Agent Flow, which is lightweight and flexible 
optiapm.com
en.wikipedia.org
getambassador.io
betterstack.com
+3
grafana.com
+3
spacelift.io
+3
.

E.g.:

yaml
Kopiuj
Edytuj
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: 'my-app'
        static_configs:
          - targets: ['my-app-service.default.svc.cluster.local:9102']
Recap of Commands
bash
Kopiuj
Edytuj
kubectl create namespace monitoring

# Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus --namespace monitoring
kubectl port-forward svc/prometheus-server -n monitoring 9090:80

# Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana --namespace monitoring
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode
kubectl port-forward svc/grafana -n monitoring 3000:80
