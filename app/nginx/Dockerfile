FROM nginx:1.29.6-alpine-perl

LABEL maintainer="Longjianghu <215241062@qq.com>"

# 更换阿里源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装时区并设置（合并为单层）
RUN apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo Asia/Shanghai > /etc/timezone