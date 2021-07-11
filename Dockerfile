FROM alpine

RUN apk upgrade --no-cache && \
    apk add --update --no-cache bash openssh-client && \
    rm -rf /var/cache/apk/*

COPY run.sh /run.sh

RUN chmod +x /run.sh

ENTRYPOINT [ "/run.sh" ]