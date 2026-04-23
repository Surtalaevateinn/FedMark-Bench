# FedMark-Bench

A High-Reliability Multi-Cluster Kubernetes Federation Benchmarking Environment.

## 🏗 Architecture Overview
This project implements a "Decoupled Management & Computing" infrastructure:
- **L1 (Infrastructure)**: Dual-cluster setup using Kind.
    - `kind-karmada-host`: Management cluster hosting the observability stack and federation brain.
    - `kind-member-1`: Execution cluster with dedicated control-plane and worker nodes.
- **L1.5 (Simulation)**: 10 high-density fake nodes via KWOK on `member-1`, injecting 320C/640G total virtual resources.
- **L2 (Federation)**: Karmada control plane in **Push Mode**, using automated CA/Token injection for secure cross-cluster orchestration.
- **L3 (Monitoring)**: Prometheus/Grafana stack isolated on the Host control-plane to prevent resource contention.

---

## 📂 Repository Structure
```text
.
├── bootstrap/               # Infrastructure-as-Code (IaC) definitions
│   ├── karmada/             # Federation policies and resource templates
│   ├── monitoring/          # Observability (Prometheus/Grafana) configurations
│   └── nodes.yaml           # KWOK simulated node blueprints
├── scripts/                 # Automation & Architect's Toolkit
│   ├── resume.sh            # V10.0: Automated auth piercing & self-healing
│   ├── inspect-fed.sh       # V5.1: Cross-context multi-dimensional auditor
│   └── push_all.sh          # One-click repository synchronization
├── host-config.yaml         # Topology for the Federation Host cluster
├── member-config.yaml       # Topology for the Member Execution cluster
└── nginx-deployment.yaml    # Standard benchmarking workload template
```


---

## 🛠 Bootstrap & Installation (Full Setup)
Before running recovery scripts, the physical and component foundations must be established.

### Phase 0: Physical Infrastructure
Create the underlying Kind clusters:
```bash
kind create cluster --name karmada-host --config host-config.yaml
kind create cluster --name member-1 --config member-config.yaml
```

### Phase 1: Simulation Base (KWOK)
Install KWOK controllers and CRDs onto the execution cluster to enable 320C simulation:
```bash
kubectl config use-context kind-member-1
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/kwok.yaml
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/stage-fast.yaml
```

### Phase 2: Federation Brain (Karmada)
Initialize the federation control plane on the host cluster:
```bash
kubectl config use-context kind-karmada-host
sudo ./karmadactl init --kubeconfig ${HOME}/.kube/config

# Export Federation Config for scripts
mkdir -p ${HOME}/karmada-config
sudo cp /etc/karmada/karmada-apiserver.config ${HOME}/karmada-config/
sudo chown $USER:$USER ${HOME}/karmada-config/karmada-apiserver.config
```

### Phase 3: Observability Stack (Helm)
Deploy the monitoring engine on the Host cluster:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f bootstrap/monitoring/prometheus-values.yaml
```

---

## 🔄 Infrastructure Recovery & Alignment
The environment is designed for deterministic recovery after VM reboots or logic drift using the V10.0 "Auth-Piercing" logic.

### Step 1: Context Alignment
Ensure your local `kubeconfig` has access to both clusters:
```bash
kind export kubeconfig --name karmada-host
kind export kubeconfig --name member-1
```


### Step 2: Master Self-Healing
Execute the architect's engine to align nodes, inject certificates, and repair RBAC:
```bash
chmod +x scripts/*.sh
./scripts/resume.sh
```


---

## 📊 Monitoring & Audit
### Holistic Health Check
Run the cross-cluster inspector to verify the state of Docker, KWOK, Karmada, and Workloads:
```bash
./scripts/inspect-fed.sh
```


### Observability Access
Maintain the following tunnel in a separate terminal:
* **Grafana**: `kubectl config use-context kind-karmada-host && kubectl port-forward -n monitoring svc/prometheus-stack-grafana --address 0.0.0.0 3000:80` (Default: `admin/admin`)

---

## ✅ Success Criteria (Success Audit)
- **Federation**: `kubectl get cluster` returns `READY: True`.
- **Simulation**: 10 KWOK nodes show `32C/64G` allocatable resources through the federation proxy.
- **Workload**: `nginx-fed` Pods are successfully distributed across `member-1-node-x`.
- **Security**: Aggregated APIService `AVAILABLE` is `True` via front-proxy-ca alignment.

---

⚖️ **Identity**: This framework is built on the principles of rigorous risk management and the rejection of manual drift in favor of deterministic automation.
