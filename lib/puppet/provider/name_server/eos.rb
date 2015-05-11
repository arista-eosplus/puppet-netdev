# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:name_server).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('dns').get
    result[:name_servers].map do |srv|
      provider_hash = { name: srv, ensure: :present }
      new(provider_hash)
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('dns').add_name_server(resource[:name])
    @property_hash = { name: resource[:name], ensure: :present }
  end

  def destroy
    node.api('dns').remove_name_server(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end

end
