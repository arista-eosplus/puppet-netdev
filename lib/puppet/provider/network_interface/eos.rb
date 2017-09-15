# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:network_interface).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    interfaces = node.api('interfaces').getall
    interfaces.each_with_object([]) do |(name, attrs), arry|
      next unless attrs[:type] == 'ethernet'
      provider_hash = { name: name, ensure: :present }
      provider_hash[:description] = attrs[:description]
      enable = !attrs[:shutdown]
      provider_hash[:enable] = enable.to_s.to_sym
      if attrs[:forced]
        speed, duplex = attrs[:speed].scan(/(\d+[gm]?)(full|half)/).first
        provider_hash[:duplex] = duplex.to_sym
        provider_hash[:speed] = self.convert_speed_to_type(speed)
      else
        provider_hash[:duplex] = :auto
        provider_hash[:speed] = :auto
      end
      arry << new(provider_hash)
    end
  end

  def initialize(resources)
    super(resources)
    @property_flush = {}
    @flush_speed = false
  end

  def enable=(val)
    value = val == :false
    node.api('interfaces').set_shutdown(resource[:name], value: value)
    @property_hash[:enable] = val
  end

  def description=(val)
    node.api('interfaces').set_description(resource[:name], value: val)
    @property_hash[:description] = val
  end

  def mtu=(_val)
    not_supported 'mtu'
  end

  def speed=(val)
    @flush_speed = true
    @property_flush[:speed] = val
  end

  def duplex=(val)
    @flush_speed = true
    @property_flush[:duplex] = val
  end

  def flush
    api = node.api('interfaces')
    speed = convert_speed_to_api(@property_flush)
    forced = speed != 'auto'
    api.set_speed(resource[:name], value: speed, forced: forced)
    # Update the state in the model to reflect the flushed changes
    @property_hash.merge!(@property_flush)
  end

  def convert_speed_to_api(opts = {})
    speed = opts[:speed] || :auto
    duplex = opts[:duplex] || :auto

    return 'auto' if speed == :auto || duplex == :auto

    case speed.to_s
    when '10m'
      duplex == :full ? '10full' : '10half'
    when '100m'
      duplex == :full ? '100full' : '100half'
    when '1g'
      duplex == :full ? '1000full' : '1000half'
    when '10g'
      '10gfull' if duplex == :full
    when '40g'
      '40gfull' if duplex == :full
    when '100g'
      '100gfull' if duplex == :full
    else
      fail ArgumentError, 'speed is not supported'
    end
  end

  def self.convert_speed_to_type(speed)
    case speed
    when '10' then '10m'
    when '100' then '100m'
    when '1000' then '1g'
    when '10000' then '10g'
    else speed
    end
  end
end
