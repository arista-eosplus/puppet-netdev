# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'
Puppet::Type.type(:network_interface).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosProviderMethods
  # Mix in the api as class methods
  extend PuppetX::NetDev::EosProviderMethods

  def self.instances
    interfaces = api.all_interfaces

    interfaces.each_with_object([]) do |(name, attr_hash), ary|
      next unless attr_hash['hardware'] == 'ethernet'
      provider_hash = { name: name }
      provider_hash.merge! interface_attributes(attr_hash)

      ary << new(provider_hash)
    end
  end

  def self.prefetch(resources)
    provider_hash = instances.each_with_object({}) do |provider, hsh|
      hsh[provider.name] = provider
    end

    resources.each_pair do |name, resource|
      resource.provider = provider_hash[name] if provider_hash[name]
    end
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def enable=(val)
    @property_flush[:enable] = val
  end

  def description=(val)
    @property_flush[:description] = val
  end

  def speed=(val)
    @property_flush[:speed] = val
  end

  def duplex=(val)
    @property_flush[:duplex] = val
  end

  def mtu=(val)
    @property_flush[:mtu] = val
  end

  ##
  # flush changes as one API call because speed and duplex settings are set via
  # one command.
  #
  #     configure interface ethernet 1
  #     speed forced 1000full
  def flush
    flush_enable_state
    flush_speed_and_duplex
    flush_mtu
    flush_description
    @property_hash = resource.to_hash
  end

  ##
  # flush_mtu manages the mtu setting and is meant to be called from the
  # provider's flush instance method.
  def flush_mtu
    mtu = @property_flush[:mtu]
    return nil unless mtu

    api.set_interface_mtu(resource[:name], mtu)
  end

  ##
  # flush_description configures the description of the target interface and is
  # meant to be called from the provider's flush instance method.
  #
  # @api private
  def flush_description
    description = @property_flush[:description]
    return nil unless description
    api.set_interface_description(resource[:name], description)
  end

  ##
  # flush_speed_and_duplex consolidates the duplex and speed settings into one
  # API call to manage the interface speed.
  def flush_speed_and_duplex
    speed = convert_speed(@property_flush[:speed])
    duplex = @property_flush[:duplex]
    return nil unless speed || duplex

    speed_out = speed ? speed : convert_speed(@property_hash[:speed])
    duplex_out = duplex ? duplex.downcase : @property_hash[:duplex].to_s

    api.set_interface_speed(resource[:name], "#{speed_out}#{duplex_out}")
  end

  ##
  # flush_enable_state configures the shutdown or no shutdown state of an
  # interface and is meant to be called from the provider's flush instance
  # method.
  def flush_enable_state
    value = @property_flush[:enable]
    return nil unless value

    arg = case value
          when :true then 'no shutdown'
          when :false then 'shutdown'
          else
            msg = "unknown enable value=#{value.inspect} expected true or false"
            fail Puppet::Error, msg
          end

    api.set_interface_state(resource[:name], arg)
  end

  ##
  # convert_speed takes a speed value from the catalog as a string and converts
  # it to a speed prefix suitable for the Arista API.  The following table is
  # used to perform the conversion.
  #
  #   10000full  Disable autoneg and force 10 Gbps/full duplex operation
  #   1000full   Disable autoneg and force 1 Gbps/full duplex operation
  #   1000half   Disable autoneg and force 1 Gbps/half duplex operation
  #   100full    Disable autoneg and force 100 Mbps/full duplex operation
  #   100gfull   Disable autoneg and force 100 Gbps/full duplex operation
  #   100half    Disable autoneg and force 100 Mbps/half duplex operation
  #   10full     Disable autoneg and force 10 Mbps/full duplex operation
  #   10half     Disable autoneg and force 10 Mbps/half duplex operation
  #   40gfull    Disable autoneg and force 40 Gbps/full duplex operation
  #
  # @param [String] speed The speed specified in the catalog, e.g. 1g
  #
  # @api private
  #
  # @return [String] The speed for the API, e.g. 1000
  def convert_speed(value)
    speed = value.to_s
    if /g$/i.match(speed) && (speed.to_i > 40)
      speed
    elsif /g$/i.match(speed)
      (speed.to_i * 1000).to_s
    elsif /m$/i.match(speed)
      speed.to_i.to_s
    end
  end
end
