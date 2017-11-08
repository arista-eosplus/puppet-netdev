require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:syslog_server).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  SERVER_PROPS = %i[
    port
    vrf
  ].freeze

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('logging').get
    # result[:hosts].each_with_object([]) do |host, arry|
    arry = []
    result[:hosts].each do |attrs|
      require 'pry'
      # binding.pry
      provider_hash = { name: namevar(attrs), ensure: :present }
      provider_hash.merge!(attrs)
      # binding.pry
      arry << new(provider_hash)
    end
    arry
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
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

  def severity_level=(_val)
    not_supported 'severity_level'
  end

  def vrf=(val)
    @flush_vrf = true
    @property_flush[:vrf] = val
  end

  def port=(val)
    @flush_port = true
    @property_flush[:port] = val
  end

  def source_interface=(_val)
    not_suppported 'source_interface'
  end

  def flush
    opts = {}
    SERVER_PROPS.each do |prop|
      next unless @resource[prop]
      opts[prop] = @resource[prop].to_s
      @property_hash[prop] = @resource[prop]
    end

    if @property_hash[:ensure] == :absent
      node.api('logging').remove_host(resource[:name].split(' ')[0], opts)
      @property_hash = { name: resource[:name], ensure: :absent }
    else
      output = node.api('logging').add_host(resource[:name].split(' ')[0], opts)
      raise Puppet::Error, "Unable to set #{resource}" unless output == true
      @property_hash[:name] = resource[:name]
      @property_hash[:ensure] = :present
    end
  end

  def self.namevar(opts)
    (address = opts[:address]) || raise(ArgumentError, 'address required')
    port = opts[:port] || 514
    vrf = opts[:vrf] || 'default'
    "#{address} #{port} #{vrf}"
  end
end
