require 'net/http'
require 'json'

module Bot
  GATEWAY_URL = "wss://gateway.discord.gg/?v=10&encoding=json"

  def self.log_error(msg)
    File.open("/var/www/discourse/log/discord_bot.log", "a") do |f|
      f.puts "[#{Time.now}] #{msg}"
    end
  end

  def self.run_bot
    log_error("Bot starting...")
    require 'websocket-client-simple'
    log_error("websocket-client-simple loaded")
    loop do
      begin
        connect
      rescue => ex
        log_error("Bot crashed: #{ex.message}\n#{ex.backtrace.join("\n")}")
        sleep 10
      end
    end
  end

  def self.connect
    log_error("Connecting to Discord gateway...")

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
        Bot.log_error("Message error: #{ex.message}")
      end
    end

    ws.on :close do |e|
      Bot.log_error("WS closed: #{e}")
    end

    ws.on :error do |e|
      Bot.log_error("WS error: #{e}")
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
      log_error("Heartbeat ACK")
    when 0
      handle_event(t, data)
    end
  end

  def self.identify(ws)
    log_error("Identifying with Discord...")
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
    log_error("Event: #{type}")
    case type
    when "GUILD_MEMBER_ADD", "GUILD_MEMBER_UPDATE"
      discord_id = data.dig("user", "id")
      Util.sync_from_discord(discord_id) if discord_id
    end
  end
end
