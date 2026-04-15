#!/bin/bash

# FedMark Infrastructure Resume Script V2.1
# Guiding Principle: Dynamic Network Adaptation & Automated Recovery.

echo "🚀 Starting FedMark Infrastructure Recovery..."

# --- Step 1: Activating Simulated Nodes ---
echo "--- Step 1: Activating Simulated Nodes ---"
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

kubectl rollout restart deployment kwok-controller -n kube-system
echo "✅ Stage applied and KWOK controller restarted."

# --- Step 2: Dynamic Network Fix ---
echo "--- Step 2: Fixing Container-to-Host Networking ---"
# 自动获取 Docker 网桥 IP (默认为 172.17.0.1)
DOCKER_BRIDGE_IP=$(ip addr show docker0 | grep -Po 'inet \K[\d.]+' || echo "172.17.0.1")
echo "🔗 Detected Docker Bridge IP: $DOCKER_BRIDGE_IP"

# 动态洗白 v-cluster 配置，确保联邦大脑指向宿主机 IP 而非容器回环
if [ -f ~/v-space-internal.config ]; then
    sed -i "s/127.0.0.1/$DOCKER_BRIDGE_IP/g" ~/v-space-internal.config
    echo "✅ v-space-internal.config updated with Bridge IP."
fi

# --- Step 3: Federation Realignment ---
echo "--- Step 3: Re-aligning Karmada Federation ---"
# 设置临时变量方便脚本内部调用
K_CONFIG="--kubeconfig ~/karmada-config/karmada-apiserver.config"

# 检查 v-cluster 状态 (增加容错判断)
READY_STATUS=$(kubectl $K_CONFIG get cluster v-cluster -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

if [ "$READY_STATUS" != "True" ]; then
    echo "⚠️ v-cluster not ready. Re-joining..."
    karmadactl unjoin v-cluster $K_CONFIG
    karmadactl join v-cluster \
      --cluster-kubeconfig ~/v-space-internal.config \
      $K_CONFIG
    echo "✅ Federation re-joined."
else
    echo "✅ Federation already healthy."
fi

echo "--- Final Instructions ---"
echo "📍 Please open two new terminals for Port-Forwarding (Crucial for V2.1):"
echo "Terminal A: kubectl port-forward -n v-space pod/v-space-0 --address 0.0.0.0 8443:8443"
echo "Terminal B: kubectl port-forward -n monitoring svc/prometheus-stack-grafana --address 0.0.0.0 3000:80"
echo "🌟 System Resume Complete."
