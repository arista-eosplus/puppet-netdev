# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'

Puppet::Type.type(:radius_global).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('radius').get
    provider_hash = { name: 'settings' }
    provider_hash.merge!(result[:global])
    provider_hash[:retransmit_count] = result[:global][:retransmit]
    [new(provider_hash)]
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
    @flush_key = false
    @flush_timeout = false
    @flush_retransmit = false
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
    @flush_retransmit = true
    @property_flush[:retransmit_count] = value
  end

  def flush
    api = node.api('radius')
    opts = @property_hash.merge(@property_flush)
    api.set_global_key(value: opts[:key], key_format: opts[:key_format]) if @flush_key
    api.set_global_timeout(value: opts[:timeout]) if @flush_timeout
    api.set_global_retransmit(value: opts[:retransmit_count]) if @flush_retransmit
    # Update the state in the model to reflect the flushed changes
    @property_hash.merge!(@property_flush)
  end
end
