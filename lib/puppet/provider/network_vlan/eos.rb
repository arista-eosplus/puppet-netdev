# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:network_vlan).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('vlans').getall
    result.each_with_object([]) do |(vid, attrs), arry|
      id = Integer(vid)
      provider_hash = { name: vid, id: id, ensure: :present }
      provider_hash[:vlan_name] = attrs[:name]
      provider_hash[:shutdown] = (attrs[:state] == 'suspend').to_s.to_sym
      arry << new(provider_hash)
    end
  end

  def vlan_name=(value)
    node.api('vlans').set_name(resource[:id], value: value)
    @property_hash[:vlan_name] = value
  end

  def shutdown=(value)
    state = value == :true ? 'suspend' : 'active'
    node.api('vlans').set_state(resource[:id], value: state)
    @property_hash[:shutdown] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('vlans').create(resource[:id])
    @property_hash = { id: id, ensure: :present }
    self.shutdown  = resource[:shutdown]  if resource[:shutdown]
    self.vlan_name = resource[:vlan_name] if resource[:vlan_name]
  end

  def destroy
    node.api('vlans').delete(resource[:id])
    @property_hash = { id: id, ensure: :absent }
  end

end
