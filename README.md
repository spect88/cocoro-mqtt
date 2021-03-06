# Cocoro::Mqtt

This is a Ruby gem for exposing your Cocoro Air-compatible device via MQTT.
It supports Home Assistant's discovery and can be used either as a library or executable.

Be aware that this is totally unofficial, not affiliated with SHARP in any way.
The moment they change their APIs, this gem may stop working.

## Installation

To use it as a library, add this line to your application's Gemfile:

```ruby
gem 'cocoro-mqtt'
```

And then execute:

    $ bundle install

Or if you want to run it as a standalone app, install it yourself as:

    $ gem install cocoro-mqtt

## Usage

The tricky part is that you need to
[get the credentials first](https://github.com/spect88/cocoro#getting-the-api-credentials).


Running the gem standalone:
```sh
$ APP_SECRET=... TERMINAL_APP_ID_KEY=... MQTT_URL=... cocoro-mqtt
```

Using it from code:
```ruby
require "cocoro/mqtt"
require "mqtt"
require "logger"

app_secret = "..."
terminal_app_id_key = "..."
mqtt_url = "..."

cocoro = Cocoro::Client.new(app_secret: app_secret, terminal_app_id_key: terminal_app_id_key)
cocoro.login

mqtt = MQTT::Client.new(mqtt_url)

server = Cocoro::Mqtt.new(cocoro_client: cocoro, mqtt_client: mqtt)
server.logger.level = Logger::INFO
server.start
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/cocoro-mqtt.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
