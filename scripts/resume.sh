#!/bin/bash
# FedMark Infrastructure Resume Script V6.0 - Architect Edition
# Guiding Principle: Automated Authentication Piercing & Resource Realignment.

echo "🚀 Starting Multi-Cluster FedMark Recovery (V6.0)..."

# 1. 变量准备
MEMBER_CONTEXT="kind-member-1"
HOST_CONTEXT="kind-karmada-host"
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

# 获取物理容器 IP
MEMBER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' member-1-control-plane 2>/dev/null)

if [ -z "$MEMBER_IP" ]; then
    echo "❌ Error: member-1-control-plane container not found. Please start kind clusters first."
    exit 1
fi

# --- Step 1: Member-1 仿真底座与权限对齐 ---
echo "--- Step 1: Aligning Member-1 Nodes & RBAC ---"
kubectl config use-context $MEMBER_CONTEXT

# 节点定义与 KWOK Stage
if [ -f bootstrap/nodes.yaml ]; then
    kubectl apply -f bootstrap/nodes.yaml
fi

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
      conditions: [{type: "Ready", status: "True", reason: "KubeletReady"}]
STAGE_EOF

# 物理资源注入 (32核/64G)
for i in {1..10}; do
    kubectl patch node member-1-node-$i --subresource=status -p '{"status":{"allocatable":{"cpu":"32","memory":"64Gi","pods":"110"},"capacity":{"cpu":"32","memory":"64Gi","pods":"110"}}}' 2>/dev/null
done

# 【核心改进】自动生成并提取真实管理员 Token
kubectl apply -f - <<TOKEN_EOF
apiVersion: v1
kind: Secret
metadata:
  name: karmada-admin-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
TOKEN_EOF

# 赋予精准 RBAC 权限
kubectl create clusterrolebinding karmada-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:default 2>/dev/null || true

REAL_TOKEN_B64=$(kubectl get secret -n kube-system karmada-admin-token -o jsonpath='{.data.token}')
REAL_CA_B64=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="kind-member-1")].cluster.certificate-authority-data}')

echo "✅ Member-1: Nodes Ready, RBAC Pierced, Token Extracted."

# --- Step 2: Host 联邦链路穿透 ---
echo "--- Step 2: Re-aligning Federation Link via Real Token ---"
kubectl config use-context $HOST_CONTEXT

# 构造基于证书的 Kubeconfig
NEW_KUBECONFIG_B64=$(sed "s|https://127.0.0.1:[0-9]*|https://$MEMBER_IP:6443|g" ~/.kube/config | base64 -w 0)

kubectl $K_CONFIG create ns karmada-cluster 2>/dev/null || true
kubectl $K_CONFIG create ns fed-workload 2>/dev/null || true

# 注入包含真实 CA 和 Token 的 Secret
kubectl $K_CONFIG apply -f - <<REG_EOF
apiVersion: v1
kind: Secret
metadata:
  name: member-1-secret
  namespace: karmada-cluster
data:
  kubeconfig: $NEW_KUBECONFIG_B64
  caBundle: $REAL_CA_B64
  token: $REAL_TOKEN_B64
---
apiVersion: cluster.karmada.io/v1alpha1
kind: Cluster
metadata:
  name: member-1
spec:
  apiEndpoint: https://$MEMBER_IP:6443
  syncMode: Push
  secretRef:
    name: member-1-secret
    namespace: karmada-cluster
REG_EOF

# 强制重启控制器以刷新连接
kubectl delete pod -n karmada-system -l app=karmada-controller-manager --force --grace-period=0 >/dev/null 2>&1

echo "✅ Host: Federation Secret Updated, Controller Pulsed."

# --- Step 3: 调度策略与负载自愈 ---
echo "--- Step 3: Re-applying Policies & Workloads ---"
if [ -f bootstrap/karmada/nginx-propagation.yaml ]; then
    kubectl $K_CONFIG apply -f bootstrap/karmada/nginx-propagation.yaml
fi

# 确保 Deployment 模板存在
kubectl $K_CONFIG get deployment nginx-fed -n fed-workload >/dev/null 2>&1
if [ $? -ne 0 ]; then
    kubectl $K_CONFIG apply -f - <<DEP_EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-fed
  namespace: fed-workload
spec:
  replicas: 10
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19.0
        resources:
          limits: {cpu: "100m", memory: "100Mi"}
          requests: {cpu: "100m", memory: "100Mi"}
DEP_EOF
fi

echo "🌟 Multi-Cluster Resume Complete. Waiting for health check..."
./scripts/inspect-fed.sh
sleep 5
kubectl $K_CONFIG get cluster
