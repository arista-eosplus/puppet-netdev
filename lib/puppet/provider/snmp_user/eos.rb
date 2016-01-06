# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:snmp_user).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    users = netdev('snmp').snmp_users
    resource_hash_ary = users.map do |user_hsh|
      user_hsh.merge(
        ensure: :present,
        roles: [*user_hsh[:roles]],
        name: namevar(user_hsh)
      )
    end

    resource_hash_ary.map { |rsrc_hsh| new(rsrc_hsh) }
  end

  ##
  # namevar Returns a composite namevar given a resource hash.
  #
  # @api private
  #
  # @return [String] the composite namevar
  def self.namevar(opts)
    "#{opts[:name]}:#{opts[:version]}"
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

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_flush = resource.to_hash
    @property_flush[:ensure] = :present
  end

  def destroy
    # Obtain missing properties from the target system, not the resource model.
    @property_flush = {
      name: resource[:name],
      roles: roles,
      version: version,
      ensure: :absent
    }
  end

  def flush
    new_property_hash = @property_hash.merge(@property_flush)
    new_property_hash[:name] = name.split(':').first

    case new_property_hash[:ensure]
    when :absent, 'absent'
      update = netdev('snmp').snmp_user_destroy(new_property_hash)
    else
      update = netdev('snmp').snmp_user_set(new_property_hash)
    end

    @property_hash = new_property_hash.merge(update)
  end
end
