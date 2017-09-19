# encoding: utf-8

require 'puppet/type'

begin
  require 'puppet_x/net_dev/eos_api'
rescue LoadError => detail
  require 'pathname' # JJM WORK_AROUND #14073
  module_base = Pathname.new(__FILE__).dirname
  require module_base + '../../../' + 'puppet_x/net_dev/eos_api'
end

Puppet::Type.type(:tacacs_server_group).provide(:eos) do
  confine operatingsystem: [:AristaEOS] unless ENV['RBEAPI_CONNECTION']
  confine feature: :rbeapi

  DEFAULT_TACACS_PORT = '49'.freeze

  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::NetDev::EosApi

  # Mix in the api as class methods
  extend PuppetX::NetDev::EosApi

  def self.instances
    aaa = node.api('aaa').get
    aaa[:groups].each_with_object([]) do |(name, attrs), arry|
      next unless attrs[:type] == 'tacacs+'
      provider_hash = { name: name, ensure: :present }
      provider_hash[:servers] = attrs[:servers].map { |srv| server_name(srv) }
      Puppet.debug("provider: #{provider_hash}")
      arry << new(provider_hash)
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def servers=(value)
    servers = value.map { |srv| parse_server_name(srv) }
    node.api('aaa').groups.set_servers(resource[:name], servers)
    @property_hash[:servers] = value
  end

  def create
    rc = node.api('aaa').groups.create(resource[:name], 'tacacs+')
    raise Puppet::Error, "unable to create server group #{name}" unless rc
    @property_hash = { name: resource[:name], ensure: :present }
    self.servers = resource[:servers] if resource[:servers]
  end

  def destroy
    node.api('aaa').groups.delete(resource[:name])
    @property_hash = { name: resource[:name], ensure: :absent }
  end

  # Construct a server name given a name, vrf, and port
  def self.server_name(opts = {})
    vrf = opts[:vrf] || ''
    port = opts[:port]
    "#{opts[:name]}/#{vrf}/#{port}"
  end

  def parse_server_name(name)
    (name, vrf, port) = name.split('/')
    hsh = { name: name }
    hsh[:vrf] = vrf if vrf
    hsh[:port] = port || DEFAULT_TACACS_PORT
    hsh
  end
  private :parse_server_name
end
