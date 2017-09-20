# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:syslog_server).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('logging').get
    require 'pry'
    #binding.pry
    result[:hosts].each_with_object([]) do |(host, attr), arry|
      provider_hash = { name: host, ensure: :present }
      arry << new(provider_hash)
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def severity_level=(_val)
    not_supported 'severity_level'
  end

  def vrf=(_val)
    not_support 'vrf'
  end

  def source_interface=(_val)
    not_suppported 'source_interface'
  end

  def create
    node.api('logging').add_host(resource[:name])
    @property_hash = { name: resource[:name], ensure: :present }
  end

  def destroy
    node.api('logging').remove_host(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end
end
