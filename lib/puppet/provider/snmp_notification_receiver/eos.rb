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
    receivers.map { |resource_hash| new(resource_hash) }
  end
end
