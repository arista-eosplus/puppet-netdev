# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'

Puppet::Type.type(:radius).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin

  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def self.instances
    result = node.api('radius').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:enable] = true
    [new(provider_hash)]
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def enable=(value)
    val = value == :true
    node.api('radius').set_enable(value: val)
    @property_hash[:enable] = value
  end

end
