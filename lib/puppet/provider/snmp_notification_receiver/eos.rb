# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:snmp_notification_receiver).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def self.instances
    receivers = netdev('snmp').snmp_notification_receivers
    receivers.map do |rsrc_hash|
      new(rsrc_hash.merge(name: namevar(rsrc_hash)))
    end
  end

  def self.prefetch(resources)
    provider_hash = instances.each_with_object({}) do |provider, hsh|
      hsh[provider.name] = provider
    end

    resources.each_pair do |_, resource|
      name = namevar(resource.to_hash)
      resource.provider = provider_hash[name] if provider_hash[name]
    end
  end

  ##
  # namevar Returns a composite namevar given a resource hash.
  #
  # @api private
  #
  # @return [String] the composite namevar
  def self.namevar(opts)
    "#{opts[:name]}:#{opts[:username]}:#{opts[:port] || '162'}"
  end

  def create
    create_or_destroy
  end

  def destroy
    create_or_destroy
  end

  def create_or_destroy
    managed_properties = default_properties.merge(specified_properties)
    @property_flush = managed_properties
  end

  def flush
    new_property_hash = @property_hash.merge(@property_flush)
    new_property_hash[:name] = name.split(':').first
    case new_property_hash[:ensure]
    when :present
      netdev('snmp').snmp_notification_receiver_set(new_property_hash)
    when :absent
      netdev('snmp').snmp_notification_receiver_remove(new_property_hash)
    end
    @property_hash = new_property_hash
    @property_hash[:name] = self.class.namevar(new_property_hash)
  end

  ## default_properties returns a Hash of default property values.  The intent
  # is to have the managed property values merged on top of this default Hash.
  # The Hash is structured as a resource hash suitable for the flush method.
  #
  # @return [Hash<Symbol,Object>] Resource hash of defaults.
  def default_properties
    {
      port: 162,
      type: :traps,
      version: :v1
    }
  end
  private :default_properties

  ##
  # specified_properties returns a Hash of the resources specified in the
  # resource model.
  #
  # @api private
  #
  # @return [Hash<Symbol,Object>]
  def specified_properties
    resource.to_hash.reject do |key, val|
      [:provider, :loglevel].include?(key) || val.nil?
    end
  end
  private :specified_properties
end
