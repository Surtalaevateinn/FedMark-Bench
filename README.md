# FedMark-Bench (Architect V6.0)

A High-Fidelity, Multi-Cluster Kubernetes Federation Benchmarking Framework.

## 🏗️ Architectural Topology
This project implements a **Dual-Cluster, Physically Isolated** infrastructure:
- **Host (Management Layer)**: `kind-karmada-host` cluster.
  - **Control Plane**: Karmada API Server & Scheduler.
  - **Worker Node**: Hosts the `karmada-controller-manager` and Monitoring stack (Prometheus/Grafana).
- **Member (Computing Layer)**: `kind-member-1` cluster.
  - **Topology**: Dual-node Kind setup (1 Master + 1 Worker).
  - **L1.5 Simulation**: 10 high-density simulated nodes via **KWOK**, injected with **32C/64G** profile.
- **Federation Mode**: **Push Mode** with automated TLS CA-injection and RBAC piercing.

---

## 📂 Repository Structure
```text
.
├── bootstrap/               # Infrastructure-as-Code (IaC)
│   ├── karmada/             # Federation policies (PropagationPolicy)
│   ├── monitoring/          # Observability stack (PodMonitors/Values)
│   └── nodes.yaml           # KWOK Simulated node blueprints
├── scripts/                 # Automation & Telemetry Suite
│   ├── resume.sh            # [V6.0] Self-Healing Engine (Auth Piercing)
│   ├── inspect-fed.sh       # [V5.1] Holistic Multi-Cluster Auditor
│   └── push_all.sh          # One-click Git synchronization
├── kind-config.yaml         # Host cluster physical specification
├── member-config.yaml       # Member cluster dual-node specification
└── nginx-deployment.yaml    # Core benchmarking resource template
🔄 Self-Healing & Recovery
The system is designed for deterministic recovery. After a VM reboot or cluster restart, execute:

Bash
# Executing the Auth-Piercing Resume Engine
./scripts/resume.sh
What V6.0 Resume does:

Nodes Alignment: Re-injects 32C/64G profiles into 10 KWOK nodes.

Auth Piercing: Automatically extracts Member-1 CA/Token and patches Host Secrets.

RBAC Alignment: Injects cluster-admin permissions for the Federation ServiceAccount.

Logic Pulse: Restarts Karmada controllers to flush stale TLS connections.

📊 Holistic Inspection
Use the architect's eye to audit the entire stack:

Bash
./scripts/inspect-fed.sh
Success Criteria:

Infrastructure: All Docker containers running with valid IPs.

Federation: member-1 status is READY: True.

Resources: KWOK nodes report 320 Cores total.

Workload: Nginx pods distributed across member-1-node-x.

🛠️ Access & Monitoring
Grafana Dashboard: kubectl config use-context kind-karmada-host && kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80 --address 0.0.0.0

Federated API: Use the K_CONFIG alias to interact with the global control plane:
export K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

⚖️ Philosophical Grounding
Deterministic Automation: Every authentication hurdle is solved by code, not manual intervention.

Risk Management: Physical isolation of management and compute resources prevents cascading failures.

Selective Acceptance: We value the system's ability to recover from a "Forbidden" or "Unauthorized" state through rigorous logic.

✅ Maintained by: Gemini-Architect-v6.0
