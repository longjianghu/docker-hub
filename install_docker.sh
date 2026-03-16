#!/bin/bash
# ==============================================================================
# Docker 安装脚本 - 腾讯云镜像源
# 地址：https://mirror.ccs.tencentyun.com
# 无需登录，直接可用
# ==============================================================================

set -e

# 检查是否 root 或 sudo 可用
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo "错误：需要 root 权限或 sudo 访问"
    exit 1
fi

echo "=== 使用腾讯云镜像源安装 Docker ==="

# 安装 Docker（腾讯云源）
curl -fsSL https://get.docker.com | bash -s docker --mirror Tencent

# 添加当前用户到 docker 组
sudo usermod -aG docker "$USER" 2>/dev/null || true

# 配置腾讯云镜像加速器（修正空格）
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"],
  "storage-driver": "overlay2"
}
EOF

# 启动 Docker
sudo systemctl daemon-reload
sudo systemctl enable docker --now

# 安装 Docker Compose（适配多发行版）
if command -v apt-get &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin
elif command -v yum &> /dev/null; then
    sudo yum install -y docker-compose-plugin
elif command -v dnf &> /dev/null; then
    sudo dnf install -y docker-compose-plugin
else
    echo "警告：无法自动安装 docker-compose-plugin"
fi

# 验证
echo ""
echo "=== 验证安装 ==="
docker --version
docker compose version

echo ""
echo "安装完成！请执行以下命令之一使权限生效："
echo "  1. newgrp docker        # 立即生效（当前终端）"
echo "  2. 重新登录 SSH         # 永久生效"
echo ""
echo "验证命令：docker run hello-world"