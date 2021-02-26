# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :bulls_mp, BullsMpWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "I75el9pXb+nYGFwNrovdCElweWLdEXxxoImIG0ilKvVXbRFpT9VWjn0/myBPGyHv",
  render_errors: [view: BullsMpWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BullsMp.PubSub,
  live_view: [signing_salt: "bU9PpZPz"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
