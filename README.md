# Arista EOS Puppet Providers

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [What NetDev EOS affects](#what-netdev_stdlib_eos-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with NetDev EOS Providers](#beginning-with-netdev_stdlib_eos)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This module adds Arista EOS support for the [NetDev Standard Type
Library](https://github.com/puppetlabs/netdev_stdlib).  This module makes it
possible to configure switch settings and resources using Puppet running
natively on an Arista EOS switch.

## Module Description

If you have Arista EOS switches in your environment this module will enable you
to configure those switches using Puppet.  The EOS providers implement all of
the types listed in the [NetDev Standard Type
Library](https://github.com/puppetlabs/netdev_stdlib).  This module extends
Puppet to configure networking resources such as VLAN's, physical interfaces,
link aggregates, SNMP settings, among other things.  The module requires an
Arista EOS switching running software version 4.13 or later with the Puppet
Enterprise extension installed on the device.  The Puppet agent running on the
switch will use pluginsync to download the types and providers from the Puppet
master.

## Setup

### What NetDev EOS affects

These providers configure the Arista switch in a similar fashion to using the
command line interface.

### Setup Requirements

This module requires pluginsync in order to synchronize the types and providers
to the device.

### Beginning with netdev_stdlib_eos

 1. Install the module on the Puppet master.
 2. Run the puppet agent on the switch to synchronize the types and providers.
 3. Verify the providers by running `puppet resource network_interface` using
    the bash command on the EOS device.

```
veos# bash puppet resource network_interface
network_interface { 'Ethernet1':
  description => 'Engineering',
  duplex      => 'full',
  enable      => 'true',
  mtu         => '9214',
  speed       => '10g',
}
network_interface { 'Ethernet2':
  description => 'Sales',
  duplex      => 'full',
  enable      => 'false',
  mtu         => '9214',
  speed       => '10g',
}
network_interface { 'Ethernet3':
  duplex => 'full',
  enable => 'true',
  mtu    => '9214',
  speed  => '10g',
}
network_interface { 'Ethernet4':
  duplex => 'full',
  enable => 'true',
  mtu    => '9214',
  speed  => '10g',
}
network_interface { 'Management1':
  duplex => 'full',
  enable => 'true',
  mtu    => '1500',
  speed  => '1g',
}
```

## Usage

Please see the [NetDev Standard Type Library][netdev]

## Reference

TBA

## Limitations

This module is supported on

 * Puppet 3.6 or later installed as an Arista EOS extension
 * Arista EOS 4.13 or later

## Development

To be added.

[netdev]: https://github.com/puppetlabs/netdev_stdlib
