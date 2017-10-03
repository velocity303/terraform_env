#!/bin/bash
role=${role}
server_name=${name}
master_ip=${masterip}
master_host=${master_name}

function setup_networking {
  echo "$server_name" > /etc/hostname
  hostname $server_name
  echo "127.0.0.1 $server_name localhost.localdomain localhost" > /etc/hosts
  echo "$master_ip $master_host puppet" >> /etc/hosts
}

function install_prereqs {
  yum -y install curl
}

function install_poss_puppetagent {
  rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm
  yum -y install puppet-agent
  echo '[agent]' >> /etc/puppetlabs/puppet/puppet.conf
  echo "server = puppet" >> /etc/puppetlabs/puppet/puppet.conf
  cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
extension_requests:
    pp_role:  $role
YAML

  service puppet start
}

function install_pe_puppetagent {
  mkdir -p /etc/puppetlabs/puppet
  echo '[agent]' >> /etc/puppetlabs/puppet/puppet.conf
  echo "server = puppet" >> /etc/puppetlabs/puppet/puppet.conf
  cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
extension_requests:
    pp_role:  $role
YAML
  curl -k https://puppet:8140/packages/current/install.bash | bash
  service puppet start
}

setup_networking
install_prereqs
install_pe_puppetagent
