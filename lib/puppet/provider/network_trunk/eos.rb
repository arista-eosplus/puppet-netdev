#
# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:network_trunk).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    switchports = node.api('switchports').getall
    switchports.map do |(name, attrs)|
      provider_hash = { name: name, ensure: :present }
      provider_hash.merge!(attrs)
      provider_hash[:mode] = attrs[:mode].to_sym
      provider_hash[:tagged_vlans] = attrs[:trunk_allowed_vlans]
      provider_hash[:untagged_vlan] = attrs[:access_vlan]
      new(provider_hash)
    end
  end

  def mode=(val)
    node.api('switchports').set_mode(resource[:name], value: val)
    @property_hash[:mode] = val
  end

  def tagged_vlans=(val)
    node.api('switchports').set_trunk_allowed_vlans(resource[:name], value: val)
    @property_hash[:tagged_vlans] = val
  end

  def untagged_vlan=(val)
    node.api('switchports').set_access_vlan(resource[:name], value: val)
    @property_hash[:untagged_vlan] = val
  end

  def encapsulation=(val)
    not_supported 'encapsulation'
  end

  def pruned_vlans=(val)
    not_supported 'pruned_vlans'
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('switchports').create(resource[:name])
    @property_hash = { name: resource[:name], ensure: :present }
    self.mode = resource[:mode] if resource[:mode]
    self.tagged_vlans = resource[:tagged_vlans] if resource[:tagged_vlans]
    self.untagged_vlan = resource[:untagged_vlan] if resource[:untagged_vlan]
  end

  def destroy
    node.api('switchports').delete(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end

end
