# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'
Puppet::Type.type(:radius_global).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin
  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def self.instances
    api = eapi.Radius
    global_settings = api.getall
    global_settings.map { |rsrc_hash| new(rsrc_hash) }
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end
end
