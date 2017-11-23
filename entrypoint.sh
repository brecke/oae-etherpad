#
# Copyright 2017 Apereo Foundation (AF) Licensed under the
# Educational Community License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may
# obtain a copy of the License at
#
#     http://opensource.org/licenses/ECL-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an "AS IS"
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing
# permissions and limitations under the License.
#

#!/bin/bash
set -e

EP=/opt/etherpad

random_key() {
    dd if=/dev/urandom bs=64 count=1 2>/dev/null|sha256sum|cut -d' ' -f1|tr -d '\n'
}

cqlsh -f /opt/etherpad/init.cql oae-cassandra 9160

if [ "$EP/bin/run.sh" = "$1" ]; then
    [ -r $EP/APIKEY.txt ] || random_key > $EP/APIKEY.txt
    [ -r $EP/SESSIONKEY.txt ] || random_key > $EP/SESSIONKEY.txt
    # touch $EP/node_modules/ep_etherpad-lite/.ep_initialized
    chown -R etherpad:etherpad $EP/settings.json $EP/var
    exec su-exec etherpad "$@"
fi

exec "$@"