# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:ntp_config).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('ntp').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:authenticate] = result[:authenticate].to_s.to_sym
    provider_hash[:source_interface] = result[:source_interface]
    provider_hash[:trusted_key] = [result[:trusted_key]]
    [new(provider_hash)]
  end

  def authenticate=(value)
    val = value == :true
    node.api('ntp').set_authenticate(enable: val)
    @property_hash[:authenticate] = val
  end

  def source_interface=(val)
    node.api('ntp').set_source_interface(value: val)
    @property_hash[:source_interface] = val
  end

  def trusted_key=(val)
    node.api('ntp').set_trusted_key(default: true)
    node.api('ntp').set_trusted_key(value: val[0])
    @property_hash[:trusted_key] = val
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
