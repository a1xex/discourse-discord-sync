require 'net/http'
require 'json'

module Util
  def self.role_group_map
    map = {}
    SiteSetting.discord_sync_role_group_map.to_s.split("|").each do |pair|
      parts = pair.split(":", 2)
      map[parts[0].strip] = parts[1].strip if parts.size == 2
    end
    map
  end

  def self.discord_request(method, path, body = nil)
    uri = URI("https://discord.com/api/v10#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = case method
    when :get    then Net::HTTP::Get.new(uri)
    when :put    then Net::HTTP::Put.new(uri)
    when :delete then Net::HTTP::Delete.new(uri)
    end

    request["Authorization"] = "Bot #{SiteSetting.discord_sync_token}"
    request["Content-Type"]  = "application/json"
    request.body = body.to_json if body

    http.request(request)
  end

  def self.log(msg)
    discord_request(:post, "/channels/#{SiteSetting.discord_sync_admin_channel_id}/messages", { content: msg })
  rescue => ex
    Rails.logger.error("Discord log error: #{ex.message}")
  end

  def self.get_member_roles(guild_id, discord_id)
    response = discord_request(:get, "/guilds/#{guild_id}/members/#{discord_id}")
    return [] unless response.code.to_i == 200
    data = JSON.parse(response.body)
    data["roles"] || []
  rescue => ex
    Rails.logger.error("Discord get member roles error: #{ex.message}")
    []
  end

  def self.get_guilds
    response = discord_request(:get, "/users/@me/guilds")
    return [] unless response.code.to_i == 200
    JSON.parse(response.body)
  rescue => ex
    Rails.logger.error("Discord get guilds error: #{ex.message}")
    []
  end

  def self.sync_from_discord(discord_id)
    builder = DB.build("select u.* from user_associated_accounts uaa, users u /*where*/ limit 1")
    builder.where("provider_name = :provider_name", provider_name: "discord")
    builder.where("uaa.user_id = u.id")
    builder.where("uaa.provider_uid = :discord_id", discord_id: discord_id.to_s)

    result = builder.query

    if result.size == 0
      log("Discord user #{discord_id} has no linked Discourse account, skipping.")
    else
      result.each { |t| sync_user(t) }
    end
  end

  def self.sync_user(user)
    discord_id = nil

    builder = DB.build("select uaa.provider_uid from user_associated_accounts uaa /*where*/ limit 1")
    builder.where("provider_name = :provider_name", provider_name: "discord")
    builder.where("uaa.user_id = :user_id", user_id: user.id)
    builder.query.each { |t| discord_id = t.provider_uid }

    return if discord_id.nil?

    mapping = role_group_map
    return if mapping.empty?

    guilds = get_guilds
    return if guilds.empty?

    guilds.each do |guild|
      guild_id = guild["id"]
      member_role_ids = get_member_roles(guild_id, discord_id)
      next if member_role_ids.empty?

      mapping.each do |role_id, group_name|
        group = Group.find_by(name: group_name)
        next if group.nil?

        discourse_user = User.find_by(id: user.id)
        next if discourse_user.nil?

        has_role = member_role_ids.include?(role_id)
        in_group = GroupUser.exists?(group_id: group.id, user_id: discourse_user.id)

        if has_role && !in_group
          group.add(discourse_user)
          log("Added @#{discourse_user.username} to #{group_name} via role #{role_id}")
        elsif !has_role && in_group
          group.remove(discourse_user)
          log("Removed @#{discourse_user.username} from #{group_name} via role #{role_id}")
        end
      end
    end
  rescue => ex
    Rails.logger.error("Discord sync_user error: #{ex.message}")
  end
end
