# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:syslog_settings).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('logging').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:enable] = result[:enable].to_s.to_sym
    [new(provider_hash)]
  end

  def enable=(value)
    val = value == :true
    node.api('logging').set_enable(value: val)
    @property_hash[:enable] = value
  end

  def time_stamp_units=(value)
    not_supported 'time_stamp_units'
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
