#!/bin/bash

# FedMark One-Click Sync Tool
# Guiding Principle: Radical Automation & Traceability

echo "📦 Starting full synchronization to GitHub..."

# 1. 进入仓库根目录（确保脚本在任何位置运行都有效）
cd "$(dirname "$0")/.."

# 2. 检查当前状态
echo "🔍 Scanning for changes..."
git status -s

# 3. 全量暂存 (注意：.gitignore 仍会自动过滤敏感 config)
git add .

# 4. 自动生成提交信息 (包含时间戳)
DESC=$(date "+%Y-%m-%d %H:%M:%S")
git commit -m "sync: automatic backup at $DESC"

# 5. 推送到远程仓库
echo "🚀 Pushing to remote..."
git push origin master

echo "✅ All assets synchronized to Surtalaevateinn/FedMark-Bench."
