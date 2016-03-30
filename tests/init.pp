# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# http://docs.puppetlabs.com/guides/tests_smoke.html
#
domain_name { 'example.com':
  ensure => present,
}

name_server { '8.8.8.8':
  ensure => present,
}

network_dns { 'settings':
  domain  => 'example.com',
  search  => ['sub1.example.com', 'sub2.example.com'],
  servers => ['8.8.8.8', '8.8.4.4'],
}

network_interface { 'Ethernet1':
  enable      => true,
  duplex      => 'auto',
  speed       => 'auto',
  description => 'Configured by Puppet',
}

network_snmp { 'settings':
  contact  => 'noc@example.com',
  location => 'DC01, Somewhere',
}

network_vlan { '200':
  ensure    => present,
  vlan_name => 'Test_200',
  shutdown  => false,
}

network_vlan { '300':
  ensure    => present,
  vlan_name => 'Test_300',
  shutdown  => false,
}

network_trunk { 'Ethernet2':
  mode           => 'trunk',
  #tagged_vlans   => ['200', '300'],
  #untagged_vlan  => '1'
}

ntp_config { 'settings':
  source_interface => 'Management1',
}

ntp_server { 'pool.ntp.org':
  ensure => present,           # create
  prefer => true,
}

port_channel { 'Port-Channel100':
  ensure        => present,
  description   => 'Link to other switch',
  force         => true,
  interfaces    => ['Ethernet3', 'Ethernet4'],
  minimum_links => 1,
}

radius { 'settings':
  enable => 'true', # not required on EOS
}

radius_global { 'settings':
  key_format       => '0',
  retransmit_count => '10',
  timeout          => '10',
}

# name format: <hostname|ip>/<auth_port>/<acct_port>
radius_server { '192.0.2.51/1812/1813':
  hostname  => '192.0.2.51',
  auth_port => 1812,
  acct_port => 1813,
  key       => '075E6141573612000E',
  #vrf       => 'mgmt',
}

radius_server_group { 'rad-prod':
  ensure => absent,
}

radius_server_group { 'prod-radus':
  servers => ['192.0.2.51/1812/1813'],
}

search_domain { 'sub1.example.com':
  ensure => present,
}

snmp_community { 'public':
  group => 'ro',
}

snmp_notification { 'entity':
  enable => true,
}

snmp_notification_receiver { 'traphost.example.com':
  type     => 'informs',
  version  => 'v3',
  security => 'priv',
  username => 'trapuser',
  #vrf      => 'mgmt',
}

# name format: <hostname|ip>/<auth_port>/<acct_port>
snmp_user { 'trapuser:v3':
  roles           => ['ops'],
  enforce_privacy => true,
  localized_key   => false,
  auth            => 'sha',
  password        => '59049ce9523878cbd1e930062e40d1848d2d80b8',
  privacy         => 'aes128',
  private_key     => 'b2f0f1ce083aca9e50e33fe4e73982ac813b77c4',
}

syslog_server { '1.2.3.4':
  ensure => 'present',
}

tacacs { 'settings':
  enable => true, # not required on EOS
}

tacacs_global { 'settings':
  timeout => '5',
}

# name format: <hostname|ip>/[vrf]/<port>
tacacs_server { 'tacacs1.example.com//49':
  ensure     => 'present',
  hostname   => 'tacacs1.example.com',
  port       => '49',
  key        => '060D0A38735D1D0B0C1915',
  key_format => '7',
}
#tacacs_server { 'tacacs1.example.com/mgmt/49':
#  ensure     => 'present',
#  hostname   => 'tacacs1.example.com',
#  vrf        => 'mgmt',
#  port       => '49',
#  key        => '060D0A38735D1D0B0C1915',
#  key_format => '7',
#}

tacacs_server_group { 'production':
  ensure  => present,
  servers => ['tacacs1.example.com//49'],
}
