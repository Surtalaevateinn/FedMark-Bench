# FedMark-Bench

A Multi-Dimensional Kubernetes Federation Benchmarking Environment.

## 🏗 Architecture Overview
This project implements a "Triple-Layer Nested" infrastructure:
- **L1 (Host)**: Managed via Kind (`member-1`).
- **L1.5 (Simulation)**: 10 high-density fake nodes via KWOK.
- **L2 (Federation)**: Karmada control plane orchestrating cross-cluster workloads.
- **L3 (Virtual)**: Tenant isolation using `vcluster` within the `v-space` namespace.

## 📂 Repository Structure
- `bootstrap/`: Core configuration for Karmada and Prometheus.
- `clusters/`: Kubeconfigs and cluster-specific metadata (Encrypted/Gitignored).
- `scripts/`: Automation for system recovery and workload generation.

## 🔄 Quick Start (Recovery)
After a VM reboot, ensure Docker is running and execute the master resume script:

```bash
./scripts/resume.sh
Important Note on Tunnels:
Due to the process-level nature of port-forwarding, the following tunnels must be maintained in separate terminal sessions:

API Tunnel (8443): Connects Karmada to the virtual cluster.

Grafana Tunnel (3000): Provides access to the Observability Dashboard.

📊 Monitoring
Access Grafana at http://localhost:3000 (Default Credentials: admin / admin).
Recommended Dashboard: Kubernetes / Compute Resources / Multi-Cluster.

⚖️ Identity & Philosophical Grounding
This project is part of a self-actualization journey towards becoming a Full-Stack Architect, emphasizing rigorous risk management and cross-ideological technical discernment.
