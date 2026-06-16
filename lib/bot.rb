require 'discordrb'

module RoleSync
  extend Discordrb::EventContainer

  member_join do |event|
    Util.sync_from_discord(event.user.id)
  end

  member_update do |event|
    Util.sync_from_discord(event.user.id)
  end
end

module Instance
  @@bot = nil

  def self.init
    @@bot = Discordrb::Commands::CommandBot.new(
      token: SiteSetting.discord_sync_token,
      prefix: SiteSetting.discord_sync_prefix
    )
    @@bot
  end

  def self.bot
    @@bot
  end
end

class Bot
  def self.run_bot
    bot = Instance::init

    unless bot.nil?
      bot.include! RoleSync

      bot.ready do |event|
        puts "Logged in as #{bot.profile.username} (ID:#{bot.profile.id}) | #{bot.servers.size} servers"
        Instance::bot.send_message(
          SiteSetting.discord_sync_admin_channel_id,
          "Discord to Discourse role sync bot started!"
        )
      end

      bot.command(:ping) do |event|
        event.respond 'Pong!'
      end

      bot.command(:syncme) do |event|
        Util.sync_from_discord(event.user.id)
        event.respond "Syncing your roles now..."
      end

      bot.run
    end
  end
end
