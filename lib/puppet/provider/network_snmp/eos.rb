# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:network_snmp).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('snmp').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash.merge!(result)
    [new(provider_hash)]
  end

  def enable=(value)
    not_supported 'enable'
  end

  def contact=(value)
    node.api('snmp').set_contact(value: value)
    @property_hash[:contact] = value
  end

  def location=(value)
    node.api('snmp').set_location(value: value)
    @property_hash[:location] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
