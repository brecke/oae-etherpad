#!/bin/bash
set -e

EP=/opt/etherpad

random_key() {
    dd if=/dev/urandom bs=64 count=1 2>/dev/null|sha256sum|cut -d' ' -f1|tr -d '\n'
}

cqlsh -f /opt/etherpad/init.cql oae-cassandra 9160

if [ "$EP/bin/run.sh" = "$1" ]; then
    # [ -r $EP/APIKEY.txt ] || random_key > $EP/APIKEY.txt
    [ -r $EP/SESSIONKEY.txt ] || random_key > $EP/SESSIONKEY.txt
    chown -R etherpad:etherpad $EP/settings.json $EP/var
    exec su-exec etherpad "$@"
fi

exec "$@"