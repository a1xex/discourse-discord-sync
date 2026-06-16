require 'net/http'
require 'json'

module Bot
  GATEWAY_URL = "wss://gateway.discord.gg/?v=10&encoding=json"

  def self.run_bot
    require 'websocket-client-simple' rescue nil

    loop do
      begin
        connect
      rescue => ex
        Rails.logger.error("Discord Bot crashed: #{ex.message}, restarting in 10s")
        sleep 10
      end
    end
  end

  def self.connect
    require 'websocket/client/simple'

    @heartbeat_interval = nil
    @heartbeat_thread   = nil
    @sequence           = nil
    @identified         = false

    ws = WebSocket::Client::Simple.connect(GATEWAY_URL)

    ws.on :message do |msg|
      begin
        payload = JSON.parse(msg.data)
        Bot.handle(payload, ws)
      rescue => ex
        Rails.logger.error("Discord WS message error: #{ex.message}")
      end
    end

    ws.on :close do |e|
      Rails.logger.warn("Discord WS closed: #{e}")
    end

    ws.on :error do |e|
      Rails.logger.error("Discord WS error: #{e}")
    end

    sleep
  end

  def self.handle(payload, ws)
    op   = payload["op"]
    data = payload["d"]
    t    = payload["t"]
    @sequence = payload["s"] if payload["s"]

    case op
    when 10
      @heartbeat_interval = data["heartbeat_interval"]
      start_heartbeat(ws)
      identify(ws) unless @identified

    when 11
      Rails.logger.debug("Discord heartbeat ACK")

    when 0
      handle_event(t, data)
    end
  end

  def self.identify(ws)
    ws.send({
      op: 2,
      d: {
        token: SiteSetting.discord_sync_token,
        intents: 269,
        properties: {
          os: "linux",
          browser: "discourse-discord-sync",
          device: "discourse-discord-sync"
        }
      }
    }.to_json)
    @identified = true
  end

  def self.start_heartbeat(ws)
    @heartbeat_thread&.kill
    @heartbeat_thread = Thread.new do
      loop do
        sleep(@heartbeat_interval / 1000.0)
        ws.send({ op: 1, d: @sequence }.to_json)
      end
    end
  end

  def self.handle_event(type, data)
    case type
    when "GUILD_MEMBER_ADD", "GUILD_MEMBER_UPDATE"
      discord_id = data.dig("user", "id")
      Util.sync_from_discord(discord_id) if discord_id
    end
  end
end
