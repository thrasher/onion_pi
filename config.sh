#!/bin/bash

# expand the filesystem
# set pi user password
# change locale to en_US (uncheck (en_GB)
# advanced : enable ssh

function update {
  apt-get -y update
  apt-get -y upgrade
}

function install_node {
  echo "Installing Node.js"
  curl http://nodejs.org/dist/v0.10.28/node-v0.10.28-linux-arm-pi.tar.gz -O
  tar -xvzf node-v0.10.28-linux-arm-pi.tar.gz
  mv node-v0.10.28-linux-arm-pi /usr/bin/.
  ln -s /usr/bin/node-v0.10.28-linux-arm-pi /usr/bin/node
  cat >> /etc/environment << EOF
NODE_JS_HOME=/usr/bin/node
EOF
  cat >> ~/.profile << EOF
NODE_JS_HOME=/usr/bin/node
export PATH=\$PATH:\$NODE_JS_HOME/bin
EOF
  . ~/.profile
  node --version
  npm version
  gcc --version

  # optional: install the native bridge
  npm install -g node-gyp
}


case "$1" in
  update)
    update
    ;;
  install_node)
    install_node
    ;;
  *)
    echo "Usage: $0 { update | install_node }"
    exit 1
esac

exit 0
