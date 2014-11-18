# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'
Puppet::Type.type(:tacacs_global).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin
  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def self.instances
    api = eapi.Tacacs
    global_settings = api.getall
    global_settings.map { |rsrc_hash| new(rsrc_hash) }
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
    @flush_key = false
    @flush_timeout = false
  end

  def enable=(value)
    fail ArgumentError, 'Tacacs cannot be disabled on EOS' unless value
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
    fail NotImplementedError,
      'Tacacs retransmit count cannot be configured on EOS'
  end

  def flush
    api = eapi.Tacacs
    opts = @property_hash.merge(@property_flush)
    api.set_global_key(opts) if @flush_key
    api.set_timeout(opts) if @flush_timeout
    # Update the state in the model to reflect the flushed changes
    @property_hash.merge!(@property_flush)
  end
end
