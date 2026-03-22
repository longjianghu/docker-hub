# syntax=docker/dockerfile:1
FROM longjianghu/jdk:21

LABEL org.opencontainers.image.authors="longjianghu <215241062@qq.com>" \
      org.opencontainers.image.description="Spring Boot base runtime image based on longjianghu/jdk:21"

ENV JAVA_OPTS="-XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:+UseStringDeduplication \
    -XX:+AlwaysPreTouch \
    -Djava.security.egd=file:/dev/./urandom \
    -Xlog:gc*:file=/app/logs/gc.log:time,level,tags:filesize=50M,filecount=5"

USER root

RUN mkdir -p /app/logs \
 && cat > /app/entrypoint.sh <<'EOF'
#!/bin/sh
set -e
exec java ${JAVA_OPTS} \
    -jar /app/app.jar \
    --spring.profiles.active=${PROFILES} \
    "$@"
EOF

RUN chmod +x /app/entrypoint.sh \
 && chown appuser:appgroup /app/entrypoint.sh /app/logs

USER appuser