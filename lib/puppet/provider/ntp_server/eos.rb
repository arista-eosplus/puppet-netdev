# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:ntp_server).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('ntp').get
    result[:servers].map do |srv, attrs|
      provider_hash = { name: srv, ensure: :present }
      provider_hash[:prefer] = attrs[:prefer].to_s.to_sym
      new(provider_hash)
    end
  end

  def prefer=(value)
    val = value == :true
    node.api('ntp').set_prefer(resource[:name], value: val)
    @property_hash[:prefer] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
