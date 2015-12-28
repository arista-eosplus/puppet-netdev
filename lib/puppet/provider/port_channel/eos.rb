# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:port_channel).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('interfaces').getall
    result.each_with_object([]) do |(name, attrs), arry|
      next unless attrs[:type] == 'portchannel'
      provider_hash = { name: name, ensure: :present }
      provider_hash[:id] = name.scan(/\d+/)
      provider_hash[:minimum_links] = attrs[:minimum_links]
      attrs[:lacp_mode].gsub!('on', 'disabled')
      provider_hash[:mode] = attrs[:lacp_mode].to_sym
      provider_hash[:interfaces] = attrs[:members]
      provider_hash[:description] = attrs[:description]
      arry << new(provider_hash)
    end
  end

  def mode=(value)
    val = value == :disabled ? 'on' : value.to_s
    node.api('interfaces').set_lacp_mode(resource[:name], val)
    @property_hash[:mode] = value
  end

  def interfaces=(val)
    node.api('interfaces').set_members(resource[:name], val)
    @property_hash[:interfaces] = val
  end

  def minimum_links=(val)
    node.api('interfaces').set_minimum_links(resource[:name], value: val)
    @property_hash[:minimum_links] = val
  end

  def description=(val)
    node.api('interfaces').set_description(resource[:name], value: val)
    @property_hash[:description] = val
  end

  def id=(val)
    not_supported 'id'
  end

  def force=(val)
    not_supported 'force'
  end

  def speed=(val)
    not_supported 'speed'
  end

  def duplex=(val)
    not_supported 'duplex'
  end

  def flowcontrol_send=(val)
    not_supported 'flowcontrol_send'
  end

  def flowcontrol_receive=(val)
    not_supported 'flowcontrol_receive'
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    node.api('interfaces').create(resource[:name])
    @property_hash = { name: resource[:name], ensure: :present }
    self.mode = resource[:mode] if resource[:mode]
    self.interfaces = resource[:interfaces] if resource[:interfaces]
    self.minimum_links = resource[:minimum_links] if resource[:minimum_links]
    self.description = resource[:description] if resource[:description]
  end

  def destroy
    node.api('interfaces').delete(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end
end
