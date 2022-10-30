FROM ubuntu:latest

WORKDIR /app/

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    tzdata \
    libssl-dev \
    ca-certificates \
    cron

ADD _build/install/default/bin/photo_archiver /app/
ADD entry.sh /app/
ADD Dockerfile /app/

CMD ["/bin/bash", "entry.sh"]
