gem 'discordrb', '3.4.2'

enabled_site_setting :discord_sync_enabled

after_initialize do
  require_relative '../plugins/discourse-discord-sync/lib/bot'
  require_relative '../plugins/discourse-discord-sync/lib/utils'

  bot_thread = Thread.new do
    begin
      Bot.run_bot
    rescue => ex
      Rails.logger.error("Discord Bot error: #{ex.message}")
      Rails.logger.error(ex.backtrace.join("\n"))
    end
  end

  bot_thread.abort_on_exception = false

  on(:user_saved) do |user|
    Util.sync_user(user) if user.id > 0
  end

  on(:user_added_to_group) do |user, group, automatic|
    Util.sync_user(user) if user.id > 0
  end

  on(:user_removed_from_group) do |user, group|
    Util.sync_user(user) if user.id > 0
  end

  on(:after_auth) do |authenticator, auth_result|
    if authenticator.name == "discord" && auth_result.user&.id.to_i > 0
      Util.sync_user(auth_result.user)
    end
  end
end
