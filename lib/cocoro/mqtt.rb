# frozen_string_literal: true

require "cocoro"
require "logger"

require_relative "mqtt/version"

module Cocoro
  # A bridge between Cocoro Air API and MQTT
  class Mqtt
    DEFAULT_INTERVAL = 30 # seconds

    attr_accessor :logger

    def initialize(cocoro_client:, mqtt_client:, interval: DEFAULT_INTERVAL, logger: nil)
      @cocoro = cocoro_client
      @mqtt = mqtt_client
      @interval = interval
      @logger = logger || Logger.new($stdout).tap do |l|
        l.level = Logger::WARN
      end
      @mutex = Mutex.new
    end

    def start
      @mqtt.connect do |client|
        air_cleaners.each do |device|
          subscribe_to_device_command_topics(device, client)
          make_device_discoverable(device, client)
        end
        subscriber = Thread.new { keep_handling_commands(client) }
        publisher = Thread.new { keep_publishing_state_updates(client) }
        [subscriber, publisher].each(&:join)
      end
    end

    protected

    def air_cleaners
      @air_cleaners ||= @cocoro.devices.select { |d| d.type == "AIR_CLEANER" }
    end

    def keep_publishing_state_updates(client)
      loop do
        air_cleaners.each do |device|
          refresh_device_state(device, client)
        end
        sleep @interval
      end
    end

    def refresh_device_state(device, client)
      # Synchronizing to make sure we're not spamming the API by fetching
      # from 2 threads at once
      @mutex.synchronize do
        @logger.info { "Fetching #{device.name} status..." }
        status = device.fetch_status!
        @logger.info { status.to_h }
        publish_device_state(device, client, status)
      end
    rescue Cocoro::Error => e
      @logger.error { "Couldn't fetch #{device.name} status: #{e}" }
    end

    def keep_handling_commands(client)
      client.get do |topic, message|
        handle_command(client, topic, message)
      end
    end

    def handle_command(client, topic, message)
      _, id, target = topic.split("/")
      device = air_cleaners.find { |d| d.echonet_node == id }
      if device.nil?
        @logger.error { "Unknown device: #{id} (#{topic})" }
        return
      end

      @logger.info { "Executing '#{message}' command at '#{topic}'" }
      case target
      when "on"
        device.set_power_on!(message == "ON")
      when "humidifier"
        device.set_humidifier_on!(message == "ON")
      when "mode"
        device.set_air_volume!(message)
      else
        @logger.error { "Unknown command target: #{target} (#{topic})" }
        return
      end
      refresh_device_state(device, client)
    rescue Cocoro::Error => e
      @logger.error { "Couldn't handle '#{message}' at '#{topic}': #{e}" }
    end

    def publish_device_state(device, client, status)
      # TODO: availability
      id = device.echonet_node
      client.publish("cocoro/#{id}/on/state", status.power_on? ? "ON" : "OFF")
      client.publish("cocoro/#{id}/mode/state", status.air_volume)
      client.publish("cocoro/#{id}/humidifier/state", status.humidifier_on? ? "ON" : "OFF")
      client.publish("cocoro/#{id}/light/state", status.light_detected? ? "ON" : "OFF")
      client.publish("cocoro/#{id}/empty_water_tank/state", status.enough_water? ? "OFF" : "ON")
      client.publish("cocoro/#{id}/temperature/state", status.temperature)
      client.publish("cocoro/#{id}/humidity/state", status.humidity)
      client.publish("cocoro/#{id}/air_cleaned/state", status.total_air_cleaned)
      client.publish("cocoro/#{id}/pm25/state", status.pm25)
      client.publish("cocoro/#{id}/odor/state", status.odor)
      client.publish("cocoro/#{id}/dust/state", status.dust)
      client.publish("cocoro/#{id}/overall_dirtiness/state", status.overall_dirtiness)
    end

    def subscribe_to_device_command_topics(device, client)
      id = device.echonet_node
      topics = %W[
        cocoro/#{id}/on/set
        cocoro/#{id}/mode/set
        cocoro/#{id}/humidifier/set
      ]
      client.subscribe(*topics)
    end

    def make_device_discoverable(device, client)
      id = device.echonet_node
      device_description = {
        "manufacturer" => device.maker,
        "model" => device.model,
        "name" => device.name,
        "identifiers" => [id]
      }
      client.publish(
        "homeassistant/fan/airpurifier/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}",
          "name" => "#{device.name} Air Purifier",
          "unique_id" => "#{id}_airpurifier",
          "device" => device_description,
          "icon" => "mdi:air-purifier",
          "state_topic" => "~/on/state",
          "command_topic" => "~/on/set",
          "preset_mode_state_topic" => "~/mode/state",
          "preset_mode_command_topic" => "~/mode/set",
          "preset_modes" => %w[auto night pollen quiet medium strong omakase powerful]
        )
      )
      client.publish(
        "homeassistant/switch/humidifier/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/humidifier",
          "name" => "#{device.name} Humidifier",
          "unique_id" => "#{id}_humidifier",
          "device" => device_description,
          "state_topic" => "~/state",
          "command_topic" => "~/set",
          "icon" => "mdi:air-humidifier"
        )
      )
      client.publish(
        "homeassistant/binary_sensor/light/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/light",
          "name" => "#{device.name} Light",
          "unique_id" => "#{id}_light",
          "device" => device_description,
          "device_class" => "light",
          "state_topic" => "~/state"
        )
      )
      client.publish(
        "homeassistant/binary_sensor/empty_water_tank/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/empty_water_tank",
          "name" => "#{device.name} Empty Water Tank",
          "unique_id" => "#{id}_empty_water_tank",
          "device" => device_description,
          "device_class" => "problem",
          "state_topic" => "~/state",
          "icon" => "mdi:water"
        )
      )
      client.publish(
        "homeassistant/sensor/temperature/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/temperature",
          "name" => "#{device.name} Temperature",
          "unique_id" => "#{id}_temperature",
          "device" => device_description,
          "device_class" => "temperature",
          "state_topic" => "~/state",
          "unit_of_measurement" => "°C"
        )
      )
      client.publish(
        "homeassistant/sensor/humidity/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/humidity",
          "name" => "#{device.name} Humidity",
          "unique_id" => "#{id}_humidity",
          "device" => device_description,
          "device_class" => "humidity",
          "state_topic" => "~/state",
          "unit_of_measurement" => "%"
        )
      )
      client.publish(
        "homeassistant/sensor/air_cleaned/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/air_cleaned",
          "name" => "#{device.name} Total Air Cleaned",
          "unique_id" => "#{id}_air_cleaned",
          "device" => device_description,
          "device_class" => "gas",
          "state_topic" => "~/state",
          "unit_of_measurement" => "m³"
        )
      )
      client.publish(
        "homeassistant/sensor/pm25/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/pm25",
          "name" => "#{device.name} PM 2.5",
          "unique_id" => "#{id}_pm25",
          "device" => device_description,
          "device_class" => "pm25",
          "state_topic" => "~/state",
          "unit_of_measurement" => "µg/m³"
        )
      )
      client.publish(
        "homeassistant/sensor/odor/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/odor",
          "name" => "#{device.name} Odor",
          "unique_id" => "#{id}_odor",
          "device" => device_description,
          "state_topic" => "~/state",
          "icon" => "mdi:scent",
          "unit_of_measurement" => "%"
        )
      )
      client.publish(
        "homeassistant/sensor/dust/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/dust",
          "name" => "#{device.name} Dust",
          "unique_id" => "#{id}_dust",
          "device" => device_description,
          "state_topic" => "~/state",
          "icon" => "mdi:broom",
          "unit_of_measurement" => "%"
        )
      )
      client.publish(
        "homeassistant/sensor/overall_dirtiness/#{id}/config",
        JSON.dump(
          "~" => "cocoro/#{id}/overall_dirtiness",
          "name" => "#{device.name} Overall Air Dirtiness",
          "unique_id" => "#{id}_overall_dirtiness",
          "device" => device_description,
          "state_topic" => "~/state",
          "icon" => "mdi:delete",
          "unit_of_measurement" => "%"
        )
      )
    end
  end
end
