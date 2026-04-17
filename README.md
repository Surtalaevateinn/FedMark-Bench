# FedMark-Bench

A Multi-Dimensional Kubernetes Federation Benchmarking Environment.

## 🏗 Architecture Overview
This project implements a "Triple-Layer Nested" infrastructure:
- **L1 (Host)**: Managed via Kind (`member-1`).
- **L1.5 (Simulation)**: 10 high-density fake nodes via KWOK with injected 32C/64G resources.
- **L2 (Federation)**: Karmada control plane orchestrating workloads via Propagation Policies.
- **L3 (Virtual)**: Tenant isolation using `vcluster` within the `v-space` namespace.

---

## 🛠 Prerequisites & Dependencies
Before deployment, ensure the following software is installed on your Ubuntu VM:

### 1. Core Runtimes
* **Docker Engine**: The L0 runtime for all containers.
* **Go (Golang)**: Required if building components from source.

### 2. Command Line Tools (Binaries)
Ensure these are in your `$PATH`:
* **kubectl**: Standard Kubernetes CLI.
* **kind**: Kubernetes-in-Docker tool for L1 infrastructure.
* **karmadactl**: CLI for Karmada federation management.
* **vcluster**: CLI for managing virtual clusters.
* **helm**: Required for deploying Prometheus/Grafana stacks.

---

## 🔄 Fresh Deployment Guide
Follow these steps to build the environment from scratch on a new machine.

### Phase 1: Infrastructure Reconstruction
Build the L1 physical base and L1.5 simulation layer:

**1. Create L1 Physical Cluster (Fixed Port 39209)**
```bash
# Uses kind-config.yaml to prevent API port drift
kind create cluster --name member-1 --config kind-config.yaml --image kindest/node:v1.27.3
```

**2. Install KWOK Controller & Stages**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/kwok.yaml
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/stage-fast.yaml
```

### Phase 2: Federation & Logic Alignment
**1. Initialize Karmada Control Plane (L2)**
```bash
# Initialize the brain on the host
sudo ./karmadactl init --kubeconfig ${HOME}/.kube/config

# Align configuration for automation scripts
mkdir -p ${HOME}/karmada-config
sudo cp /etc/karmada/karmada-apiserver.config ${HOME}/karmada-config/
sudo chown $USER:$USER ${HOME}/karmada-config/karmada-apiserver.config
```

**2. Execute Master Self-Healing & Alignment**
```bash
chmod +x scripts/*.sh
./scripts/resume.sh
```

**3. Deploy L3 Virtual Cluster & Agents**
```bash
# Deploy Federation Agents
kubectl apply -f bootstrap/karmada/karmada-agent.yaml

# Deploy Virtual Cluster
kubectl create ns v-space
vcluster create v-space-0 -n v-space --connect=false
```

---

## 📊 Access & Monitoring
Maintain these tunnels in **separate terminals** to enable observability:

**Terminal A: Grafana Dashboard**
```bash
# Access via http://localhost:3000 (admin/admin)
kubectl port-forward -n monitoring svc/prometheus-stack-grafana --address 0.0.0.0 3000:80
```

**Terminal B: vcluster API Tunnel**
```bash
# Required for L2-to-L3 communication
kubectl port-forward -n v-space pod/v-space-0-0 --address 0.0.0.0 8443:8443
```

---

## ✅ Final Architectural Audit
Verify the "Golden State" using the telemetry script:
```bash
./scripts/check_status.sh
```
**Expected Success Criteria:**
- **Nodes Ready**: 10/10 with 32C/64G resources injected.
- **Workload**: 50/50 Nginx Pods Running across simulated nodes.
- **Federation**: Status True (member-1 connected).

---

⚖️ **Identity & Philosophical Grounding**: Emphasizing rigorous risk management, deterministic automation, and the self-actualization of a Full-Stack Architect.
