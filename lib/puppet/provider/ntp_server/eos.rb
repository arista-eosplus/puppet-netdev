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

  NTP_SERVER_PROPS = [
    :key,
    :prefer,
    :maxpoll,
    :minpoll,
    :source_interface,
    :vrf
  ]

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def self.instances
    result = node.api('ntp').get
    result[:servers].map do |srv, attrs|
      provider_hash = { name: srv, ensure: :present }
      provider_hash[:key] = attrs[:key]
      provider_hash[:maxpoll] = attrs[:maxpoll]
      provider_hash[:minpoll] = attrs[:minpoll]
      provider_hash[:prefer] = attrs[:prefer].to_s.to_sym
      provider_hash[:source_interface] = attrs[:source_interface]
      provider_hash[:vrf] = attrs[:vrf]
      new(provider_hash)
    end
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_hash = { name: resource[:name], ensure: :absent }
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if @property_hash[:ensure] == :absent
      node.api('ntp').remove_server(resource[:name], resource[:vrf])
    else
      opts = {}
      NTP_SERVER_PROPS.each do |prop|
        next unless @resource[prop]
        opts[prop] = @resource[prop].to_s
        @property_hash[prop] = @resource[prop]
      end

      output = node.api('ntp').add_server(resource[:name], false, opts)
      if output == true
        @property_hash[:name] = resource[:name]
        @property_hash[:ensure] = :present
      else
        raise Puppet::Error, "Unable to set #{resource}"
      end
    end
  end
end
