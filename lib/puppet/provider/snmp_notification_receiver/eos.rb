# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'
Puppet::Type.type(:snmp_notification_receiver).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosProviderMethods
  # Mix in the api as class methods
  extend PuppetX::NetDev::EosProviderMethods
  # Mix in common provider class methods (e.g. self.prefetch)
  extend PuppetX::NetDev::EosProviderClassMethods

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def self.instances
    receivers = api.snmp_notification_receivers
    receivers.map do |rsrc_hash|
      new(rsrc_hash.merge(name: namevar(rsrc_hash)))
    end
  end

  def self.prefetch(resources)
    provider_hash = instances.each_with_object({}) do |provider, hsh|
      hsh[provider.name] = provider
    end

    resources.each_pair do |_, resource|
      name = namevar(resource.to_hash)
      resource.provider = provider_hash[name] if provider_hash[name]
    end
  end

  ##
  # namevar Returns a composite namevar given a resource hash.
  #
  # @api private
  #
  # @return [String] the composite namevar
  def self.namevar(opts)
    values = [opts[:name]]
    values << (opts[:username] || opts[:community])
    values += [:port, :version, :type].map { |k| opts[k] }
    # security is optional
    values << opts[:security] if opts[:security]
    values.join(':')
  end
end
