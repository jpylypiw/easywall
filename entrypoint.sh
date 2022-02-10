#!/bin/bash -e

update_config() {
    local file="$2"
    local global_prefix="INI_${1^^}"
    if [ -z "$(compgen -v "$global_prefix")" ]; then
        return 0
    fi
    awk -F '[^0-9a-zA-Z-]' -v global_prefix="$global_prefix" '
        BEGIN {
            ln = 0
        }
        /^\[.*\]$/ {
            group = toupper($2);
            gsub(/[^A-Z0-9]/, "_", group);
        }
        $1 != "" {
            prop = toupper($1);
            gsub(/[^A-Z0-9]/, "_", prop);
            value = ENVIRON[sprintf("%s_%s_%s", global_prefix, group, prop)];
            if (value != "") {
                if ($0 ~ /^[^=]*=[[:space:]]*"/) {
                    lines[++ln] = sprintf("%s = \"%s\"", $1, value);
                } else {
                    lines[++ln] = sprintf("%s = %s", $1, value);
                }
                next;
            }
        }
        {
            lines[++ln] = $0;
        }
        END {
            for(c = 1; c <= ln; c++) print lines[c] > ARGV[1]
        }
    ' "${file}"
}

: "${EASYWALL_SSL_ENABLED:="true"}"

mkdir -p config
for config in easywall log web; do
    cp /usr/share/easywall/config/$config.sample.ini config/$config.sample.ini
    if [ ! -f config/$config.ini ]; then
        cp config/$config.sample.ini config/$config.ini
    fi
    if [ "$config" == "web" ] && [ "$SSL_ENABLED" == "false" ]; then
        sed -i 's/^https-socket/http-socket/g' config/$config.ini
    fi
    update_config $config config/$config.ini
done

if [ "$EASYWALL_SSL_ENABLED" == "true" ] && [ ! -f ssl/easywall.crt ]; then
    mkdir -p ssl
    (
        PASSPHRASE="$(
            head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128
            echo
        )" &&
            export PASSPHRASE &&
            openssl genrsa -des3 -out ssl/easywall.key -passout env:PASSPHRASE 4096 &&
            openssl req -new -batch -key ssl/easywall.key -out ssl/easywall.csr -passin env:PASSPHRASE -subj "$(
                printf "/%s=%s" \
                    "C" "${EASYWALL_SSL_CRT_CONTRY:-"DE"}" \
                    "ST" "${EASYWALL_SSL_CRT_CITY:-"Berlin"}" \
                    "O" "${EASYWALL_SSL_CRT_ORG:-"easywall"}" \
                    "localityName" "${EASYWALL_SSL_CRT_REGION:-"Berlin"}" \
                    "commonName" "${EASYWALL_SSL_CRT_CN:-"$(hostname -f)"}" \
                    "organizationalUnitName" "${EASYWALL_SSL_CRT_OU:-"IT"}" \
                    "emailAddress" "${EASYWALL_SSL_CRT_EMAIL:-"admin@example.com"}"
            )" &&
            openssl rsa -in ssl/easywall.key -out ssl/easywall.key -passin env:PASSPHRASE &&
            openssl x509 -req -days 3650 -in ssl/easywall.csr -signkey ssl/easywall.key -out ssl/easywall.crt
    )
    chmod 700 ssl
    chmod -R 600 ssl/*
fi
chown easywall:easywall -R .

touch /var/log/easywall.log
chown easywall:easywall /var/log/easywall.log

export PYTHONPATH=/app
uwsgi config/web.ini &
/usr/bin/env python3 -m easywall
