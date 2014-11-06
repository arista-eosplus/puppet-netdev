
# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'
Puppet::Type.type(:tacacs_server).provide(:eos) do
  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin
  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def self.instances
    api = eapi.Tacacs
    servers = api.servers
    servers.map do |api_attributes|
      puppet_attributes = { name: namevar(api_attributes), ensure: :present, }
      new(api_attributes.merge(puppet_attributes))
    end
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def self.namevar(opts)
    hostname  = opts[:hostname] or fail ArgumentError, 'hostname required'
    port = opts[:port] || 49
    "#{hostname}/#{port}"
  end
end
