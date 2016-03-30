# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:ntp_server).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

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

  def create
    prefer = resource[:prefer] == :true
    node.api('ntp').add_server(resource[:name], prefer)
    @property_hash = { name: resource[:name], ensure: :present }
  end

  def destroy
    node.api('ntp').remove_server(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end

  def prefer=(value)
    val = value == :true
    node.api('ntp').set_prefer(resource[:name], val)
    @property_hash[:prefer] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end
end
