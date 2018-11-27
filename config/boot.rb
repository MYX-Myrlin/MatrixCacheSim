ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

# Set the ExecJS runtime to use NodeJS to avoid an "Undefined not callable" bug
# that occurs when using Bootstrap & Duktape
ENV['EXECJS_RUNTIME'] = 'Node'
