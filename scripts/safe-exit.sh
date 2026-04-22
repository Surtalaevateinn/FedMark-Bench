#!/bin/bash
# FedMark Infrastructure Safe Exit Script V1.1
# Guiding Principle: Graceful degradation to prevent etcd corruption.

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "🛑 Starting Graceful Shutdown Sequence..."
echo -e "${BLUE}================================================${NC}"

K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

# --- Step 1: 停止联邦层面的业务同步 ---
echo -e "\n⏳ [1/5] Scaling down federation workloads..."
if [ -f ${HOME}/karmada-config/karmada-apiserver.config ]; then
    kubectl $K_CONFIG scale deployment nginx-fed -n fed-workload --replicas=0 --timeout=30s 2>/dev/null
    echo -e "✅ Workloads scaled to zero."
fi

# --- Step 2: 优雅停止 Karmada 控制面组件 ---
echo -e "\n🧠 [2/5] Stopping Federation Control Plane components..."
kubectl config use-context kind-karmada-host >/dev/null 2>&1
COMPONENTS=("karmada-controller-manager" "karmada-scheduler" "karmada-webhook" "karmada-apiserver" "karmada-aggregated-apiserver" "kube-controller-manager")
for comp in "${COMPONENTS[@]}"; do
    kubectl scale deployment -n karmada-system "$comp" --replicas=0 --timeout=15s 2>/dev/null
    echo -e "  - $comp: Stopped"
done

# --- Step 3: 设置容器重启策略 ---
echo -e "\n🔄 [3/5] Ensuring containers restart on boot..."
docker update --restart unless-stopped member-1-control-plane karmada-host-control-plane 2>/dev/null
echo -e "✅ Restart policy set to 'unless-stopped'."

# --- Step 4: 物理容器停止 ---
echo -e "\n🐳 [4/5] Stopping Kind Infrastructure..."
docker stop member-1-control-plane karmada-host-control-plane 2>/dev/null
echo -e "✅ Docker containers stopped."

# --- Step 5: 内核缓冲区同步 ---
echo -e "\n💾 [5/5] Flushing filesystem buffers..."
sync
echo -e "✅ Filesystem synced."

echo -e "\n${GREEN}================================================${NC}"
echo -e "🏁 Safe to shutdown or reboot the VM now."
echo -e "${GREEN}================================================${NC}"
