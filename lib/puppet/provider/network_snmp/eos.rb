# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'
Puppet::Type.type(:network_snmp).provide(:eos) do

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

  ##
  # Only one instance is ever returned, managing the overall SNMP state on the
  # device.
  def self.instances
    provider_hash = api.snmp_attributes
    [new(provider_hash)]
  end

  ##
  # enable SNMP by setting the "public" community string to "ro"
  def enable=(value)
    case value
    when :true
      api.snmp_enable = true
    when :false
      api.snmp_enable = false
    end
    @property_hash[:enable] = value
  end

  def contact=(value)
    api.snmp_contact = value
    @property_hash[:contact] = value
  end

  def location=(value)
    api.snmp_location = value
    @property_hash[:location] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
