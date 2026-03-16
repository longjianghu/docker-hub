#!/bin/sh
set -e

if [ -n "$REDIS_PASSWORD" ] || [ -n "$REDIS_BIND" ]; then
    # 绑定 IP，默认 127.0.0.1 -::1
    BIND_ADDR="${REDIS_BIND:-127.0.0.1 -::1}"
    echo "bind ${BIND_ADDR}" > /tmp/redis-override.conf

    # 密码（可选）
    if [ -n "$REDIS_PASSWORD" ]; then
        echo "requirepass ${REDIS_PASSWORD}" >> /tmp/redis-override.conf
        echo "masterauth ${REDIS_PASSWORD}" >> /tmp/redis-override.conf
    fi

    exec redis-server /etc/redis.conf --include /tmp/redis-override.conf
fi

exec "$@"