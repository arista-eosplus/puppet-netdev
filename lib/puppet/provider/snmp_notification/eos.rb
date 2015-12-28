# encoding: utf-8

require 'puppet/type'

begin
  require "puppet_x/net_dev/eos_api"
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + "../../../" + "puppet_x/net_dev/eos_api"
end

Puppet::Type.type(:snmp_notification).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    result = node.api('snmp').get
    result[:notifications].map do |trap|
      provider_hash = { name: trap[:name], ensure: :present }
      provider_hash[:enable] = trap[:state] == 'on' ? :true : :false
      new(provider_hash)
    end
  end

  def enable=(value)
    val = value == :true ? 'on' : 'off'
    node.api('snmp').set_notification(name: resource[:name], state: val)
    @property_hash[:enable] = value
  end

end
