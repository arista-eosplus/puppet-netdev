# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:tacacs).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('tacacs').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:enable] = :true
    [new(provider_hash)]
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def enable=(value)
    val = value == :true
    unless val
      not_supported 'tacacs disable'
    end
    @property_hash[:enable] = :true
  end
end
