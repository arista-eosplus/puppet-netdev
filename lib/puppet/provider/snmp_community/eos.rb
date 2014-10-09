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

  def self.instances
    communities = api.snmp_communities
    communities.each { |hsh| hsh[:ensure] = :present }
    communities.map { |resource_hash| new(resource_hash) }
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    allowed_keys = [:name, :group, :acl]
    property_hash = resource.to_hash.select do |key, _|
      allowed_keys.include? key
    end
    api.snmp_community_create(property_hash)
    @property_hash = property_hash
    @property_hash[:ensure] = :present
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
