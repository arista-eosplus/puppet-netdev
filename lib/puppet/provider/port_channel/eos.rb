# encoding: utf-8

require 'puppet/type'
require 'puppet_x/net_dev/eos_api'
Puppet::Type.type(:port_channel).provide(:eos) do

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosProviderMethods
  # Mix in the api as class methods
  extend PuppetX::NetDev::EosProviderMethods
  # Mix in common provider class methods (e.g. self.prefetch)
  extend PuppetX::NetDev::EosProviderClassMethods

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def self.instances
    # For member interfaces, the least common value for duplex and flow control
    # are used as the value for the LAG.  The intent is to find outliers and
    # synchronize them.
    interfaces = api.all_interfaces
    api.all_portchannels.map do |name, attr_hash|
      # FIXME: Need to populate
      # flowcontrol_send (desired | off | on)
      # flowcontrol_receive (desired | off | on)
      channel_ports = attr_hash['ports']
      provider_hash = {
        name: name,
        id: name.scan(/\d+/).first.to_i,
        ensure: :present,
        interfaces: attr_hash['ports'],
        mode: attr_hash['mode'],
        minimum_links: attr_hash['minimum_links']
      }
      # Get the description of the portchannel interface
      provider_hash.merge! port_channel_attributes(interfaces[name])

      # Get the least common duplex value across all member interfaces
      duplex_count = channel_ports.each_with_object(Hash.new(0)) do |port, hsh|
        attributes = interface_attributes(interfaces[port])
        duplex = attributes[:duplex]
        hsh[duplex] += 1
      end
      duplex = duplex_count.sort_by { |_key, value| value }.first.first
      provider_hash[:duplex] = duplex

      # Get the least common speed value across all member interfaces
      speed_count = channel_ports.each_with_object(Hash.new(0)) do |port, hsh|
        attributes = interface_attributes(interfaces[port])
        speed = attributes[:speed]
        hsh[speed] += 1
      end
      speed  = speed_count.sort_by { |_key, value| value }.first.first
      provider_hash[:speed] = speed

      new(provider_hash)
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  ##
  # Note, on arista the `interface port-channel` command creates a port channel
  # without assigning Ethernet channels to the new interface.
  def create
    name = resource[:name]
    attributes = resource.to_hash
    attributes[:mode] = :disabled unless attributes[:mode]
    api.channel_group_create(name, attributes)
  end

  def destroy
    name = resource[:name]
    api.port_channel_destroy(name)
    @property_hash = { name: name, ensure: :absent }
  end

  def mode=(value)
    name = resource[:name]
    # LACP Mode cannot be changed without deleting the entire channel group
    api.channel_group_destroy(name)
    api.channel_group_create(name, mode: value, interfaces: interfaces)
    @property_hash[:mode] = value
  end

  ##
  # interfaces= manages the group of interfaces that are members of the
  # portchannel group.
  def interfaces=(value) # rubocop:disable Metrics/MethodLength
    desired_members   = [*value]
    current_members   = interfaces
    members_to_remove = current_members - desired_members
    members_to_add    = desired_members - current_members

    members_to_remove.each do |interface|
      api.interface_unset_channel_group(interface)
    end

    members_to_add.each do |interface|
      opts = { mode: mode, group: id }
      api.interface_set_channel_group(interface, opts)
    end

    @property_hash[:interfaces] = desired_members
  end

  def description=(value)
    api.set_interface_description(resource[:name], value)
    @property_hash[:description] = value
  end

  def speed=(value)
    @property_flush[:speed] = value
  end

  def duplex=(value)
    @property_flush[:duplex] = value
  end

  def flush
    interfaces.each { |name| flush_speed_and_duplex(name) }
    @property_hash.merge!(@property_flush)
  end
end
