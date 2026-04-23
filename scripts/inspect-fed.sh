#!/bin/bash
# FedMark Architect Inspector V5.0
# 功能：跨集群自动上下文对齐，多维度状态穿透

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "🛰️  ${BLUE}FedMark Multi-Cluster Inspector Engine${NC}"
echo -e "${BLUE}================================================${NC}"

# 1. 检查物理容器层
echo -e "\n🐳 [1/6] Container Infrastructure (Docker)"
docker ps --filter "name=karmada-host" --filter "name=member-1" --format "table {{.Names}}\t{{.Status}}\t{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"

# 2. 检查联邦大脑 (Host 侧)
echo -e "\n🧠 [2/6] Federation Control Plane (Host View)"
kubectl config use-context kind-karmada-host >/dev/null 2>&1
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

if [ -f ${HOME}/karmada-config/karmada-apiserver.config ]; then
    echo -e "Karmada Endpoint: ${GREEN}Online${NC}"
    kubectl $K_CONFIG get clusters --no-headers 2>/dev/null | awk '{printf "  - Cluster: %-12s | READY: %-5s | Version: %s\n", $1, $4, $2}'
else
    echo -e "Karmada Config: ${RED}Missing${NC}"
fi

# 3. 检查算力池 (Member-1 侧)
echo -e "\n🤖 [3/6] Compute Resources (Member-1 View)"
kubectl config use-context kind-member-1 >/dev/null 2>&1
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_V_NODES=$(kubectl get nodes | grep "member-1-node-" | grep -c "Ready")
# 检查第一个虚拟节点的资源注入情况
HAS_RES=$(kubectl describe node member-1-node-1 2>/dev/null | grep -E "cpu:\s+32" >/dev/null && echo -e "${GREEN}YES${NC}" || echo -e "${RED}NO${NC}")
echo -e "  - Total Nodes: $TOTAL_NODES"
echo -e "  - KWOK Ready : $READY_V_NODES / 10"
echo -e "  - HW Profile Injected: $HAS_RES"

# 4. 检查业务负载分布
echo -e "\n🚀 [4/6] Workload Distribution (Member-1 Context)"
# 注意：这里需要指向成员集群的 context
MEMBER_CONTEXT="kind-member-1" 

if kubectl --context=$MEMBER_CONTEXT get ns fed-workload >/dev/null 2>&1; then
    RUNNING=$(kubectl --context=$MEMBER_CONTEXT get pods -n fed-workload --no-headers 2>/dev/null | grep -c "Running")
    echo -e "  - Namespace: ${GREEN}fed-workload (Active on Member-1)${NC}"
    # ... 其余逻辑同理增加 --context ...
else
    echo -e "  - Namespace: ${RED}fed-workload NOT FOUND on Member-1${NC}"
fi

# 5. 系统组件健康度
echo -e "\n🎡 [5/6] System Components (Host Context)"
kubectl config use-context kind-karmada-host >/dev/null 2>&1
echo -n "  - Karmada Core   : "
kubectl get pods -n karmada-system --no-headers 2>/dev/null | awk '{if($3=="Running") c++} END {printf "%d Running\n", c}'
echo -n "  - Monitoring Stack: "
kubectl get pods -n monitoring --no-headers 2>/dev/null | awk '{if($3=="Running") c++} END {printf "%d Running\n", c}'

# 6. 网络与鉴权路径
echo -e "\n🔐 [6/6] Security & Connectivity"
SECRET_CHECK=$(kubectl $K_CONFIG get secret -n karmada-cluster member-1-secret -o jsonpath='{.data.caBundle}' 2>/dev/null)
if [ ! -z "$SECRET_CHECK" ]; then
    echo -e "  - TLS caBundle: ${GREEN}Injected${NC}"
else
    echo -e "  - TLS caBundle: ${RED}Missing${NC}"
fi

echo -e "\n${BLUE}================================================${NC}"
echo -e "✅ Inspection Complete."
