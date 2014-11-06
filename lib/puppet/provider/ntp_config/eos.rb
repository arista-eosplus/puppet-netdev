# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'

Puppet::Type.type(:ntp_config).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin

  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def self.instances
    result = eapi.Ntp.get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:source_interface] = result['source_interface']
    [new(provider_hash)]
  end

  def source_interface=(val)
    eapi.Ntp.set_source_interface(value: val)
    @property_hash[:source_interface] = val
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
