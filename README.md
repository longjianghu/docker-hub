# 项目说明

基于官方 Nginx\Mysql\Redis 构建的自定义镜像以及常用的 Spring 基础镜像

# 安装 Docker

执行install_docker.sh

# 构建容器

## 单平台架构镜像

```shell
docker build -t longjianghu/nginx:1.29.6 ./app/nginx/

docker build -t longjianghu/mysql:8.4.8 ./app/mysql/

docker build -t longjianghu/redis:7.2.13 ./app/redis/
```

## 多平台架构镜像

```shell
docker buildx create --name mybuilder --driver docker-container --use

docker buildx build --builder mybuilder --platform linux/amd64,linux/arm64/v8 -t longjianghu/nginx:1.29.6 ./app/nginx/ --push
```

# 容器运行方法

## Nginx

> nginx 配置生成网站：https://nginxconfig.io

docker run --name nginx -p 80:80 -p 443:443 -v /data/var/www:/data/htdocs -v /data/var/etc/nginx/conf.d/:/etc/nginx/conf.d/ -v /data/var/etc/nginx/nginx.conf:/etc/nginx/nginx.conf -v /data/var/log/nginx/:/var/log/nginx/ --restart=unless-stopped -d longjianghu/nginx:1.29.6

docker run --name nginx -p 80:80 -p 443:443 -v /data/var/www:/data/htdocs -v /data/var/etc/nginx/conf.d:/etc/nginx/conf.d  -v /data/nginx/ssl:/etc/nginx/ssl -v /data/var/log/nginx/:/var/log/nginx/ --restart=unless-stopped -d longjianghu/nginx:1.29.6

## MySQL

docker run --name mysql -p 3306:3306 -v /data/var/etc/mysql:/etc/mysql/conf.d -v /data/var/lib/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=123456 --restart=unless-stopped -d longjianghu/mysql:8.4.8

## Redis

> 自定义Redis密码 -e REDIS_PASSWORD=xxx -e REDIS_BIND=0.0.0.0

> 扶久化不丢失数据

docker run --name redis -p 6379:6379 -v /data/var/etc/redis/redis-db.conf:/etc/redis.conf -v /data/var/lib/redis:/data --restart=unless-stopped -d longjianghu/redis:7.2.13

> 日常开发缓存场景(默认)

docker run --name redis -p 6379:6379 -v /data/var/etc/redis/redis-cache.conf:/etc/redis.conf -v /data/var/lib/redis:/data --restart=unless-stopped -d longjianghu/redis:7.2.13

## PHPMyadmin

docker run --name phpmyadmin -p 8000:80 -e PMA_HOST=172.17.0.1 --restart=unless-stopped -d phpmyadmin/phpmyadmin

# Spring 镜像

## 基础镜像

Spring 基础镜像是为了提升构建速度和简化部署成本

```shell

docker build -t longjianghu/spring:17 ./app/spring/17

docker build -t longjianghu/spring:21 ./app/spring/21

docker build -t longjianghu/spring:17-fonts ./app/spring/17-fonts

docker build -t longjianghu/spring:21-fonts ./app/spring/21-fonts
```

## 应用镜像

应用镜像的 Dockerfile 示例

```shell
FROM longjianghu/spring:21

LABEL org.opencontainers.image.authors="longjianghu <215241062@qq.com>" \
      org.opencontainers.image.description="Gateway service"

ARG PROFILES=dev
ENV PROFILES=${PROFILES}

COPY --chown=appuser:appgroup target/app.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]

```
