#!/bin/bash
# FedMark Status Checker V3.2
# Goal: Precise observation of multi-dimensional workloads.

echo "------------------------------------------------"
echo "🔍 [1/6] Physical Infrastructure"
docker ps --filter "name=member-1-control-plane" --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "🤖 [2/6] KWOK Nodes (Resources Check)"
READY_NODES=$(kubectl get nodes | grep member-1-node- | grep -c "Ready")
HAS_RES=$(kubectl describe node member-1-node-1 | grep -q "cpu:                32" && echo "YES" || echo "NO")
echo "Nodes Ready: $READY_NODES / 10 | Resources Injected: $HAS_RES"

echo ""
echo "🚀 [3/6] Federation Workload Distribution (fed-workload)"
# 核心指标：统计 50 个 Pod 在不同节点的分布
if kubectl get ns fed-workload >/dev/null 2>&1; then
    TOTAL_PODS=$(kubectl get pods -n fed-workload --no-headers | wc -l)
    RUNNING_PODS=$(kubectl get pods -n fed-workload --no-headers | grep -c "Running")
    echo "Total Pods: $TOTAL_PODS | Running: $RUNNING_PODS"
    echo "Distribution:"
    kubectl get pods -n fed-workload -o custom-columns=NODE:.spec.nodeName | sort | uniq -c | grep member-1-node
else
    echo "⚪ No fed-workload namespace found."
fi

echo ""
echo "📦 [4/6] vcluster Runtime"
kubectl get pods -n v-space -l app=vcluster --no-headers -o custom-columns=":metadata.name,:status.phase,:status.containerStatuses[0].restartCount" | xargs printf "Name: %s | Status: %s | Restarts: %s\n"

echo ""
echo "🎡 [5/6] System Health (Karmada & Monitoring)"
echo "Karmada Pods: $(kubectl get pods -n karmada-system --no-headers | wc -l)"
echo "Monitoring Pods: $(kubectl get pods -n monitoring --no-headers | wc -l)"

echo ""
echo "🌌 [6/6] Federation View (KFED)"
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"
kubectl $K_CONFIG get clusters --no-headers | awk '{printf "Cluster: %-12s | Status: %-5s | Version: %s\n", $1, $4, $2}'
echo "------------------------------------------------"
