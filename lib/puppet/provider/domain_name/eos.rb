# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:domain_name).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('dns').get
    provider_hash = { name: result[:domain_name], ensure: :present }
    [new(provider_hash)]
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('dns').set_domain_name(value: resource[:name])
    @property_hash = { name: resource[:name] , ensure: :present }
  end

  def destroy
    node.api('dns').set_domain_name
    @property_hash = { name: resource[:name], ensure: :absent }
  end
end
