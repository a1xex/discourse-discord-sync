class Util

  def self.role_group_map
    map = {}
    SiteSetting.discord_sync_role_group_map.split("|").each do |pair|
      parts = pair.split(":", 2)
      map[parts[0].strip] = parts[1].strip if parts.size == 2
    end
    map
  end

  def self.sync_from_discord(discord_id)
    builder = DB.build("select u.* from user_associated_accounts uaa, users u /*where*/ limit 1")
    builder.where("provider_name = :provider_name", provider_name: "discord")
    builder.where("uaa.user_id = u.id")
    builder.where("uaa.provider_uid = :discord_id", discord_id: discord_id.to_s)

    result = builder.query

    if result.size == 0
      Instance::bot.send_message(
        SiteSetting.discord_sync_admin_channel_id,
        "Discord user #{discord_id} has no linked Discourse account, skipping."
      )
    else
      result.each do |t|
        self.sync_user(t)
      end
    end
  end

  def self.sync_user(user)
    discord_id = nil

    builder = DB.build("select uaa.provider_uid from user_associated_accounts uaa /*where*/ limit 1")
    builder.where("provider_name = :provider_name", provider_name: "discord")
    builder.where("uaa.user_id = :user_id", user_id: user.id)
    builder.query.each do |t|
      discord_id = t.provider_uid
    end

    return if discord_id.nil?

    mapping = self.role_group_map
    return if mapping.empty?

    Instance::bot.servers.each do |key, server|
      member = server.member(discord_id)
      next if member.nil?

      member_role_names = member.roles.map(&:name)

      mapping.each do |role_name, group_name|
        group = Group.find_by(name: group_name)
        next if group.nil?

        discourse_user = User.find_by(id: user.id)
        next if discourse_user.nil?

        has_discord_role = member_role_names.include?(role_name)
        in_discourse_group = GroupUser.exists?(group_id: group.id, user_id: discourse_user.id)

        if has_discord_role && !in_discourse_group
          group.add(discourse_user)
          Instance::bot.send_message(
            SiteSetting.discord_sync_admin_channel_id,
            "Added @#{discourse_user.username} to Discourse group #{group_name} via Discord role #{role_name}"
          )
        elsif !has_discord_role && in_discourse_group
          group.remove(discourse_user)
          Instance::bot.send_message(
            SiteSetting.discord_sync_admin_channel_id,
            "Removed @#{discourse_user.username} from Discourse group #{group_name} via Discord role #{role_name}"
          )
        end
      end
    end
  end

end
