# A sample Guardfile
# More info at https://github.com/guard/guard#readme

ignore(%r{^coverage\/})

group :specs, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec' do
    watch(%r{^spec\/.+_spec\.rb$})
    watch(%r{^lib\/(.+)\.rb$}) { |m| "spec/unit/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')  { 'spec' }
  end
end

group :style do
  guard :rubocop do
    watch(/.+\.rb$/)
    watch(%r{(?:.+\/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
  end
end

# Add files and commands to this file, like the example:
#   watch(%r{file/path}) { `command(s)` }
#
group :docs do
  guard :shell do
    watch(%r{^lib\/(.+)\.rb$}) { |m| `yard doc #{m[0]} --quiet` }
  end
end
