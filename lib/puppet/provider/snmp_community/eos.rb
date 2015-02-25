# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:snmp_community).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('snmp').get
    result[:communities].map do |name, attrs|
      provider_hash = { name: name, ensure: :present }
      provider_hash[:group] = attrs[:access].to_sym
      provider_hash[:acl] = attrs[:acl]
      new(provider_hash)
    end
  end

  def group=(value)
    node.api('snmp').set_community_access(resource[:name], value.to_s)
    @property_hash[:group] = value
  end

  def acl=(value)
    node.api('snmp').set_community_acl(resource[:name], value: value)
    @property_hash[:acl] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('snmp').add_community(resource[:name])
    @property_hash = { name: resource[:name] , ensure: :present }
    self.group = resource[:group] if resource[:group]
    self.acl = resource[:acl] if resource[:acl]
  end

  def destroy
    node.api('snmp').remove_community(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end

end
