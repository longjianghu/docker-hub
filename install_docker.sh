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

# 幂等性检查：已安装则跳过
if command -v docker &> /dev/null; then
    echo "Docker 已安装: $(docker --version)"
    echo "如需重新安装，请先卸载后重新执行此脚本"
    exit 0
fi

echo "=== 使用腾讯云镜像源安装 Docker ==="

# 安装 Docker（腾讯云源）
curl -fsSL https://get.docker.com | bash -s docker --mirror Tencent

# 添加当前用户到 docker 组
sudo usermod -aG docker "$USER" 2>/dev/null || true

# 配置腾讯云镜像加速器
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
COMPOSE_INSTALLED=false
if command -v apt-get &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin && COMPOSE_INSTALLED=true
elif command -v yum &> /dev/null; then
    sudo yum install -y docker-compose-plugin && COMPOSE_INSTALLED=true
elif command -v dnf &> /dev/null; then
    sudo dnf install -y docker-compose-plugin && COMPOSE_INSTALLED=true
fi

if [ "$COMPOSE_INSTALLED" = false ]; then
    echo "错误：Docker Compose 插件安装失败，请手动安装"
    echo "  参考: https://docs.docker.com/compose/install-linux/"
    exit 1
fi

# 验证
echo ""
echo "=== 验证安装 ==="
docker --version
docker compose version

# 当场验证，无需重新登录
echo ""
echo "安装完成！正在验证 Docker 运行权限..."
if sg docker -c "docker run --rm hello-world" > /dev/null 2>&1; then
    echo "Docker 运行验证通过"
else
    echo "Docker 权限验证未通过，请执行以下命令之一："
    echo "  1. newgrp docker        # 立即生效（当前终端）"
    echo "  2. 重新登录 SSH         # 永久生效"
fi
