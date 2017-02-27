#!/bin/bash
# This bootstraps Puppet on CentOS 7.x
# It has been tested on CentOS 7.0 64bit

#SCRIPT TO DO
#
# 1. This script should be able to set up r10k as seperate user
# 2. This script should set up puppetserver to run as seperate user
SERVER_NAME=puppet.${location}.lab
CONTROL_REPO=${control_repo}
read -r -d '' PRIV_KEY << EOM
${ssh_pri_key}
EOM
read -r -d '' PUBLIC_KEY << EOM
${ssh_pub_key}
EOM
DOWNLOAD_VERSION=$${DOWNLOAD_VERSION:-2016.5.1}
DOWNLOAD_DIST=$${DOWNLOAD_DIST:-el}
DOWNLOAD_RELEASE=$${DOWNLOAD_RELEASE:-7}
DOWNLOAD_ARCH=$${DOWNLOAD_ARCH:-x86_64}
DOWNLOAD_RC=$${DOWNLOAD_RC:-1}
GIT_REMOTE=$${GIT_REMOTE:-"$${CONTROL_REPO}"}

set -x

#Setup Prereqs
function setup_prereqs {
  yum -y install wget
  mkdir -p /etc/puppetlabs/puppetserver/ssh/
  mkdir -p /etc/puppetlabs/puppet
  ln -s /etc/puppetlabs/code/environments/production/scripts/reconfigure_host.sh /usr/local/bin/reconfigurehost
cat > /etc/hosts << EOM
127.0.0.1   ${hostname}.${location}.lab ${hostname} localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOM
}

function setup_users {
  echo "Adding user puppetpov"
  useradd -m -p '$6$oDTfITCj$/RDXWiYpkTSUcJjfMfEdPsncaHWGW2FC8PoW39MgELECnwhcBmtxx00E4EnTwkhr1s4eaWz6aANuhE3w4cjE81' puppetpov
  usermod --password '$6$oDTfITCj$/RDXWiYpkTSUcJjfMfEdPsncaHWGW2FC8PoW39MgELECnwhcBmtxx00E4EnTwkhr1s4eaWz6aANuhE3w4cjE81' root
}

#Generate SSH Keys
function generate_keys {
  mkdir /home/puppetpov/.ssh
  chown puppetpov:puppetpov /home/puppetpov
  ssh-keygen -t rsa -b 4096 -N "" -f /home/puppetpov/.ssh/id_rsa
  cat > /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa << PRIVATE
$PRIV_KEY
PRIVATE

  cat > /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub << PUBLIC
$PUBLIC_KEY
PUBLIC
  chown pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub
  chown pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
  chown puppetpov:puppetpov /home/puppetpov/.ssh/*
}

#Download PE
function download_pe {
  #https://github.com/glarizza/pe_curl_requests/blob/master/installer/download_pe_tarball.sh
  DOWNLOAD_MVER=$(echo $DOWNLOAD_VERSION|awk -F '.' '{print $1"."$2}')

  if [ $DOWNLOAD_RC -eq 0 ]; then
    DOWNLOAD_URL="http://enterprise.delivery.puppetlabs.net/$${DOWNLOAD_MVER}/ci-ready/puppet-enterprise-$${DOWNLOAD_VERSION}-$${DOWNLOAD_DIST}-$${DOWNLOAD_RELEASE}-$${DOWNLOAD_ARCH}.tar"
    TAR_OPTS="-xf"
    TAR_NAME="puppet-enterprise-$${DOWNLOAD_VERSION}-$${DOWNLOAD_DIST}-$${DOWNLOAD_RELEASE}-$${DOWNLOAD_ARCH}.tar"
  else
    DOWNLOAD_URL="https://pm.puppetlabs.com/cgi-bin/download.cgi?dist=$${DOWNLOAD_DIST}&rel=$${DOWNLOAD_RELEASE}&arch=$${DOWNLOAD_ARCH}&ver=$${DOWNLOAD_VERSION}"
    TAR_OPTS="-xzf"
    TAR_NAME="puppet-enterprise-$${DOWNLOAD_VERSION}-$${DOWNLOAD_DIST}-$${DOWNLOAD_RELEASE}-$${DOWNLOAD_ARCH}.tar.gz"
  fi

  echo "Downloading PE $DOWNLOAD_VERSION for $${DOWNLOAD_DIST}-$${DOWNLOAD_RELEASE}-$${DOWNLOAD_ARCH} to: $${TAR_NAME}"
  echo
  curl --progress-bar \
    -L \
    -o "./$${TAR_NAME}" \
    -C - \
    $DOWNLOAD_URL

  tar $TAR_OPTS $TAR_NAME -C /tmp/
}

#Setup PE
function install_pe {
  cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
  extension_requests:
      pp_role:  puppetmaster
YAML
  cat > /tmp/pe.conf << FILE
"console_admin_password": "puppetlabs"
"puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
"puppet_enterprise::profile::master::code_manager_auto_configure": true
"puppet_enterprise::profile::master::r10k_remote": "$${GIT_REMOTE}"
"puppet_enterprise::profile::master::r10k_private_key": "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
FILE
  /tmp/puppet-enterprise-$DOWNLOAD_VERSION-$DOWNLOAD_DIST-$DOWNLOAD_RELEASE-$DOWNLOAD_ARCH/puppet-enterprise-installer -c /tmp/pe.conf
  chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh
}

#Setup Code Manager

function add_pe_users {
/opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \
        https://`facter fqdn`:4433/rbac-api/v1/roles \
        https://`facter fqdn`:4433/rbac-api/v1/roles \
        -d '{"description":"","user_ids":[],"group_ids":[],"display_name":"Node Data Viewer","permissions":[{"object_type":"nodes","action":"view_data","instance":"*"}]}' \
        --cert /`puppet config print ssldir`/certs/`facter fqdn`.pem \
        --key /`puppet config print ssldir`/private_keys/`facter fqdn`.pem \
        --cacert /`puppet config print ssldir`/certs/ca.pem

  /opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \
          https://`facter fqdn`:4433/rbac-api/v1/users \
          -d '{"login": "deploy", "password": "puppetlabs", "email": "", "display_name": "", "role_ids": [2,5]}' \
          --cert /`puppet config print ssldir`/certs/`facter fqdn`.pem \
          --key /`puppet config print ssldir`/private_keys/`facter fqdn`.pem \
          --cacert /`puppet config print ssldir`/certs/ca.pem

  /opt/puppetlabs/bin/puppet-access login deploy --lifetime=1y << TEXT
puppetlabs
TEXT
}

#Deploy Code
function deploy_code_pe {
  #create license key for bootstrap
  curl --progress-bar \
    -L \
    -o "/etc/puppetlabs/license.key" \
    -C - \
    https://raw.githubusercontent.com/puppetlabs-seteam/puppet-module-role/master/files/license.key
  /opt/puppetlabs/bin/puppet-code deploy production -w
}

function setup_hiera_pe {
  /opt/puppetlabs/bin/puppetserver gem install hiera-eyaml
  /opt/puppetlabs/puppet/bin/gem install hiera-eyaml
  /opt/puppetlabs/bin/puppet apply -e "include profile::puppet::hiera"
}

#Kick Off First Puppet Run
function run_puppet {
  cd /
  /opt/puppetlabs/bin/puppet agent -t
}

function binary_cleanup {
  rm -rf /tmp/puppet-enterprise*
  rm -f  /root/puppet-enterprise-*.tar.gz
}


setup_prereqs
setup_users
generate_keys
download_pe
install_pe
add_pe_users
deploy_code_pe
sleep 15
setup_hiera_pe
run_puppet
run_puppet
binary_cleanup
exit 0
