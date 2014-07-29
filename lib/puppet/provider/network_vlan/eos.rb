# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'
Puppet::Type.type(:network_vlan).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosProviderMethods
  # Mix in the api as class methods
  extend PuppetX::NetDev::EosProviderMethods

  def self.instances
    vlans = api.all_vlans

    vlans.map do |id_s, attr_hash|
      id = Integer(id_s)
      name = attr_hash['name']
      provider_hash = { name: id_s, vlan_name: name, id: id, ensure: :present }

      is_active = attr_hash['status'] == 'active'
      provider_hash[:shutdown] = is_active ? :false : :true

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

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    id = resource[:id]
    api.vlan_create(id)
    @property_hash = { id: id, ensure: :present }
    # Sync the catalog with the system
    self.shutdown  = resource[:shutdown]  if resource[:shutdown]
    self.vlan_name = resource[:vlan_name] if resource[:vlan_name]
  end

  def destroy
    id = resource[:id]
    api.vlan_destroy(id)
    @property_hash = { id: id, ensure: :absent }
  end

  def vlan_name=(value)
    api.set_vlan_name(resource[:id], value)
    @property_hash[:vlan_name] = value
  end

  def shutdown=(value)
    case value
    when :true
      state = 'suspend'
    when :false
      state = 'active'
    end
    api.set_vlan_state(resource[:id], state)
    @property_hash[:shutdown] = value
  end
end
