# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'
Puppet::Type.type(:radius_server_group).provide(:eos) do
  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin
  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def self.instances
    api = eapi.Radius
    groups = api.server_groups
    groups.map do |api_attributes|
      servers = api_attributes[:servers].map {|hsh| server_name(hsh) }
      new(name: api_attributes[:name], ensure: :present, servers: servers)
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
  end

  def destroy
    @property_flush = resource.to_hash
  end

  def servers=(value)
    @property_flush[:servers] = value
  end

  def flush
    api = eapi.Radius
    desired_state = @property_hash.merge(@property_flush)
    radius_servers = desired_state[:servers].map { |s| parse_server_name(s) }
    case desired_state[:ensure]
    when :present
      api.update_server_group(name: name, servers: radius_servers)
    when :absent
      api.remove_server_group(name: name)
    end
    @property_hash = desired_state
  end

  # Construct a server name given a hostname, auth_port and acct_port
  def self.server_name(opts = {})
    "#{opts[:hostname]}/#{opts[:auth_port]}/#{opts[:acct_port]}"
  end

  def parse_server_name(name)
    (hostname, auth_port, acct_port) = name.split('/')
    hsh = { hostname: hostname }
    hsh[:auth_port] = auth_port if auth_port
    hsh[:acct_port] = acct_port if acct_port
    hsh
  end
  private :parse_server_name
end
