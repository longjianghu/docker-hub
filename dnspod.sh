#!/bin/sh
set -e

# ─────────────────────────────────────────
#  颜色
# ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo "${BLUE}[INFO]${NC}  $1"; }
success() { echo "${GREEN}[OK]${NC}    $1"; }
warn()    { echo "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo "${RED}[ERROR]${NC} $1"; exit 1; }

# ─────────────────────────────────────────
#  检查 acme.sh
# ─────────────────────────────────────────
if ! command -v acme.sh > /dev/null 2>&1 && [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
    warn "未检测到 acme.sh，正在安装..."
    curl https://get.acme.sh | sh
    . "$HOME/.bashrc" 2>/dev/null || . "$HOME/.profile" 2>/dev/null || true
    success "acme.sh 安装完成，cron 自动续期已启用"
else
    success "acme.sh 已安装"
fi

ACME="$HOME/.acme.sh/acme.sh"

"$ACME" --set-default-ca --server letsencrypt
success "已切换到 Let's Encrypt"

# ─────────────────────────────────────────
#  配置 DNSPod API 环境变量
# ─────────────────────────────────────────
echo ""
info "是否配置 DNSPod API 环境变量？（acme.sh 会自动保存，续期时无需重复配置）"
printf "请选择 [y/N]: "
read SETUP_ENV

if [ "$SETUP_ENV" = "y" ] || [ "$SETUP_ENV" = "Y" ]; then
    printf "请输入 DP_Id: "
    read DP_Id
    printf "请输入 DP_Key: "
    read DP_Key

    if [ -z "$DP_Id" ] || [ -z "$DP_Key" ]; then
        error "DP_Id 和 DP_Key 不能为空"
    fi

    export DP_Id
    export DP_Key
    success "环境变量已设置（本次会话生效，acme.sh 申请后会持久化到 account.conf）"
else
    info "跳过环境变量配置，将使用已保存的凭据"
fi

# ─────────────────────────────────────────
#  SSL 证书存放目录
# ─────────────────────────────────────────
echo ""
info "请输入证书存放根目录（默认: /data/nginx/ssl）："
printf "> "
read SSL_DIR
SSL_DIR="${SSL_DIR:-/data/nginx/ssl}"
mkdir -p "$SSL_DIR"
success "证书目录: $SSL_DIR"

# ─────────────────────────────────────────
#  循环申请证书
# ─────────────────────────────────────────
echo ""
info "开始配置证书，每次输入一个主域名（证书名），可附加多个 SAN 域名"
info "输入空行结束"

CERT_COUNT=0

while true; do
    echo ""
    printf "主域名（留空结束）: "
    read MAIN_DOMAIN

    [ -z "$MAIN_DOMAIN" ] && break

    # 收集附加域名
    DOMAIN_ARGS="-d $MAIN_DOMAIN"
    while true; do
        printf "附加域名（留空跳过）: "
        read EXTRA_DOMAIN
        [ -z "$EXTRA_DOMAIN" ] && break
        DOMAIN_ARGS="$DOMAIN_ARGS -d $EXTRA_DOMAIN"
    done

    # Docker 容器名（用于 reload）
    printf "Nginx 容器名（默认: nginx）: "
    read NGINX_CONTAINER
    NGINX_CONTAINER="${NGINX_CONTAINER:-nginx}"

    # 证书路径
    CERT_KEY="$SSL_DIR/${MAIN_DOMAIN}.key"
    CERT_PEM="$SSL_DIR/${MAIN_DOMAIN}.pem"

    info "正在申请证书: $DOMAIN_ARGS"
    "$ACME" --issue --dns dns_dp $DOMAIN_ARGS

    info "正在安装证书..."
    "$ACME" --install-cert -d "$MAIN_DOMAIN" \
        --key-file       "$CERT_KEY" \
        --fullchain-file "$CERT_PEM" \
        --reloadcmd      "docker exec $NGINX_CONTAINER nginx -s reload"

    CERT_COUNT=$((CERT_COUNT + 1))

    echo ""
    success "证书申请成功"
    echo "  私钥路径:   $CERT_KEY"
    echo "  证书路径:   $CERT_PEM"
done

# ─────────────────────────────────────────
#  汇总输出
# ─────────────────────────────────────────
echo ""
if [ "$CERT_COUNT" -eq 0 ]; then
    warn "未申请任何证书"
else
    success "共申请 $CERT_COUNT 张证书，存放于: $SSL_DIR"
    echo ""
    info "证书列表："
    ls -1 "$SSL_DIR"/*.pem 2>/dev/null | while read f; do
        echo "  $f"
    done
fi

echo ""
info "验证 cron 自动续期任务："
crontab -l 2>/dev/null | grep acme || warn "未找到 cron 任务，请手动检查"
