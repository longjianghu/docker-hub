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
    success "acme.sh 安装完成，cron 自动续期已启用"
else
    success "acme.sh 已安装"
fi

ACME="$HOME/.acme.sh/acme.sh"

"$ACME" --set-default-ca --server letsencrypt || error "切换 Let's Encrypt 失败，请检查网络"
success "已切换到 Let's Encrypt"

# ─────────────────────────────────────────
#  输入辅助函数
# ─────────────────────────────────────────
trim() { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

validate_domain() {
    case "$1" in
        ""|*[!a-zA-Z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

validate_container_name() {
    case "$1" in
        ""|*[!a-zA-Z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

# ─────────────────────────────────────────
#  配置 DNSPod API 环境变量
# ─────────────────────────────────────────
echo ""
info "是否配置 DNSPod API 环境变量？（acme.sh 会自动保存，续期时无需重复配置）"
printf "请选择 [y/N]: "
read SETUP_ENV

if [ "$(trim "$SETUP_ENV")" = "y" ] || [ "$(trim "$SETUP_ENV")" = "Y" ]; then
    printf "请输入 DP_Id: "
    read DP_Id
    printf "请输入 DP_Key: "
    read -rs DP_Key
    echo ""

    if [ -z "$(trim "$DP_Id")" ] || [ -z "$(trim "$DP_Key")" ]; then
        error "DP_Id 和 DP_Key 不能为空"
    fi

    DP_Id="$(trim "$DP_Id")"
    DP_Key="$(trim "$DP_Key")"
    export DP_Id
    export DP_Key
    # acme.sh 首次 --issue 时会自动将 DP_Id/DP_Key 持久化到 ~/.acme.sh/account.conf
    success "环境变量已设置"
else
    info "跳过环境变量配置，将使用已保存的凭据"
fi

# ─────────────────────────────────────────
#  SSL 证书存放目录
# ─────────────────────────────────────────
echo ""
info "请输入证书存放根目录（默认: /data/var/etc/nginx/ssl）："
printf "> "
read SSL_DIR
SSL_DIR="$(trim "${SSL_DIR:-/data/var/etc/nginx/ssl}")"
mkdir -p "$SSL_DIR" || error "无法创建证书目录: $SSL_DIR"
success "证书目录: $SSL_DIR"

# ─────────────────────────────────────────
#  循环申请证书
# ─────────────────────────────────────────
echo ""
info "开始配置证书，每次输入一个主域名（证书名），可附加多个 SAN 域名"
info "输入空行结束"

CERT_COUNT=0
FAIL_COUNT=0

while true; do
    echo ""
    printf "主域名（留空结束）: "
    read MAIN_DOMAIN
    MAIN_DOMAIN="$(trim "$MAIN_DOMAIN")"

    [ -z "$MAIN_DOMAIN" ] && break

    if ! validate_domain "$MAIN_DOMAIN"; then
        warn "域名格式无效: $MAIN_DOMAIN，跳过"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    # 检查证书是否已存在
    if [ -f "$SSL_DIR/${MAIN_DOMAIN}.pem" ] || [ -f "$SSL_DIR/${MAIN_DOMAIN}.key" ]; then
        warn "检测到域名 $MAIN_DOMAIN 已有证书文件"
        printf "是否覆盖？[y/N]: "
        read OVERWRITE
        if [ "$(trim "$OVERWRITE")" != "y" ] && [ "$(trim "$OVERWRITE")" != "Y" ]; then
            info "跳过 $MAIN_DOMAIN"
            continue
        fi
    fi

    # 收集附加域名
    DOMAIN_ARGS="-d $MAIN_DOMAIN"
    while true; do
        printf "附加域名（留空跳过）: "
        read EXTRA_DOMAIN
        EXTRA_DOMAIN="$(trim "$EXTRA_DOMAIN")"
        [ -z "$EXTRA_DOMAIN" ] && break
        if ! validate_domain "$EXTRA_DOMAIN"; then
            warn "域名格式无效: $EXTRA_DOMAIN，跳过"
            continue
        fi
        DOMAIN_ARGS="$DOMAIN_ARGS -d $EXTRA_DOMAIN"
    done

    # Docker 容器名（用于 reload）
    printf "Nginx 容器名（默认: nginx）: "
    read NGINX_CONTAINER
    NGINX_CONTAINER="$(trim "${NGINX_CONTAINER:-nginx}")"

    if ! validate_container_name "$NGINX_CONTAINER"; then
        warn "容器名格式无效: $NGINX_CONTAINER，跳过"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    # 证书路径
    CERT_KEY="$SSL_DIR/${MAIN_DOMAIN}.key"
    CERT_PEM="$SSL_DIR/${MAIN_DOMAIN}.pem"

    info "正在申请证书: $DOMAIN_ARGS"
    if ! "$ACME" --issue --dns dns_dp $DOMAIN_ARGS; then
        warn "证书申请失败: $MAIN_DOMAIN，跳过"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    info "正在安装证书..."
    if ! "$ACME" --install-cert -d "$MAIN_DOMAIN" \
        --key-file       "$CERT_KEY" \
        --fullchain-file "$CERT_PEM" \
        --reloadcmd      "docker exec $NGINX_CONTAINER nginx -s reload"; then
        warn "证书安装失败: $MAIN_DOMAIN"
        warn "证书已签发但未安装，可手动执行:"
        warn "  $ACME --install-cert -d $MAIN_DOMAIN --key-file $CERT_KEY --fullchain-file $CERT_PEM --reloadcmd 'docker exec $NGINX_CONTAINER nginx -s reload'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

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
if [ "$CERT_COUNT" -eq 0 ] && [ "$FAIL_COUNT" -eq 0 ]; then
    warn "未申请任何证书"
elif [ "$CERT_COUNT" -eq 0 ]; then
    error "所有证书申请均失败（共 $FAIL_COUNT 个）"
else
    success "成功申请 $CERT_COUNT 张证书，存放于: $SSL_DIR"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        warn "有 $FAIL_COUNT 个域名申请失败"
    fi
    echo ""
    info "证书列表："
    found=0
    for f in "$SSL_DIR"/*.pem; do
        [ -f "$f" ] && echo "  $f" && found=1
    done
    [ "$found" -eq 0 ] && warn "未找到 .pem 文件"
fi

echo ""
info "验证 cron 自动续期任务："
crontab -l 2>/dev/null | grep acme || warn "未找到 cron 任务，请手动检查"
