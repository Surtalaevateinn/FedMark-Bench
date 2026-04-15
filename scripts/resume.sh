#!/bin/bash

# FedMark Infrastructure Resume Script V2.0
# Guiding Principle: Balance automation with structural integrity.

echo "🚀 Starting FedMark Infrastructure Recovery..."

# 1. Physical Layer & KWOK Activation
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

# 2. Federation Realignment
echo "--- Step 2: Re-aligning Karmada Federation ---"
alias k-fed='kubectl --kubeconfig ~/karmada-config/karmada-apiserver.config'

# Check if v-cluster is already ready
READY_STATUS=$(kubectl --kubeconfig ~/karmada-config/karmada-apiserver.config get cluster v-cluster -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

if [ "$READY_STATUS" != "True" ]; then
    echo "⚠️ v-cluster not ready. Re-joining..."
    karmadactl unjoin v-cluster --kubeconfig ~/karmada-config/karmada-apiserver.config
    karmadactl join v-cluster \
      --cluster-kubeconfig ~/v-space-internal.config \
      --kubeconfig ~/karmada-config/karmada-apiserver.config
    echo "✅ Federation re-joined."
else
    echo "✅ Federation already healthy."
fi

echo "--- Final Instructions ---"
echo "📍 Please open two new terminals for Port-Forwarding:"
echo "Terminal A: kubectl port-forward -n v-space pod/v-space-0 8443:8443"
echo "Terminal B: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
echo "🌟 System Resume Complete."
