#/bin/bash

export GEM_HOME=$(pwd)/.gem
export GEM_PATH=$GEM_HOME/gems

export PATH=$GEM_HOME/bin:$PATH

if ! [ -d .restfully ]; then mkdir .restfully; fi
if ! [ -f .restfully/api.grid5000.fr.yml ]; then
  cat > .restfully/api.grid5000.fr.yml << EOF
base_uri: https://api.grid5000.fr/stable/grid5000
cache: false
verify_ssl: false
EOF
fi

export RESTFULLY_CONFIG=$(pwd)/.restfully/api.grid5000.fr.yml

