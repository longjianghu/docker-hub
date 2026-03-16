FROM redis:7.2.13-alpine3.21

LABEL maintainer="Longjianghu <215241062@qq.com>"

# 更换阿里源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装时区并设置（单层）
RUN apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo Asia/Shanghai > /etc/timezone

# 确保数据目录权限（Redis 用户 uid=999）
RUN mkdir -p /data && chown redis:redis /data

# 复制配置 默认配置:https://raw.githubusercontent.com/redis/redis/7.2/redis.conf
COPY --chown=redis:redis redis.conf /etc/redis.conf

# 切换到非 root 用户运行（安全）
USER redis

EXPOSE 6379

CMD ["redis-server", "/etc/redis.conf"]