# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:ntp_config).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('ntp').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:source_interface] = result[:source_interface]
    [new(provider_hash)]
  end

  def source_interface=(val)
    node.api('ntp').set_source_interface(value: val)
    @property_hash[:source_interface] = val
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
