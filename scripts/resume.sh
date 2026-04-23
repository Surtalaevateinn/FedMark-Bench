#!/bin/bash
# FedMark Infrastructure Resume Script V10.0
# Guiding Principle: TLS Alignment, Impersonator Injection & Proxy Piercing.

echo "🚀 Starting Multi-Cluster FedMark Recovery (V10.0)..."

# --- Step 0: 环境、物理地址与上下文对齐 ---
# [修复] 强制将宿主机 Kubeconfig 中的 0.0.0.0 拨正为 127.0.0.1 以通过 TLS 验证
echo "🔧 Aligning local Kubeconfig endpoints to 127.0.0.1..."
sed -i 's/0.0.0.0:39209/127.0.0.1:39209/g' ~/.kube/config

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

# 提取成员集群在 Docker 网络中的内部 IP
MEMBER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' member-1-control-plane 2>/dev/null)

# --- Step 1: Member-1 仿真底座与权限对齐 ---
echo "--- Step 1: Aligning Member-1 Nodes & RBAC ---"
kubectl config use-context $MEMBER_CONTEXT

# [新增] 补全 KWOK 核心组件，防止节点处于 NotReady
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/kwok.yaml
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/download/v0.6.0/stage-fast.yaml

if [ -f bootstrap/nodes.yaml ]; then
    kubectl apply -f bootstrap/nodes.yaml
fi

# 算力注入 (320核) 并强制触发 Ready 状态
for i in {1..10}; do
    kubectl patch node member-1-node-$i --subresource=status -p '{"status":{"allocatable":{"cpu":"32","memory":"64Gi","pods":"110"},"capacity":{"cpu":"32","memory":"64Gi","pods":"110"},"conditions":[{"type":"Ready","status":"True","reason":"KubeletReady"}]}}' 2>/dev/null
done

# Token 提取逻辑 (用于跨集群鉴权)
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

# --- Step 2.1: 物理鉴权对齐 (解决 503/401 穿透的关键) ---
echo "🔐 Aligning Physical RequestHeader Auth..."
# 提取物理 CA 证书并直接对齐 Secret (解决 unknown authority)
FRONT_PROXY_CA=$(kubectl get configmap extension-apiserver-authentication -n kube-system -o jsonpath='{.data.requestheader-client-ca-file}')
kubectl create secret generic karmada-aggregator-auth-ca --from-literal=ca.crt="$FRONT_PROXY_CA" -n karmada-system --dry-run=client -o yaml | kubectl apply -f -

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

# 物理 CA 重新注入 APIService 隧道
PHYSICAL_CA_B64=$(echo "$FRONT_PROXY_CA" | base64 -w 0)
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

# --- Step 2.2: 注入 Cluster 与 Impersonator (解决 no server found) ---
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
apiVersion: cluster.cluster.karmada.io/v1alpha1
kind: Cluster
metadata:
  name: member-1
spec:
  apiEndpoint: https://$MEMBER_IP:6443
  syncMode: Push
  secretRef:
    name: member-1-secret
    namespace: karmada-cluster
  impersonatorSecretRef:
    name: member-1-secret
    namespace: karmada-cluster
REG_EOF

# 🚀 强制刷新聚合代理，确保 --cluster 标志生效
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

# 自动切换到联邦逻辑上下文
kubectl config use-context $FED_CONTEXT

echo "🌟 All systems aligned. Context switched to: $FED_CONTEXT"
echo "👉 Try: kubectl get nodes --cluster member-1"

# --- Step 4: Monitoring Realignment (Ensure Prometheus Visibility) ---
echo "📊 Aligning Monitoring Discovery..."
kubectl config use-context $HOST_CONTEXT

# A. 确保命名空间标签存在，防止 Prometheus 过滤
kubectl label namespace karmada-system kubernetes.io/metadata.name=karmada-system --overwrite 2>/dev/null
kubectl label namespace fed-workload kubernetes.io/metadata.name=fed-workload --overwrite 2>/dev/null

# B. 应用监控定义 (ServiceMonitor & PodMonitor)
if [ -f bootstrap/monitoring/karmada-service-monitor.yaml ]; then
    echo "  - Re-applying Karmada ServiceMonitor..."
    kubectl apply -f bootstrap/monitoring/karmada-service-monitor.yaml
fi

if [ -f bootstrap/monitoring/fed-pod-monitor.yaml ]; then
    echo "  - Re-applying Fed Workload PodMonitor..."
    kubectl apply -f bootstrap/monitoring/fed-pod-monitor.yaml
fi

# C. 关键：强制对齐 ServiceMonitor 的 release 标签（防止重启后标签丢失导致的不抓取）
kubectl label servicemonitor karmada-metrics-discovery -n karmada-system release=prometheus-stack --overwrite 2>/dev/null

# D. 触发 Prometheus 热加载 (如果 Pod 已经 Ready)
PROM_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$PROM_POD" ]; then
    echo "🔄 Poking Prometheus for target refresh..."
    # 鉴于之前发现镜像无 curl，我们通过 Patch 触发 Operator 刷新配置
    kubectl patch prometheus -n monitoring $(kubectl get prometheus -n monitoring --no-headers | awk '{print $1}') --type='merge' -p "{\"spec\":{\"paused\":false,\"tag\":\"$(date +%s)\"}}" 2>/dev/null
fi

./scripts/inspect-fed.sh
