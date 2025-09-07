defmodule Tutor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TutorWeb.Telemetry,
      Tutor.Repo,
      {DNSCluster, query: Application.get_env(:tutor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Tutor.PubSub},
      # Learning session infrastructure
      Tutor.Learning.SessionRegistry,
      Tutor.Learning.ToolTaskSupervisor,
      Tutor.Learning.SessionSupervisor,
      # Start to serve requests, typically the last entry
      TutorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tutor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TutorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
