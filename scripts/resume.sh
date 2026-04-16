#!/bin/bash
# FedMark Infrastructure Resume Script V4.1 - Observability Aware
# Guiding Principle: Immutable Infrastructure & Self-Healing Architecture.

echo "🚀 Starting Full FedMark Infrastructure Recovery (V4.1)..."

# --- Step 0: Clear Finalizer Deadlocks ---
echo "--- Step 0: Clearing Namespace Deadlocks ---"
for ns in fed-workload karmada-system; do
  if kubectl get ns $ns 2>/dev/null | grep -q "Terminating"; then
    echo "🧹 Scrubbing finalizers from $ns..."
    kubectl get ns $ns -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/$ns/finalize -f - 2>/dev/null
  fi
done

# --- Step 1: KWOK Infrastructure Realignment ---
echo "--- Step 1: Aligning Simulated Nodes & KWOK Stages ---"
if [ -f bootstrap/nodes.yaml ]; then
    kubectl apply -f bootstrap/nodes.yaml
    echo "✅ Nodes definition applied from bootstrap/nodes.yaml."
fi

kubectl apply -f - <<STAGE_EOF
apiVersion: kwok.x-k8s.io/v1alpha1
kind: Stage
metadata:
  name: node-ready
spec:
  resourceRef:
    kind: Node
    apiVersion: v1
  selector:
    matchAnnotations:
      kwok.x-k8s.io/node: fake
  next:
    statusTemplate: |
      conditions:
        - type: Ready
          status: "True"
          reason: "KubeletReady"
          message: "kwok-controller is simulating a healthy node"
STAGE_EOF

echo "🧹 Cleansing NoSchedule taints from simulated nodes..."
for i in {1..10}; do
  kubectl taint nodes member-1-node-$i kwok.x-k8s.io/node- 2>/dev/null
  kubectl patch node member-1-node-$i --subresource=status -p '{
    "status": {
      "allocatable": {"cpu": "32", "memory": "64Gi", "pods": "110"},
      "capacity": {"cpu": "32", "memory": "64Gi", "pods": "110"}
    }
  }' 2>/dev/null
done
echo "✅ 10 Simulated Nodes Ready & Resources Patched."

# --- Step 2: Federation Command Chain Recovery ---
echo "--- Step 2: Fixing Federation Connectivity ---"
MEMBER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' member-1-control-plane 2>/dev/null)
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

if ! kubectl $K_CONFIG get cluster member-1 2>/dev/null | grep -q "True"; then
    echo "⚠️  Federation link broken or IP shifted. Re-aligning to $MEMBER_IP..."
    cp ~/.kube/config ~/member-1-internal.config
    sed -i "s|https://127.0.0.1:[0-9]*|https://$MEMBER_IP:6443|g" ~/member-1-internal.config
    karmadactl unjoin member-1 $K_CONFIG 2>/dev/null
    karmadactl join member-1 --cluster-kubeconfig ~/member-1-internal.config $K_CONFIG
    echo "✅ Federation link re-established via Internal IP."
fi

# --- Step 3: Workload Rescheduling ---
echo "--- Step 3: Triggering Workload Rescheduling ---"
kubectl $K_CONFIG rollout restart deployment nginx-fed -n fed-workload 2>/dev/null

# --- Step 4: Observability Alignment (New in V4.1) ---
# 确保 Prometheus PodMonitor 始终存在，以解决 Grafana "No Data" 问题
echo "--- Step 4: Re-applying Observability Config ---"
if [ -f bootstrap/monitoring/fed-pod-monitor.yaml ]; then
    kubectl apply -f bootstrap/monitoring/fed-pod-monitor.yaml
    echo "✅ PodMonitor applied for fed-workload tracking."
fi

# --- Step 5: Environment Alias ---
if ! grep -q "alias kfed=" ~/.bashrc; then
    echo "alias kfed='kubectl $K_CONFIG'" >> ~/.bashrc
    echo "✅ Alias 'kfed' added to .bashrc."
fi

echo "🌟 System Resume Complete."
./scripts/check_status.sh
