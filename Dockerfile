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

#
# Setup in two steps
#
# Step 1: Build the image
# $ docker build -f Dockerfile -t oae-etherpad:latest .
# Step 2: Run the docker
# $ docker run -it --name=etherpad --net=host oae-etherpad:latest
#

FROM buildpack-deps:jessie-scm
LABEL Name=hilary Version=12.5.0
MAINTAINER Apereo Foundation <which.email@here.question>

# node
RUN apt-get update && apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bzip2 \
		file \
		g++ \
		gcc \
    git \
		graphicsmagick \
		libbz2-dev \
		libc6-dev \
		libcurl4-openssl-dev \
		libevent-dev \
		libffi-dev \
		libgeoip-dev \
		libglib2.0-dev \
		libjpeg-dev \
		liblzma-dev \
		libmagickcore-dev \
		libmagickwand-dev \
		libmysqlclient-dev \
		libncurses-dev \
		libpng-dev \
		libpq-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		libtool \
		libwebp-dev \
		libxml2-dev \
		libxslt-dev \
		libyaml-dev \
		make \
		patch \
    python-pip \
		xz-utils \
		zlib1g-dev \
	&& rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 6.10.0

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

ENV YARN_VERSION 0.21.3

RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done \
  && curl -fSL -o yarn.js "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-legacy-$YARN_VERSION.js" \
  && curl -fSL -o yarn.js.asc "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-legacy-$YARN_VERSION.js.asc" \
  && gpg --batch --verify yarn.js.asc yarn.js \
  && rm yarn.js.asc \
  && mv yarn.js /usr/local/bin/yarn \
  && chmod +x /usr/local/bin/yarn

# install etherpad and apply configuration
RUN mkdir -p /opt && cd /opt
WORKDIR /opt/
RUN git clone https://github.com/ether/etherpad-lite.git etherpad && cd etherpad && mv settings.json.template settings.json && touch APIKEY.txt

WORKDIR /opt/etherpad/

# Install node dependencies
RUN /opt/etherpad/bin/installDeps.sh

# Next two lines are production config ONLY
RUN sed -i -e 's/dbType\" : \"dirty/dbType\" : \"cassandra/g' settings.json
RUN sed -i -e 's/"filename" : "var\/dirty.db"/"clientOptions": {"keyspace": "etherpad", "port": "9160", "contactPoints": ["oae-cassandra"]},"columnFamily": "Etherpad"/g' settings.json

RUN sed -i -e 's/defaultPadText" : ".*"/defaultPadText" : ""/g' settings.json
RUN echo "13SirapH8t3kxUh5T5aqWXhXahMzoZRA" > APIKEY.txt

# We need to run a specific cqlsh command before this works
RUN pip install cqlsh==4.0.1
RUN echo "CREATE KEYSPACE etherpad WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};" > /tmp/.create_etherpad_keyspace.cql3

# Install ep_headings module
RUN cd /opt/etherpad && npm install ep_headings

# Etherpad OAE plugin
RUN cd /opt/etherpad/node_modules && git clone https://github.com/oaeproject/ep_oae && cd ep_oae && npm install

# Not strictly necessary if we're using default IP and port
RUN sed -i -e '/defaultPadText/a \
    "ep_oae": {"mq": { "host": "oae-rabbitmq", "port": 5672 } },' settings.json

# CSS changes
RUN cd /opt/etherpad && rm node_modules/ep_headings/templates/editbarButtons.ejs && cp node_modules/ep_oae/static/templates/editbarButtons.ejs node_modules/ep_headings/templates/editbarButtons.ejs
RUN cd /opt/etherpad/ && rm src/static/custom/pad.css && cp node_modules/ep_oae/static/css/pad.css src/static/custom/pad.css

# Edit protocols in config
RUN sed -i -e 's/\["xhr-polling", "jsonp-polling", "htmlfile"\],/\["websocket", "xhr-polling", "jsonp-polling", "htmlfile"\],/g' settings.json

# Edit toolbar in config
RUN sed -i -e '/"loadTest/a \
"toolbar": {"left": [["bold", "italic", "underline", "strikethrough", "orderedlist", "unorderedlist", "indent", "outdent"]],"right": [["showusers"]]},' settings.json

EXPOSE 9001

RUN groupadd --gid 1001 etherpad && useradd --uid 1001 --gid etherpad --shell /bin/bash --create-home etherpad

CMD cqlsh -f /tmp/.create_etherpad_keyspace.cql3 oae-cassandra 9160 && bin/run.sh --root
# CMD ["bin/run.sh", "--root"]

# TODO try to run this as non-root if possible
# CMD ["su", "-", "etherpad", "-c", "/bin/sh /opt/etherpad/bin/run.sh"]

