#!/bin/bash
# FedMark Infrastructure Resume Script V9.0
# Guiding Principle: Total Automation, Proxy Refresh & Auth Persistence.

echo "🚀 Starting Multi-Cluster FedMark Recovery (V9.0)..."

# --- Step 0: 环境与上下文自动对齐 ---
export KUBECONFIG=${HOME}/.kube/config:${HOME}/karmada-config/karmada-apiserver.config

MEMBER_CONTEXT="kind-member-1"
HOST_CONTEXT="kind-karmada-host"
FED_CONTEXT="karmada-apiserver"
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

# 确保 KWOK 状态机运行
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

# 算力注入 (320核)
for i in {1..10}; do
    kubectl patch node member-1-node-$i --subresource=status -p '{"status":{"allocatable":{"cpu":"32","memory":"64Gi","pods":"110"},"capacity":{"cpu":"32","memory":"64Gi","pods":"110"}}}' 2>/dev/null
done

# Token 提取逻辑
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

# --- Step 2: Host 控制面唤醒与代理刷新 ---
echo "--- Step 2: Waking up Federation Brain ---"
kubectl config use-context $HOST_CONTEXT

# 唤醒所有副本
kubectl scale deployment -n karmada-system --all --replicas=1 2>/dev/null

echo "⏳ Waiting for Karmada API Server (32443) to wake up..."
until kubectl $K_CONFIG get cluster >/dev/null 2>&1; do
    printf "."
    sleep 2
done
echo -e "\n✅ Federation Brain is Online."

# --- 新增 Step 2.1: 物理鉴权对齐 (解决 401 关键) ---
echo "🔐 Aligning Physical RequestHeader Auth..."
# 提取物理 CA 证书
PHYSICAL_CA_B64=$(kubectl get configmap extension-apiserver-authentication -n kube-system -o jsonpath='{.data.requestheader-client-ca-file}' | base64 -w 0)

# 持久化 RBAC 授权
kubectl apply -f - <<AUTH_EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karmada-extension-auth-reader-persist
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: default
  namespace: karmada-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karmada-auth-delegator-persist
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: default
  namespace: karmada-system
AUTH_EOF

# 持久化注入 APIService 隧道
kubectl apply -f - <<APISVC_EOF
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1alpha1.cluster.karmada.io
spec:
  service:
    name: karmada-aggregated-apiserver
    namespace: karmada-system
    port: 443
  group: cluster.karmada.io
  version: v1alpha1
  groupPriorityMinimum: 2000
  versionPriority: 10
  caBundle: $PHYSICAL_CA_B64
  insecureSkipTLSVerify: false
APISVC_EOF

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

# 🚀 关键：强制刷新控制器与聚合代理，确保 --cluster 标志生效
echo "🔄 Refreshing Federation Proxies..."
kubectl delete pod -n karmada-system -l app=karmada-controller-manager --force --grace-period=0 >/dev/null 2>&1
kubectl delete pod -n karmada-system -l app=karmada-aggregated-apiserver --force --grace-period=0 >/dev/null 2>&1
sleep 5

# --- Step 3: 调度策略与负载自愈 ---
echo "--- Step 3: Re-applying Policies & Workloads ---"
if [ -f bootstrap/karmada/nginx-propagation.yaml ]; then
    kubectl $K_CONFIG apply -f bootstrap/karmada/nginx-propagation.yaml
fi

# 确保业务 Pod 副本数恢复
kubectl $K_CONFIG scale deployment nginx-fed -n fed-workload --replicas=10 2>/dev/null

# 自动切换到联邦逻辑上下文，方便用户直接操作
kubectl config use-context $FED_CONTEXT

echo "🌟 All systems aligned. Context switched to: $FED_CONTEXT"
echo "👉 Try: kubectl get pods -A --cluster member-1"
./scripts/inspect-fed.sh
