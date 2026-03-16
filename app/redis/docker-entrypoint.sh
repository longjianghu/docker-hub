#!/bin/sh
set -e

# 修复 /data 目录权限（兼容宿主机挂载目录属主不一致的情况）
chown -R redis:redis /data

# 生成 override 配置
if [ -n "$REDIS_PASSWORD" ] || [ -n "$REDIS_BIND" ]; then
    BIND_ADDR="${REDIS_BIND:-127.0.0.1 -::1}"
    echo "bind ${BIND_ADDR}" > /tmp/redis-override.conf

    if [ -n "$REDIS_PASSWORD" ]; then
        echo "requirepass ${REDIS_PASSWORD}" >> /tmp/redis-override.conf
        echo "masterauth ${REDIS_PASSWORD}" >> /tmp/redis-override.conf
    fi

    exec su-exec redis redis-server /etc/redis.conf --include /tmp/redis-override.conf
fi

exec su-exec redis "$@"