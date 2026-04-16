#!/bin/bash
# FedMark Status Checker V3.3 - Improved Regex
# Goal: Precise observation of multi-dimensional workloads.

echo "------------------------------------------------"
echo "🔍 [1/6] Physical Infrastructure"
docker ps --filter "name=member-1-control-plane" --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "🤖 [2/6] KWOK Nodes (Resources Check)"
# 检查 Ready 状态
READY_NODES=$(kubectl get nodes | grep member-1-node- | grep -c "Ready")
# 关键修正：使用正则表达式匹配 CPU 资源，避免空格数量干扰
HAS_RES=$(kubectl describe node member-1-node-1 | grep -E "cpu:\s+32" >/dev/null && echo "YES" || echo "NO")
echo "Nodes Ready: $READY_NODES / 10 | Resources Injected: $HAS_RES"

echo ""
echo "🚀 [3/6] Federation Workload Distribution (fed-workload)"
if kubectl get ns fed-workload >/dev/null 2>&1; then
    TOTAL_PODS=$(kubectl get pods -n fed-workload --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n fed-workload --no-headers 2>/dev/null | grep -c "Running")
    echo "Total Pods: $TOTAL_PODS | Running: $RUNNING_PODS"
    echo "Distribution:"
    kubectl get pods -n fed-workload -o custom-columns=NODE:.spec.nodeName --no-headers 2>/dev/null | sort | uniq -c | grep member-1-node || echo "Waiting for scheduling..."
else
    echo "⚪ No fed-workload namespace found on member-1."
fi

echo ""
echo "📦 [4/6] vcluster Runtime"
kubectl get pods -n v-space -l app=vcluster --no-headers 2>/dev/null -o custom-columns=":metadata.name,:status.phase,:status.containerStatuses[0].restartCount" | xargs printf "Name: %s | Status: %s | Restarts: %s\n" || echo "vcluster not found."

echo ""
echo "🎡 [5/6] System Health (Karmada & Monitoring)"
echo "Karmada Pods: $(kubectl get pods -n karmada-system --no-headers 2>/dev/null | wc -l)"
echo "Monitoring Pods: $(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l)"

echo ""
echo "🌌 [6/6] Federation View (KFED)"
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"
if [ -f ${HOME}/karmada-config/karmada-apiserver.config ]; then
    kubectl $K_CONFIG get clusters --no-headers 2>/dev/null | awk '{printf "Cluster: %-12s | Status: %-5s | Version: %s\n", $1, $4, $2}' || echo "Karmada unreachable."
else
    echo "Config missing at ${HOME}/karmada-config/karmada-apiserver.config"
fi
echo "------------------------------------------------"
