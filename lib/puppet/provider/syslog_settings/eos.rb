require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:syslog_settings).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('logging').get
    provider_hash = { name: 'settings', ensure: :present }
    provider_hash[:enable] = result[:enable].to_s.to_sym
    provider_hash[:console] = result[:console]
    provider_hash[:monitor] = result[:monitor]
    provider_hash[:time_stamp_units] = result[:time_stamp_units]
    vrfs = []
    intfs = []
    result[:source].each do |vrf, intf|
      vrfs << vrf
      intfs << intf
    end
    provider_hash[:vrf] = vrfs
    provider_hash[:source_interface] = intfs
    [new(provider_hash)]
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
    @flush_source_interface = false
  end

  def enable=(value)
    val = value == :true
    node.api('logging').set_enable(value: val)
    @property_hash[:enable] = value
  end

  def console=(value)
    node.api('logging').set_console(level: value)
    @property_hash[:console] = value
  end

  def monitor=(value)
    node.api('logging').set_monitor(level: value)
    @property_hash[:monitor] = value
  end

  def time_stamp_units=(value)
    node.api('logging').set_time_stamp_units(units: value)
    @property_hash[:time_stamp_units] = value
  end

  def source_interface=(value)
    @flush_source_interface = true
    @property_flush[:source_interface] = value
  end

  def vrf=(value)
    @flush_source_interface = true
    @property_flush[:vrf] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    return unless @flush_source_interface == true
    api = node.api('logging')
    vrfs = @property_flush[:vrf] || @resource[:vrf]
    ints = @property_flush[:source_interface] || @resource[:source_interface]
    srcs = Hash[vrfs.zip(ints)]
    api.set_source_interface(srcs)
    # Update the state in the model to reflect the flushed changes
    @property_hash.merge!(@property_flush)
  end
end
