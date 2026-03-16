FROM mysql:8.4.8

LABEL maintainer="Longjianghu <215241062@qq.com>"

ENV TIMEZONE=Asia/Shanghai
RUN cp -f /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# 创建日志目录（关键：先创建并授权）
RUN mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql

# 复制配置并确保权限（MySQL 用户可读）
COPY docker.cnf /etc/mysql/conf.d/
RUN chown mysql:mysql /etc/mysql/conf.d/docker.cnf && \
    chmod 644 /etc/mysql/conf.d/docker.cnf