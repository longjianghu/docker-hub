FROM redis:7.2.13-alpine3.21
LABEL maintainer="Longjianghu <215241062@qq.com>"

# 更换阿里源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装时区、su-exec（单层）
RUN apk add --no-cache tzdata su-exec && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo Asia/Shanghai > /etc/timezone

# 确保数据目录存在
RUN mkdir -p /data

# 复制配置
COPY --chown=redis:redis redis-cache.conf /etc/redis.conf

# 复制启动脚本（root owned，chmod 赋予执行权限）
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 保持 root，由脚本内部切换
EXPOSE 6379
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["redis-server", "/etc/redis.conf"]