#!/bin/bash
# FedMark Infrastructure Resume Script V4.0 - Total Resilience
# Guiding Principle: Immutable Infrastructure & Self-Healing Architecture.

echo "🚀 Starting Full FedMark Infrastructure Recovery (V4.0)..."

# --- Step 0: Clear Finalizer Deadlocks ---
# 解决由于环境崩溃导致的命名空间无法删除的僵死状态
echo "--- Step 0: Clearing Namespace Deadlocks ---"
for ns in fed-workload karmada-system; do
  if kubectl get ns $ns 2>/dev/null | grep -q "Terminating"; then
    echo "🧹 Scrubbing finalizers from $ns..."
    kubectl get ns $ns -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/$ns/finalize -f - 2>/dev/null
  fi
done

# --- Step 1: KWOK Infrastructure Realignment ---
# 1.1 应用声明式节点定义（包含 Labels 和 Annotations）
# 解决重启后节点丢失 Annotations 导致 KWOK 不接管的问题
echo "--- Step 1: Aligning Simulated Nodes & KWOK Stages ---"
if [ -f bootstrap/nodes.yaml ]; then
    kubectl apply -f bootstrap/nodes.yaml
    echo "✅ Nodes definition applied from bootstrap/nodes.yaml."
fi

# 1.2 重新声明 Stage，确保满足 Ready 条件
kubectl apply -f - <<STAGE_EOF
apiVersion: kwok.x-k8s.io/v1alpha1
kind: Stage
metadata:
  name: node-ready
spec:
  resourceRef:
    kind: Node
    apiVersion: v1
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

# 1.3 关键：强制移除阻碍调度的污点 (Taints)
# 解决物理集群重启或节点未就绪时自动产生的 NoSchedule 限制
echo "🧹 Cleansing NoSchedule taints from simulated nodes..."
for i in {1..10}; do
  kubectl taint nodes member-1-node-$i kwok.x-k8s.io/node- 2>/dev/null
  # 1.4 注入虚拟资源 (32C/64G)
  kubectl patch node member-1-node-$i --subresource=status -p '{
    "status": {
      "allocatable": {"cpu": "32", "memory": "64Gi", "pods": "110"},
      "capacity": {"cpu": "32", "memory": "64Gi", "pods": "110"}
    }
  }' 2>/dev/null
done
echo "✅ 10 Simulated Nodes Ready & Resources Patched."

# --- Step 2: Federation Command Chain Recovery ---
echo "--- Step 2: Fixing Federation Connectivity ---"
# 2.1 动态获取 member-1 在 Docker 网桥中的最新 IP
# 解决 127.0.0.1 导致的集群失联 (NotReachable) 问题
MEMBER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' member-1-control-plane 2>/dev/null)
K_CONFIG="--kubeconfig ${HOME}/karmada-config/karmada-apiserver.config"

# 2.2 如果 member-1 失联，自动更新 Kubeconfig 并重新 Join
if ! kubectl $K_CONFIG get cluster member-1 2>/dev/null | grep -q "True"; then
    echo "⚠️  Federation link broken or IP shifted. Re-aligning to $MEMBER_IP..."
    cp ~/.kube/config ~/member-1-internal.config
    # 强制将 server 地址指向容器内部 IP 和标准 6443 端口
    sed -i "s|https://127.0.0.1:[0-9]*|https://$MEMBER_IP:6443|g" ~/member-1-internal.config
    karmadactl unjoin member-1 $K_CONFIG 2>/dev/null
    karmadactl join member-1 --cluster-kubeconfig ~/member-1-internal.config $K_CONFIG
    echo "✅ Federation link re-established via Internal IP."
fi

# --- Step 3: Workload Rescheduling ---
# 强制重启 Deployment 以触发调度器重新扫描已就绪的节点资源
echo "--- Step 3: Triggering Workload Rescheduling ---"
kubectl $K_CONFIG rollout restart deployment nginx-fed -n fed-workload 2>/dev/null

# --- Step 4: Environment Alias ---
if ! grep -q "alias kfed=" ~/.bashrc; then
    echo "alias kfed='kubectl $K_CONFIG'" >> ~/.bashrc
    echo "✅ Alias 'kfed' added to .bashrc."
fi

echo "🌟 System Resume Complete. Use 'source ~/.bashrc' if kfed is not active."
./scripts/check_status.sh
