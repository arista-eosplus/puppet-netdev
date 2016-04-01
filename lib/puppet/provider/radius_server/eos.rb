# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:radius_server).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    api = node.api('radius').get
    api[:servers].map do |attrs|
      provider_hash = { name: namevar(attrs), ensure: :present }
      provider_hash.merge!(attrs)
      new(provider_hash)
    end
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_flush = resource.to_hash
  end

  def destroy
    @property_flush = resource.to_hash
  end

  def hostname=(value)
    @property_flush[:hostname] = value
  end

  def auth_port=(value)
    @property_flush[:auth_port] = value
  end

  def acct_port=(value)
    @property_flush[:acct_port] = value
  end

  def key=(value)
    @property_flush[:key] = value
  end

  def key_format=(value)
    @property_flush[:key_format] = value
  end

  def retransmit_count=(value)
    @property_flush[:retransmit_count] = value
  end

  def timeout=(value)
    @property_flush[:timeout] = value
  end

  def flush
    api = node.api('radius')
    desired_state = @property_hash.merge!(@property_flush)
    validate_identity(desired_state)
    case desired_state[:ensure]
    when :present
      api.update_server(desired_state)
    when :absent
      api.remove_server(desired_state)
    end
    @property_hash = desired_state
  end

  ##
  # validate_identity checks to make sure there are enough options specified to
  # uniquely identify a radius server resource.
  def validate_identity(opts = {})
    errors = false
    missing = [:hostname, :auth_port, :acct_port].reject { |k| opts[k] }
    errors = !missing.empty?
    msg = "Invalid options #{opts.inspect} missing: #{missing.join(', ')}"
    fail Puppet::Error, msg if errors
  end
  private :validate_identity

  def self.namevar(opts)
    hostname  = opts[:hostname] or fail ArgumentError, 'hostname required'
    auth_port = opts[:auth_port] || 1812
    acct_port = opts[:acct_port] || 1813
    "#{hostname}/#{auth_port}/#{acct_port}"
  end
end
