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

  PRIV_MODE = { :aes => :aes128, :des => :des }.freeze

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('snmp').get
    require 'pry'
    #binding.pry
    result[:users].map do |user|
      # TODO
      provider_hash = { name: namevar(user), ensure: :present }
      provider_hash[:roles] = [user[:group]]
      provider_hash[:version] = user[:version]

      provider_hash[:engine_id] = user[:engine_id]

      provider_hash[:auth] = user[:auth_mode] if user[:auth_mode]
      # Type indicates Cleartext password. We only have encrypted
      provider_hash[:password] = user[:auth_pass] if user[:auth_pass]

      provider_hash[:privacy] = PRIV_MODE[user[:priv_mode]] if user[:priv_mode]
      provider_hash[:private_key] = user[:priv_pass] if user[:priv_pass]
      new(provider_hash)
    end
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
    @property_flush[:ensure] = :absent
  end

  def flush
    new_property_hash = @property_hash.merge(@property_flush)
    new_property_hash[:name] = name.split(':').first

    fail('Failed to configure user') unless
    node.api('snmp').set_user(new_property_hash)
  end
end
