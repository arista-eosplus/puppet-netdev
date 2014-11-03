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
    @property_flush = resource.to_hash.select do |key, _|
      [:name, :group, :acl].include? key
    end
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush = { name: name, ensure: :absent }
  end

  def group=(value)
    @property_flush[:group] = value
  end

  def acl=(value)
    @property_flush[:acl] = value
  end

  def flush
    new_property_hash = @property_hash.merge(@property_flush)
    new_property_hash[:name] = name

    case new_property_hash[:ensure]
    when :absent, 'absent'
      api.snmp_community_destroy(name: name)
    else
      api.snmp_community_set(new_property_hash)
    end

    @property_hash = new_property_hash
  end
end
