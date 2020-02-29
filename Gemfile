source ENV['GEM_SOURCE'] || 'https://rubygems.org'

def location_for(place, fake_version = nil)
  mdata = /^(git[:@][^#]*)#(.*)/.match(place)
  if mdata
    hsh = { git: mdata[1], branch: mdata[2], require: false }
    return [fake_version, hsh].compact
  end
  mdata2 = %r{^file:\/\/(.*)}.match(place)
  if mdata2
    return ['>= 0', { path: File.expand_path(mdata2[1]), require: false }]
  end
  [place, { require: false }]
end

group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'guard-shell'
end

group :development, :test do
  gem 'metadata-json-lint'
  gem 'pry', require: false
  gem 'pry-doc', require: false
  gem 'pry-stack_explorer', require: false
  gem 'puppet-lint'
  gem 'puppetlabs_spec_helper'
  gem 'rake', '~> 12.3.3', require: false
  gem 'rb-readline'
  gem 'redcarpet'
  gem 'rspec', '~> 3.0.0'
  gem 'rspec-mocks', '~> 3.0.0'
  gem 'semantic_puppet'
  gem 'simplecov', require: false
  gem 'yard'
end

ENV['GEM_PUPPET_VERSION'] ||= ENV['PUPPET_GEM_VERSION']
puppetversion = ENV['GEM_PUPPET_VERSION']
if puppetversion
  gem 'puppet', *location_for(puppetversion)
else
  # Rubocop thinks these are duplicates.
  # rubocop:disable Bundler/DuplicatedGem
  gem 'puppet', require: false
  # rubocop:enable Bundler/DuplicatedGem
end

netdev_stdlib_version = ENV['GEM_NETDEV_STDLIB_VERSION']
if netdev_stdlib_version
  gem 'puppetmodule-netdev_stdlib', *location_for(netdev_stdlib_version)
else
  # Rubocop thinks these are duplicates.
  # rubocop:disable Bundler/DuplicatedGem
  gem 'puppetmodule-netdev_stdlib', '~> 0.10.0'
  # rubocop:enable Bundler/DuplicatedGem
end

rbeapiversion = ENV['GEM_RBEAPI_VERSION']
if rbeapiversion
  gem 'rbeapi', *location_for(rbeapiversion)
else
  # Rubocop thinks these are duplicates.
  # rubocop:disable Bundler/DuplicatedGem
  gem 'rbeapi', require: false
  # rubocop:enable Bundler/DuplicatedGem
end
# vim:ft=ruby
