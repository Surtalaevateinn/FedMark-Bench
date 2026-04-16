# FedMark-Bench

A Multi-Dimensional Kubernetes Federation Benchmarking Environment.

## 🏗 Architecture Overview
This project implements a "Triple-Layer Nested" infrastructure:
- **L1 (Host)**: Managed via Kind (`member-1`).
- **L1.5 (Simulation)**: 10 high-density fake nodes via KWOK with injected 32C/64G resources.
- **L2 (Federation)**: Karmada control plane orchestrating workloads via Propagation Policies.
- **L3 (Virtual)**: Tenant isolation using `vcluster` within the `v-space` namespace.

## 📂 Repository Structure
- `bootstrap/`:
    - `karmada/`: Agents and **Propagation Policies** (`nginx-propagation.yaml`).
    - `monitoring/`: Prometheus and PodMonitor configurations.
    - `nodes.yaml`: Declarative node definitions.
- `scripts/`: Automation for system recovery (`resume.sh`) and status auditing.

## 🔄 Quick Start (Recovery)
After a VM reboot, execute the master resume script to realign all layers:

```bash
./scripts/resume.sh
```

## 📊 Monitoring
- Access Grafana: `http://localhost:3000` (admin/admin).
- Metrics: Real-time tracking of 50+ federated pods across simulated nodes.

⚖️ Identity & Philosophical Grounding: Emphasizing rigorous risk management and the self-actualization of a Full-Stack Architect.
