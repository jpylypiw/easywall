FROM alpine:3.15 AS builder

RUN apk add --no-cache                                                                                                  \
        autoconf                                                                                                        \
        automake                                                                                                        \
        bash                                                                                                            \
        build-base                                                                                                      \
        py3-pip                                                                                                         \
        py3-wheel                                                                                                       \
        python3-dev

COPY easywall           /src/easywall/easywall
COPY requirements.txt   /src/easywall/
COPY setup.cfg          /src/easywall/
COPY setup.py           /src/easywall/
WORKDIR                 /src/easywall

RUN pip3 install . -t /app

ARG BOOTSTRAP="4.1.3"
ARG JQUERY="3.3.1"
ARG POPPER="1.14.3"
COPY easywall/web/static /app/easywall/web/static
RUN mkdir -p /app/easywall/web/static/css/ && wget -P /app/easywall/web/static/css/                                     \
    https://stackpath.bootstrapcdn.com/bootstrap/$BOOTSTRAP/css/bootstrap.min.css                                       \
    https://stackpath.bootstrapcdn.com/bootstrap/$BOOTSTRAP/css/bootstrap.min.css.map
RUN mkdir -p /app/easywall/web/static/js/ && wget -P /app/easywall/web/static/js/                                       \
    https://stackpath.bootstrapcdn.com/bootstrap/$BOOTSTRAP/js/bootstrap.min.js                                         \
    https://stackpath.bootstrapcdn.com/bootstrap/$BOOTSTRAP/js/bootstrap.min.js.map                                     \
    https://cdnjs.cloudflare.com/ajax/libs/popper.js/$POPPER/umd/popper.min.js                                          \
    https://cdnjs.cloudflare.com/ajax/libs/popper.js/$POPPER/umd/popper.min.js.map                                      \
    https://code.jquery.com/jquery-$JQUERY.slim.min.js
COPY easywall/web/templates /app/easywall/web/templates

ARG FONTAWESOME="4.7.0"
RUN wget -P /tmp https://fontawesome.com/v$FONTAWESOME/assets/font-awesome-$FONTAWESOME.zip                             \
 && unzip -d /tmp -q /tmp/font-awesome-$FONTAWESOME.zip                                                                 \
 && mkdir -p /app/easywall/web/static/css/ && cp -r /tmp/font-awesome-$FONTAWESOME/css/* /app/easywall/web/static/css/  \
 && mkdir -p /app/easywall/web/static/fonts && cp -r /tmp/font-awesome-$FONTAWESOME/fonts/* /app/easywall/web/static/fonts/

FROM alpine:3.15

RUN apk add --no-cache                                                                                                  \
        bash                                                                                                            \
        iptables                                                                                                        \
        ip6tables                                                                                                       \
        openssl                                                                                                         \
        uwsgi-python3

COPY --from=builder /app /app
COPY config/*.sample.ini /usr/share/easywall/config/
RUN printf "%s = %s\n" "uid" "easywall" "gid" "easywall" >> /usr/share/easywall/config/web.sample.ini
COPY .version /app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN addgroup -S -g 777 easywall && adduser --system --uid 777 -h /app -s /bin/bash -G easywall easywall

VOLUME /app/ssl
VOLUME /app/config
# VOLUME /app/rules
WORKDIR /app
ENTRYPOINT /entrypoint.sh
