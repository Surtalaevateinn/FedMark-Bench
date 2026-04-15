#!/bin/bash

# FedMark Status Checker V3.1
# Goal: Comprehensive observability across all dimensions.

echo "------------------------------------------------"
echo "🔍 [1/6] Docker Host Layer (Physical Container)"
docker ps --filter "name=member-1-control-plane" --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "🏘️ [2/6] Physical Namespaces (Namespaces)"
kubectl get ns | grep -E "kube-system|karmada-system|monitoring|v-space"

echo ""
echo "🤖 [3/6] KWOK Simulated Nodes (10 Fake Nodes)"
# 增加统计功能，更直观
READY_NODES=$(kubectl get nodes | grep member-1-node- | grep -c "Ready")
echo "Simulated Nodes Ready: $READY_NODES / 10"

echo ""
echo "📦 [4/6] vcluster Runtime (v-space-0 Pod)"
kubectl get pods -n v-space -l app=vcluster --no-headers -o custom-columns=":metadata.name,:status.phase,:status.containerStatuses[0].restartCount" | xargs printf "Name: %s | Status: %s | Restarts: %s\n"

echo ""
echo "🎡 [5/6] Federation & Monitoring Health"
# 获取 Docker 网桥 IP 用于提示
DOCKER_IP=$(ip addr show docker0 | grep -Po 'inet \K[\d.]+' || echo "172.17.0.1")
echo "Karmada Pods: $(kubectl get pods -n karmada-system --no-headers | wc -l)"
echo "Monitoring Pods: $(kubectl get pods -n monitoring --no-headers | wc -l)"

echo ""
echo "🌌 [6/6] Federation Member Status (Karmada View)"
# 核心验证：检查联邦是否真正收编了子集群
K_CONFIG="--kubeconfig ~/karmada-config/karmada-apiserver.config"
kubectl $K_CONFIG get clusters --no-headers | awk '{printf "Cluster: %-12s | Status: %-5s | Version: %s\n", $1, $4, $2}'

echo "------------------------------------------------"
echo "💡 Hint: If v-cluster is False, ensure Tunnel is open on $DOCKER_IP:8443"
echo "------------------------------------------------"
