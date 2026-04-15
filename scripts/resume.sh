#!/bin/bash
# FedMark Infrastructure Resume Script V3.2
# Guiding Principle: Total Control - From Simulation Resources to Federation.

echo "🚀 Starting FedMark Infrastructure Recovery (V3.2)..."

# --- Step 1: KWOK & Resource Injection ---
echo "--- Step 1: Activating Simulated Nodes & Injecting Resources ---"
kubectl apply -f - <<STAGE_EOF
apiVersion: kwok.x-k8s.io/v1alpha1
kind: Stage
metadata:
  name: node-ready
spec:
  resourceRef:
    kind: Node
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

# 关键更新：批量注入虚拟资源，确保调度器不会盲目
for i in {1..10}; do
  kubectl patch node member-1-node-$i --subresource=status -p '{
    "status": {
      "allocatable": {"cpu": "32", "memory": "64Gi", "pods": "110"},
      "capacity": {"cpu": "32", "memory": "64Gi", "pods": "110"}
    }
  }'
done
echo "✅ 10 Simulated Nodes patched with 32C/64G resources."

# --- Step 2: Dynamic Network Fix ---
echo "--- Step 2: Fixing Container-to-Host Networking ---"
DOCKER_BRIDGE_IP=$(ip addr show docker0 | grep -Po 'inet \K[\d.]+' || echo "172.17.0.1")
if [ -f ~/v-space-internal.config ]; then
    sed -i "s/127.0.0.1/$DOCKER_BRIDGE_IP/g" ~/v-space-internal.config
    echo "✅ v-space-internal.config updated with Bridge IP: $DOCKER_BRIDGE_IP"
fi

# --- Step 3: Federation & Alias ---
echo "--- Step 3: Re-aligning Karmada & Setting Alias ---"
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

# 自动注入别名到 bashrc (如果不存在)
if ! grep -q "alias kfed=" ~/.bashrc; then
    echo "alias kfed='kubectl $K_CONFIG'" >> ~/.bashrc
    echo "✅ Alias 'kfed' added to .bashrc"
fi

READY_STATUS=$(kubectl $K_CONFIG get cluster v-cluster -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [ "$READY_STATUS" != "True" ]; then
    echo "⚠️ v-cluster not ready. Re-joining..."
    karmadactl unjoin v-cluster $K_CONFIG
    karmadactl join v-cluster --cluster-kubeconfig ~/v-space-internal.config $K_CONFIG
    echo "✅ Federation re-joined."
else
    echo "✅ Federation already healthy."
fi

echo "--- Final Instructions ---"
echo "Terminal A: kubectl port-forward -n v-space pod/v-space-0 --address 0.0.0.0 8443:8443"
echo "Terminal B: kubectl port-forward -n monitoring svc/prometheus-stack-grafana --address 0.0.0.0 3000:80"
echo "🌟 System Resume Complete. Use 'source ~/.bashrc' to activate kfed."
