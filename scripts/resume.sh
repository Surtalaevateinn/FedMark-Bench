#!/bin/bash
# FedMark Infrastructure Resume Script V7.0
# Guiding Principle: Automated Wake-up, Auth Piercing & Resource Realignment.

echo "🚀 Starting Multi-Cluster FedMark Recovery (V7.0)..."

MEMBER_CONTEXT="kind-member-1"
HOST_CONTEXT="kind-karmada-host"
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

# 检查并启动容器
echo "🐳 Checking physical containers..."
for container in member-1-control-plane karmada-host-control-plane; do
    if [ "$(docker inspect -f '{{.State.Running}}' $container 2>/dev/null)" != "true" ]; then
        echo "  - Starting $container..."
        docker start $container >/dev/null
    fi
done

MEMBER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' member-1-control-plane 2>/dev/null)

# --- Step 1: Member-1 仿真底座与权限对齐 ---
echo "--- Step 1: Aligning Member-1 Nodes & RBAC ---"
kubectl config use-context $MEMBER_CONTEXT

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

for i in {1..10}; do
    kubectl patch node member-1-node-$i --subresource=status -p '{"status":{"allocatable":{"cpu":"32","memory":"64Gi","pods":"110"},"capacity":{"cpu":"32","memory":"64Gi","pods":"110"}}}' 2>/dev/null
done

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

kubectl create clusterrolebinding karmada-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:default 2>/dev/null || true
REAL_TOKEN_B64=$(kubectl get secret -n kube-system karmada-admin-token -o jsonpath='{.data.token}')
REAL_CA_B64=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="kind-member-1")].cluster.certificate-authority-data}')

# --- Step 2: Host 控制面唤醒与链路穿透 ---
echo "--- Step 2: Waking up Federation Brain ---"
kubectl config use-context $HOST_CONTEXT

# 唤醒副本
kubectl scale deployment -n karmada-system --all --replicas=1 2>/dev/null
echo "⏳ Waiting for Karmada API Server to be responsive..."
until kubectl $K_CONFIG get cluster >/dev/null 2>&1; do
    printf "."
    sleep 2
done
echo -e "\n✅ Federation Brain is Online."

# 链路对齐
NEW_KUBECONFIG_B64=$(sed "s|https://127.0.0.1:[0-9]*|https://$MEMBER_IP:6443|g" ~/.kube/config | base64 -w 0)
kubectl $K_CONFIG create ns karmada-cluster 2>/dev/null || true
kubectl $K_CONFIG create ns fed-workload 2>/dev/null || true

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

kubectl delete pod -n karmada-system -l app=karmada-controller-manager --force --grace-period=0 >/dev/null 2>&1

# --- Step 3: 调度策略与负载自愈 ---
echo "--- Step 3: Re-applying Policies & Workloads ---"
if [ -f bootstrap/karmada/nginx-propagation.yaml ]; then
    kubectl $K_CONFIG apply -f bootstrap/karmada/nginx-propagation.yaml
fi

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
DEP_EOF
else
    # 如果模板已存在，确保副本数恢复
    kubectl $K_CONFIG scale deployment nginx-fed -n fed-workload --replicas=10 2>/dev/null
fi

echo "🌟 All systems aligned."
./scripts/inspect-fed.sh
