# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'
Puppet::Type.type(:snmp_community).provide(:eos) do

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

  def self.instances
    communities = api.snmp_communities
    communities.map { |resource_hash| new(resource_hash) }
  end

  def group=(value)
    fail NotImplementedError, 'not implemented'
    @property_hash[:group] = value
  end

  def acl=(value)
    fail NotImplementedError, 'not implemented'
    @property_hash[:acl] = value
  end
end
