# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:l2_interface).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosProviderMethods
  # Mix in the api as class methods
  extend PuppetX::NetDev::EosProviderMethods

  def self.instances
    interfaces = api.all_virtual_interfaces

    interfaces.map do |name, attr_hash|
      provider_hash = { name: name }
      provider_hash.merge! trunk_attributes(attr_hash)

      new(provider_hash)
    end
  end

  def self.prefetch(resources)
    provider_hash = instances.each_with_object({}) do |provider, hsh|
      hsh[provider.name] = provider
    end

    resources.each_pair do |name, resource|
      resource.provider = provider_hash[name] if provider_hash[name]
    end
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end
end
