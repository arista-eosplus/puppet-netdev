# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:network_dns).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('dns').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:domain] = result[:domain_name]
    provider_hash[:search] = result[:domain_list]
    provider_hash[:servers] = result[:name_servers]
    [new(provider_hash)]
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('dns').create(resource[:id])
    @property_hash = { name: name, ensure: :present }
    self.domain = resource[:domain] if resource[:domain]
    self.search = resource[:search] if resource[:search]
    self.servers = resource[:servers] if resource[:servers]
  end

  def destroy
    node.api('dns').delete(resource[:id])
    @property_hash = { id: id, ensure: :absent }
  end

  def domain=(value)
    node.api('dns').set_domain_name(value: value)
    @property_hash[:domain] = value
  end

  def search=(value)
    node.api('dns').set_domain_list(value: value)
    @property_hash[:search] = value
  end

  def servers=(value)
    node.api('dns').set_name_servers(value: value)
    @property_hash[:servers] = value
  end
end
