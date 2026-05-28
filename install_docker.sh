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

# 通过设置环境变量指定腾讯云镜像源安装 Docker
echo "正在下载 Docker 安装脚本..."
if ! DOCKER_DOWNLOAD_MIRROR=https://mirrors.cloud.tencent.com/docker-ce curl -fsSL --retry 3 --retry-delay 5 https://get.docker.com | sudo bash -s docker; then
    echo "错误：Docker 安装脚本下载或执行失败"
    echo "  可能原因："
    echo "    1. 无法访问 get.docker.com，请检查网络连接"
    echo "    2. 可尝试手动设置代理后重新执行"
    echo ""
    echo "  手动安装参考：https://docs.docker.com/engine/install/"
    exit 1
fi

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
if ! sudo systemctl daemon-reload; then
    echo "警告：systemctl daemon-reload 失败，systemd 可能不可用"
    echo "  如果 Docker 已通过其他方式启动，请忽略此警告"
fi

if ! sudo systemctl enable docker --now 2>/dev/null; then
    echo "警告：systemctl enable docker 失败，尝试手动启动 Docker..."
    sudo dockerd > /tmp/dockerd.log 2>&1 &
    sleep 3
    if ! docker info > /dev/null 2>&1; then
        echo "错误：Docker 启动失败，请检查 /tmp/dockerd.log"
        exit 1
    fi
fi

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
