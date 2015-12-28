# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:tacacs_global).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    resource = node.api('tacacs').get
    provider_hash = { name: 'settings' }
    provider_hash.merge!(resource[:global])
    [new(provider_hash)]
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
    @flush_key = false
    @flush_timeout = false
  end

  def enable=(value)
    not_supported 'enable'
  end

  def key=(value)
    @flush_key = true
    @property_flush[:key] = value
  end

  def key_format=(value)
    @flush_key = true
    @property_flush[:key_format] = value
  end

  def timeout=(value)
    @flush_timeout = true
    @property_flush[:timeout] = value
  end

  def retransmit_count=(value)
    not_supported 'retransmit_count'
  end

  def flush
    api = node.api('tacacs')
    opts = @property_hash.merge(@property_flush)
    api.set_global_key(value: opts[:key], key_format: opts[:key_format]) if @flush_key
    api.set_global_timeout(value: opts[:timeout]) if @flush_timeout
    # Update the state in the model to reflect the flushed changes
    @property_hash.merge!(@property_flush)
  end
end
