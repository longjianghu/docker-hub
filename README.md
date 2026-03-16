### 项目说明

基于官方 Nginx\Mysql\Redis 构建的自定义镜像

### 安装 Docker

执行install_docker.sh

### 构建容器

docker build -t longjianghu/nginx:1.29.6 ./app/nginx/

docker build -t longjianghu/mysql:8.4.8 ./app/mysql/

docker build -t longjianghu/redis:7.2.13 ./app/redis/

### 容器运行方法

Nginx:

docker run --name nginx -p 80:80 -p 443:443 -v /data/var/www:/data/htdocs -v /data/var/etc/nginx/conf.d/:/etc/nginx/conf.d/ -v /data/var/etc/nginx/nginx.conf:/etc/nginx/nginx.conf -v /data/var/log/nginx/:/var/log/nginx/ -d longjianghu/nginx:1.29.6

MySQL:

docker run --name mysql -p 3306:3306 -v /data/var/etc/mysql:/etc/mysql/conf.d -v /data/var/lib/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=123456 -d longjianghu/mysql:8.4.8

Redis:

docker run --name redis -p 6379:6379 -v /data/var/etc/redis/redis.conf:/etc/redis.conf -d longjianghu/redis:7.2.13

PHPMyadmin：

docker run --name phpmyadmin -p 8000:80 -e PMA_HOST=172.17.0.1 -d phpmyadmin/phpmyadmin