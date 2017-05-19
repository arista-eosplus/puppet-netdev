# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:ntp_auth_key).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  NTP_AUTH_KEY_PROPS = [
    :algorithm,
    :mode,
    :password
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
    result[:auth_keys].map do |key, attrs|
      provider_hash = { name: key.to_s, ensure: :present }
      provider_hash[:algorithm] = attrs[:algorithm]
      provider_hash[:mode] = attrs[:mode]
      provider_hash[:password] = attrs[:password]
      new(provider_hash)
    end
  end

  def create
    @property_flush[:ensure] = :present
  end

  def destroy
    @property_flush[:ensure] = :absent
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    opts = { key: resource[:name] }
    opts[:enable] = false if @property_flush[:ensure] == :absent
    NTP_AUTH_KEY_PROPS.each do |prop|
      next unless @resource[prop]
      opts[prop] = @resource[prop].to_s
      @property_hash[prop] = @resource[prop]
    end

    output = node.api('ntp').set_authentication_key(opts)
    if output == true
      @property_hash[:name] = resource[:name]
      @property_hash[:ensure] = @property_flush[:ensure]
    else
      raise Puppet::Error, "Unable to set #{resource}"
    end
  end
end
