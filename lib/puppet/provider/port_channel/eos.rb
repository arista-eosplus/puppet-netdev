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

  def self.instances
    api.all_portchannels.map do |name, attr_hash|
      # FIXME: This list of parameters needs to be complete
      # Need to populate:
      # description (namevar, String)
      # speed (10 | 100 | 1000 | auto)
      # duplex (auto | full | half)
      # flowcontrol_send (desired | off | on)
      # flowcontrol_receive (desired | off | on)
      provider_hash = {
        name: name,
        id: name.scan(/\d+/).first.to_i,
        ensure: :present,
        interfaces: attr_hash['ports'],
        mode: attr_hash['mode']
      }

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
end
