# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:search_domain).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('dns').get
    result[:domain_list].map do |domain|
      provider_hash = {name: domain, ensure: :present }
      new(provider_hash)
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('dns').add_domain_list(resource[:name])
    @property_hash = { name: resource[:name], ensure: :present }
  end

  def destroy
    node.api('dns').remove_domain_list(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end

end
