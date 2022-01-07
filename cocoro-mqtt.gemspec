# frozen_string_literal: true

require_relative "lib/cocoro/mqtt/version"

Gem::Specification.new do |spec|
  spec.name          = "cocoro-mqtt"
  spec.version       = Cocoro::Mqtt::VERSION
  spec.authors       = ["Tomasz Szczęśniak-Szlagowski"]
  spec.email         = ["spect88@gmail.com"]

  spec.summary       = "Unofficial Cocoro Air API to MQTT bridge"
  spec.description   = "This is a bridge exposing your Cocoro Air compatible devices on MQTT. " \
                       "Not affiliated with SHARP in any way - use at your own risk"
  spec.homepage      = "https://github.com/spect88/cocoro-mqtt"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.5.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/spect88/cocoro-mqtt"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(
        %r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)}
      )
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.7"
  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
