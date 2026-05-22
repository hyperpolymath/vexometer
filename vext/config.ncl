# SPDX-License-Identifier: MPL-2.0
# Nickel configuration for vext
# Export to TOML: nickel export --format toml config.ncl > vext.toml

let IrcTarget = {
  server | String,
  port | Number | default = 6697,
  tls | Bool | default = true,
  channels | Array String,
  key | String | optional,
}

let RateLimitConfig = {
  messages_per_second | Number | default = 2,
  burst_size | Number | default = 5,
}

let PoolConfig = {
  max_connections_per_server | Number | default = 4,
  connection_timeout_secs | Number | default = 30,
  idle_timeout_secs | Number | default = 300,
}

let LoggingConfig = {
  level | [| 'trace, 'debug, 'info, 'warn, 'error |] | default = 'info,
  format | [| 'json, 'pretty, 'compact |] | default = 'pretty,
  file | String | optional,
}

let VextConfig = {
  # Server settings
  listen_address | String | default = "127.0.0.1",
  listen_port | Number | default = 6659,

  # Default IRC settings
  default_server | String | default = "irc.libera.chat",
  default_port | Number | default = 6697,
  default_tls | Bool | default = true,

  # Bot identity
  nick_prefix | String | default = "vext",
  realname | String | default = "vext IRC notification daemon",
  username | String | default = "vext",

  # Rate limiting
  rate_limit | RateLimitConfig | default = {},

  # Connection pool
  pool | PoolConfig | default = {},

  # Logging
  logging | LoggingConfig | default = {},

  # Predefined targets (optional)
  targets | Array IrcTarget | default = [],
}

# Default configuration
let default_config : VextConfig = {
  listen_address = "127.0.0.1",
  listen_port = 6659,
  default_server = "irc.libera.chat",
  default_port = 6697,
  default_tls = true,
  nick_prefix = "vext",
  realname = "vext IRC notification daemon",
  username = "vext",
  rate_limit = {
    messages_per_second = 2,
    burst_size = 5,
  },
  pool = {
    max_connections_per_server = 4,
    connection_timeout_secs = 30,
    idle_timeout_secs = 300,
  },
  logging = {
    level = 'info,
    format = 'pretty,
  },
  targets = [],
}

# Production configuration example
let production_config : VextConfig = default_config & {
  listen_address = "0.0.0.0",
  logging = {
    level = 'warn,
    format = 'json,
  },
  pool = {
    max_connections_per_server = 8,
    idle_timeout_secs = 600,
  },
}

# Export default config
default_config
