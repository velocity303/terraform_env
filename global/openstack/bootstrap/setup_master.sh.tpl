#!/bin/bash
set -x
export PATH=$$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin

SERVER_NAME=puppet.infrastructure.lab
read -r -d '' PRIV_KEY << EOM
${ssh_pri_key}
EOM
read -r -d '' PUBLIC_KEY << EOM
${ssh_pub_key}
EOM
read -r -d '' LIC_KEY << EOM
${license_key}
EOM

DOWNLOAD_VERSION=$${DOWNLOAD_VERSION:-2017.2.3}
DOWNLOAD_DIST=$${DOWNLOAD_DIST:-el}
DOWNLOAD_RELEASE=$${DOWNLOAD_RELEASE:-7}
DOWNLOAD_ARCH=$${DOWNLOAD_ARCH:-x86_64}
DOWNLOAD_RC=$${DOWNLOAD_RC:-1}
GIT_REMOTE=${control_repo}

#Setup Prereqs
function setup_prereqs {
  yum -y install wget
  mkdir -p /etc/puppetlabs/puppetserver/ssh/
  mkdir -p /etc/puppetlabs/puppet
  yum -y install open-vm-tools

  hostnamectl set-hostname --static "$${SERVER_NAME}"
  echo 'preserve_hostname: true' >> /etc/cloud/cloud.cfg
  echo "127.0.0.1  $${SERVER_NAME}  puppet" > /etc/hosts
  yum clean all
  setenforce 0
}

function setup_users {
  usermod --password '$6$oDTfITCj$/RDXWiYpkTSUcJjfMfEdPsncaHWGW2FC8PoW39MgELECnwhcBmtxx00E4EnTwkhr1s4eaWz6aANuhE3w4cjE81' root
}

#Generate SSH Keys
function generate_keys {
#  ssh-keygen -t rsa -b 4096 -N "" -f /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
  echo "$${PRIV_KEY}" > /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
  echo "$${PUBLIC_KEY}" > /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub
  chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh
  chmod 0600 /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
}

#Download PE
function download_pe {
  #https://github.com/glarizza/pe_curl_requests/blob/master/installer/download_pe_tarball.sh
  DOWNLOAD_MVER=$(echo $$DOWNLOAD_VERSION|awk -F '.' '{print $$1"."$$2}')


  DOWNLOAD_URL="https://pm.puppetlabs.com/cgi-bin/download.cgi?dist=$${DOWNLOAD_DIST}&rel=$${DOWNLOAD_RELEASE}&arch=$${DOWNLOAD_ARCH}&ver=$${DOWNLOAD_VERSION}"
  TAR_OPTS="-xzf"
  TAR_NAME="puppet-enterprise-$${DOWNLOAD_VERSION}-$${DOWNLOAD_DIST}-$${DOWNLOAD_RELEASE}-$${DOWNLOAD_ARCH}.tar.gz"

  echo "Downloading PE $${DOWNLOAD_VERSION} for $${DOWNLOAD_DIST}-$${DOWNLOAD_RELEASE}-$${DOWNLOAD_ARCH} to: $${TAR_NAME}"
  echo
  curl --progress-bar \
    -L \
    -o "./$${TAR_NAME}" \
    -C - \
    "$${DOWNLOAD_URL}"

  tar $$TAR_OPTS $$TAR_NAME -C /tmp/
}

# Install Agent
function install_agent {
  rpm -Uhv /tmp/puppet-enterprise-$$DOWNLOAD_VERSION-$$DOWNLOAD_DIST-$$DOWNLOAD_RELEASE-$$DOWNLOAD_ARCH/packages/el-7-x86_64/puppet-agent-*.rpm
}

#Setup PE
function install_pe {
  echo "$${LIC_KEY}" > /etc/puppetlabs/license.key
  cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
  extension_requests:
      pp_role:  master_server
YAML
  cat > /tmp/pe.conf << FILE
"console_admin_password": "puppetlabs"
"puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
"puppet_enterprise::profile::master::code_manager_auto_configure": true
"puppet_enterprise::profile::master::r10k_remote": "git@localhost:puppet/control-repo.git"
"puppet_enterprise::profile::master::r10k_private_key": "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
FILE
  /tmp/puppet-enterprise-$DOWNLOAD_VERSION-$DOWNLOAD_DIST-$DOWNLOAD_RELEASE-$DOWNLOAD_ARCH/puppet-enterprise-installer -c /tmp/pe.conf
  chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh
}

#Setup Code Manager

function add_pe_users {
/opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \
        https://$SERVER_NAME:4433/rbac-api/v1/roles \
        https://$SERVER_NAME:4433/rbac-api/v1/roles \
        -d '{"description":"","user_ids":[],"group_ids":[],"display_name":"Node Data Viewer","permissions":[{"object_type":"nodes","action":"view_data","instance":"*"}]}' \
        --cert //etc/puppetlabs/puppet/ssl/certs/$SERVER_NAME.pem \
        --key //etc/puppetlabs/puppet/ssl/private_keys/$SERVER_NAME.pem \
        --cacert //etc/puppetlabs/puppet/ssl/certs/ca.pem

  /opt/puppetlabs/puppet/bin/curl -k -X POST -H 'Content-Type: application/json' \
          https://$SERVER_NAME:4433/rbac-api/v1/users \
          -d '{"login": "deploy", "password": "puppetlabs", "email": "", "display_name": "", "role_ids": [2,5]}' \
          --cert //etc/puppetlabs/puppet/ssl/certs/$SERVER_NAME.pem \
          --key //etc/puppetlabs/puppet/ssl/private_keys/$SERVER_NAME.pem \
          --cacert //etc/puppetlabs/puppet/ssl/certs/ca.pem

  /opt/puppetlabs/bin/puppet-access login deploy --lifetime=1y -t /root/.puppetlabs/token << TEXT
puppetlabs
TEXT
}

function setup_git {
  /opt/puppetlabs/bin/puppet module install kschu91-gogs --version 1.1.0
  cat > /tmp/git.pp << FILE
class {'gogs':
  app_ini          => {
    'APP_NAME' => 'TSE Demo Master Git Server',
    'RUN_USER' => 'git',
    'RUN_MODE' => 'prod',
  },
  app_ini_sections => {
    'server'     => {
      'DOMAIN'           => $::fqdn,
      'HTTP_PORT'        => 3000,
      'ROOT_URL'         => "https://$(hostname -f)/",
      'HTTP_ADDR'        => '0.0.0.0',
      'DISABLE_SSH'      => false,
      'SSH_PORT'         => '22',
      'START_SSH_SERVER' => false,
      'OFFLINE_MODE'     => false,
    },
    'database'   => {
      'DB_TYPE'  => 'sqlite3',
      'HOST'     => '127.0.0.1:3306',
      'NAME'     => 'gogs',
      'USER'     => 'root',
      'PASSWD'   => '',
      'SSL_MODE' => 'disable',
      'PATH'     => '/opt/gogs/data/gogs.db',
    },
    'security'   => {
      'SECRET_KEY'   => 'thesecretkey',
      'INSTALL_LOCK' => true,
    },
    'service'    => {
      'REGISTER_EMAIL_CONFIRM' => false,
      'ENABLE_NOTIFY_MAIL'     => false,
      'DISABLE_REGISTRATION'   => false,
      'ENABLE_CAPTCHA'         => true,
      'REQUIRE_SIGNIN_VIEW'    => false,
    },
    'repository' => {
      'ROOT'     => '/var/git',
    },
    'mailer'     => {
      'ENABLED' => false,
    },
    'picture'    => {
      'DISABLE_GRAVATAR'        => false,
      'ENABLE_FEDERATED_AVATAR' => true,
    },
    'session'    => {
      'PROVIDER' => 'file',
    },
    'log'        => {
      'MODE'      => 'file',
      'LEVEL'     => 'info',
      'ROOT_PATH' => '/opt/gogs/log',
    },
    'webhook'    => {
      'SKIP_TLS_VERIFY' => true,
    },
  },
  manage_user      => true,
}

FILE

  /opt/puppetlabs/bin/puppet apply /tmp/git.pp

  cd /tmp
  su - git -c '/opt/gogs/gogs admin create-user --name=puppet --password=puppetlabs --email='puppet@localhost.local' --admin=true'

  echo "{\"clone_addr\": \"$${GIT_REMOTE}\", \"uid\": 1, \"repo_name\": \"control-repo\"}" > repo.data
  curl -H 'Content-Type: application/json' -X POST -d @repo.data http://puppet:puppetlabs@localhost:3000/api/v1/repos/migrate
  if [ $? -ne 0 ]; then
    echo "Gogs: Failed to create control-repo"
    exit 5
  fi

  PUB_KEY=$(cat /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub)
  echo "{\"title\":\"puppet master key\",\"key\":\""$${PUB_KEY}\""}" > input.data
  curl -H 'Content-Type: application/json' -X POST -d @input.data http://puppet:puppetlabs@localhost:3000/api/v1/admin/users/puppet/keys
  if [ $? -ne 0 ]; then
    echo "Gogs: Failed to create public key"
    exit 6
  fi

  # Prune non-production branches
  echo "Pruning branches...."
  mkdir ~/.ssh
  chmod 700 ~/.ssh
  ssh-keyscan localhost > ~/.ssh/known_hosts
  echo -e "Host localhost\n\tIdentityFile /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa" > ~/.ssh/config
  git clone git@localhost:puppet/control-repo.git control-repo
  cd control-repo

  for i in $(git branch -a|grep -v production|awk -F '/' '{print $3}')
  do
    git push origin :$${i}
  done
  cd ../

  rm -rf /tmp/control-repo
  rm /tmp/git.pp
  rm /tmp/repo.data
  rm /tmp/input.data

}

#Deploy Code
function deploy_code_pe {
  /opt/puppetlabs/bin/puppet-code deploy production -w
}

function setup_hiera_pe {
  /opt/puppetlabs/bin/puppetserver gem install hiera-eyaml
  /opt/puppetlabs/puppet/bin/gem install hiera-eyaml
  if [ -f /vagrant/keys/private_key.pkcs7.pem ]
    then
      rm /etc/puppetlabs/puppet/keys/*
      cp /vagrant/keys/private_key.pkcs7.pem /etc/puppetlabs/puppet/keys/.
      cp /vagrant/keys/public_key.pkcs7.pem /etc/puppetlabs/puppet/keys/.
  fi
}

#Kick Off First Puppet Run
function run_puppet {
  cd /
  /opt/puppetlabs/bin/puppet agent -t
}

# Generate Offline Control Repo
function offline_control_repo {
  /opt/puppetlabs/puppet/bin/ruby /etc/puppetlabs/code/environments/production/scripts/local_control_repo.rb \
    -c /home/git/puppetpov/control-repo.git \
    -o /home/git/puppetpov/offline-control-repo.git
  chown -R git:git /home/git/puppetpov/offline-control-repo.git
}

#Remove Certs and Sanitize Hostname in puppet.conf
function clean_certs {
  /opt/puppetlabs/bin/puppet apply -e "include profile::puppet::clean_certs"
}

function vagrant_setup {
  id vagrant &>/dev/null || useradd -m vagrant
  mkdir /home/vagrant/.ssh
  wget --no-check-certificate https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -O /home/vagrant/.ssh/authorized_keys
  wget --no-check-certificate https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant -O /home/vagrant/.ssh/id_rsa
  chmod 700 /home/vagrant/.ssh
  chmod 600 /home/vagrant/.ssh/authorized_keys
  chown -R vagrant:vagrant /home/vagrant/.ssh
  echo "vagrant" | passwd --stdin vagrant
  cat > /etc/sudoers.d/10_sudovagrant << SUDOVAGRANT
vagrant ALL=(ALL) NOPASSWD: ALL
SUDOVAGRANT
}

function guest_additions {
  yum groupinstall "Development Tools"
  yum install -y gcc kernel-devel kernel-headers dkms make bzip2 perl
  mkdir /tmp/vboxguest
  wget http://download.virtualbox.org/virtualbox/5.1.14/VBoxGuestAdditions_5.1.14.iso
  KERN_DIR=/usr/src/kernels/`uname -r`
  export KERN_DIR
  mkdir /media/VBoxGuestAdditions
  mount -o loop,ro VBoxGuestAdditions_5.1.14.iso /media/VBoxGuestAdditions
  sh /media/VBoxGuestAdditions/VBoxLinuxAdditions.run
  rm VBoxGuestAdditions_5.1.14.iso
  umount /media/VBoxGuestAdditions
  rmdir /media/VBoxGuestAdditions
}

function add_gogs_webhook {
  echo "{\"type\":\"gogs\",\"config\":\
    {\"url\":\"https://localhost:8170/code-manager/v1/webhook?type=github&token=\$(cat /root/.puppetlabs/token)\",\"content_type\":\"json\"},\
    \"events\":[\"push\"],\"active\":true}" > hook.data
  curl -H 'Content-Type: application/json' -X POST -d @hook.data http://puppet:puppetlabs@localhost:3000/api/v1/repos/puppet/control-repo/hooks
  rm -f hook.data
}

function cleanup {
  rm -rf /tmp/puppet-enterprise*
  rm -f  /root/puppet-enterprise-*.tar.gz
}


# Main
setup_prereqs
setup_users
generate_keys

download_pe
install_agent
setup_git
install_pe
add_pe_users
deploy_code_pe
sleep 15
setup_hiera_pe
run_puppet
run_puppet
run_puppet
add_gogs_webhook
cleanup

exit 0
