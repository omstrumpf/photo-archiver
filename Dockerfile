FROM ubuntu:21.10

WORKDIR /app/

RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    cron

ADD _build/install/default/bin/photo_archiver /app/
ADD entry.sh /app/
ADD Dockerfile /app/

CMD ["/bin/bash", "entry.sh"]