# discourse-discord-sync

A Discourse plugin that syncs Discord roles to Discourse groups in real time using a Discord bot and Discord OAuth2.

When a user is given a role in Discord, they are automatically added to the corresponding Discourse group — and removed when the role is taken away.

---

## Requirements

- Discord OAuth2 must be configured on your Discourse instance so accounts can be linked. If you want account linking without allowing Discord login, see [this solution](https://meta.discourse.org/t/partially-enable-login-option/175330/4?u=barreeeiroo).
- Your bot must have the **Server Members Intent** enabled in the Discord Developer Portal.

---

## Installation

1. Follow the standard [plugin installation guide](https://meta.discourse.org/t/install-a-plugin/19157) using this repository URL.
2. Set up [Login with Discord](https://meta.discourse.org/t/configuring-discord-login-for-discourse/127129) on your Discourse instance.
3. In the [Discord Developer Portal](https://discord.com/developers/applications), go to your app → **Bot** and enable all **Privileged Gateway Intents**.
4. Invite the bot to your server with **Administrator** permissions and make sure its role is positioned above any roles it needs to manage.
5. Configure the plugin settings in Discourse Admin → Settings → Plugins.

---

## Configuration

| Setting | Description |
|---|---|
| `discord_sync_enabled` | Enable or disable the integration |
| `discord_sync_token` | Bot token from the Discord Developer Portal |
| `discord_sync_admin_channel_id` | Channel ID where the bot posts sync log messages |
| `discord_sync_role_group_map` | Pipe-separated list of `role_id:group_name` mappings |

---

## Role Mapping

Mappings are set in `discord_sync_role_group_map` using the following format:

```
ROLE_ID:group_name|ROLE_ID:group_name
```

**Example:**
```
1234567890123456789:staff|9876543210987654321:moderators
```

To get a role ID, enable Developer Mode in Discord (User Settings → Advanced → Developer Mode), then right-click any role and select **Copy Role ID**.

---

## How It Works

1. User links their Discord account via Discord OAuth2 on Discourse.
2. When their roles change in Discord, the bot receives a `GUILD_MEMBER_UPDATE` event.
3. The bot compares their Discord roles against the configured mappings.
4. The user is added to or removed from the corresponding Discourse groups automatically.

---

## License

MIT
