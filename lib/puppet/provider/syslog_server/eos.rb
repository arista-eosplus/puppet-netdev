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

  # Create getter methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def self.instances
    result = node.api('logging').get
    result[:hosts].each_with_object([]) do |(host, attr), arry|
      provider_hash = { name: host, ensure: :present }
      provider_hash[:port] = attr[:port] if attr[:port]
      provider_hash[:vrf] = attr[:vrf] if attr[:vrf]
      arry << new(provider_hash)
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def port=(value)
    @property_flush[:port] = value
  end

  def severity_level=(_value)
    not_supported 'severity_level'
  end

  def vrf=(value)
    @property_flush[:vrf] = value
  end

  def source_interface=(_value)
    not_supported 'source_interface'
  end

  def create
    @property_flush[:ensure] = :present
    @property_flush[:vrf] = @resource[:vrf]
    @property_flush[:port] = @resource[:port]
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def flush
    api = node.api('logging')
    opts = @property_hash.merge(@property_flush)
    if @property_flush[:ensure] == :absent
      api.remove_host(resource[:name], opts)
      @property_hash = { name: resource[:name], ensure: :absent }
      return
    end

    api.add_host(resource[:name], opts)

    @property_hash = { name: resource[:name], ensure: :present }
    @property_hash[:vrf] = opts[:vrf]
    @property_hash[:port] = opts[:port]
  end
end
