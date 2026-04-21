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
.
├── bootstrap/               # Infrastructure-as-Code (IaC) definitions
│   ├── karmada/             # Federation policies and resource templates
│   ├── monitoring/          # Observability (Prometheus/Grafana) configurations
│   └── nodes.yaml           # KWOK simulated node blueprints
├── scripts/                 # Automation & Architect's Toolkit
│   ├── resume.sh            # V6.0: Automated auth piercing & self-healing
│   ├── inspect-fed.sh       # V5.1: Cross-context multi-dimensional auditor
│   └── push_all.sh          # One-click repository synchronization
├── host-config.yaml         # Topology for the Federation Host cluster
├── member-config.yaml       # Topology for the Member Execution cluster
└── nginx-deployment.yaml    # Standard benchmarking workload template

---

## 🔄 Infrastructure Recovery & Alignment
The environment is designed for deterministic recovery after VM reboots using the V6.0 "Auth-Piercing" logic.

### Phase 1: Context Alignment
Ensure your local `kubeconfig` has access to both clusters:
kind export kubeconfig --name karmada-host
kind export kubeconfig --name member-1

### Phase 2: Master Self-Healing
Execute the architect's engine to align nodes, inject certificates, and repair RBAC:
chmod +x scripts/*.sh
./scripts/resume.sh

---

## 📊 Monitoring & Audit
### Holistic Health Check
Run the cross-cluster inspector to verify the state of Docker, KWOK, Karmada, and Workloads:
./scripts/inspect-fed.sh

### Observability Access
Maintain the following tunnel in a separate terminal:
* **Grafana**: `kubectl config use-context kind-karmada-host && kubectl port-forward -n monitoring svc/prometheus-stack-grafana --address 0.0.0.0 3000:80`

---

## ✅ Success Criteria (Success Audit)
- **Federation**: `kubectl get cluster` returns `READY: True`.
- **Simulation**: 10 KWOK nodes show `32C/64G` allocatable resources.
- **Workload**: `nginx-fed` Pods are successfully distributed across `member-1-node-x`.
- **Security**: TLS `caBundle` and ServiceAccount `Token` are dynamically synchronized.

---

⚖️ **Identity**: This framework is built on the principles of rigorous risk management and the rejection of manual drift in favor of deterministic automation.
