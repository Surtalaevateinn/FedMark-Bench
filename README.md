# FedMark-Bench

A Multi-Dimensional Kubernetes Federation Benchmarking Environment.

## 🏗 Architecture Overview
This project implements a "Triple-Layer Nested" infrastructure:
- **L1 (Host)**: Managed via Kind (`member-1`).
- **L1.5 (Simulation)**: 10 high-density fake nodes via KWOK with injected 32C/64G resources.
- **L2 (Federation)**: Karmada control plane orchestrating workloads via Propagation Policies.
- **L3 (Virtual)**: Tenant isolation using `vcluster` within the `v-space` namespace.

---

## 📂 Repository Structure
```text
.
├── bootstrap/               # Infrastructure-as-Code (IaC) definitions
│   ├── karmada/             # L2 Federation policies and agents
│   ├── monitoring/          # Observability stack configurations
│   └── nodes.yaml           # L1.5 Simulated node blueprints
├── clusters/                # Cluster-specific credentials and metadata
├── scripts/                 # Automation and Telemetry suite
├── kind-config.yaml         # L1 Physical cluster specification
└── nginx-deployment.yaml    # Core benchmarking workload
```

### Key Files Definition
* **`kind-config.yaml`**: The "Physical Anchor." It fixes the API Server port to **39209** to prevent networking drift.
* **`bootstrap/nodes.yaml`**: The "Birth Certificate" for simulated nodes, defining labels and annotations for KWOK.
* **`bootstrap/karmada/nginx-propagation.yaml`**: The "Conductor's Baton." Defines the L2 policy for distributing workloads to member clusters.
* **`scripts/resume.sh`**: The "Self-Healing Engine." Automates the realignment of all architectural layers.
* **`scripts/check_status.sh`**: The "Architect's Eye." Provides a holistic audit of the environment's health.

---

## 🛠 Prerequisites & Dependencies
Ensure the following software is installed on your Ubuntu VM:
* **Runtimes**: Docker Engine (L0), Go (Golang).
* **Binaries**: `kubectl`, `kind`, `karmadactl`, `vcluster`, `helm`.

---

## 🔄 Fresh Deployment Guide
### Phase 1: Infrastructure Reconstruction
Build the L1 base and L1.5 simulation layer:
```bash
# 1. Create L1 Cluster with Fixed Port 39209
kind create cluster --name member-1 --config kind-config.yaml --image kindest/node:v1.27.3

# 2. Install KWOK Controller
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/kwok.yaml
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/stage-fast.yaml
```

### Phase 2: Federation & Logic Alignment
```bash
# 1. Initialize Karmada Control Plane
sudo ./karmadactl init --kubeconfig ${HOME}/.kube/config

# 2. Align configuration for automation
mkdir -p ${HOME}/karmada-config
sudo cp /etc/karmada/karmada-apiserver.config ${HOME}/karmada-config/
sudo chown $USER:$USER ${HOME}/karmada-config/karmada-apiserver.config

# 3. Execute Master Self-Healing & Alignment
chmod +x scripts/*.sh
./scripts/resume.sh

# 4. Deploy vcluster and Federation Agents
kubectl apply -f bootstrap/karmada/karmada-agent.yaml
kubectl create ns v-space
vcluster create v-space-0 -n v-space --connect=false
```

---

## 📊 Access & Monitoring
Maintain these tunnels in **separate terminals**:
* **Grafana Dashboard**: `kubectl port-forward -n monitoring svc/prometheus-stack-grafana --address 0.0.0.0 3000:80`.
* **vcluster API**: `kubectl port-forward -n v-space pod/v-space-0-0 --address 0.0.0.0 8443:8443`.

---

## ✅ Final Architectural Audit
```bash
./scripts/check_status.sh
```
**Success Criteria:**
- **Nodes Ready**: 10/10 with 32C/64G resources injected.
- **Workload**: 50/50 Nginx Pods Running.
- **Federation**: Status True.

---

⚖️ **Identity & Philosophical Grounding**: Emphasizing rigorous risk management, deterministic automation, and the self-actualization of a Full-Stack Architect.
