defmodule BullsMp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BullsMpWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: BullsMp.PubSub},
      # Start the Endpoint (http/https)
      BullsMpWeb.Endpoint,
      # Start a worker by calling: BullsMp.Worker.start_link(arg)
      # {BullsMp.Worker, arg}
      BullsMp.BackupAgent,
      BullsMp.GameSup,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BullsMp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BullsMpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
