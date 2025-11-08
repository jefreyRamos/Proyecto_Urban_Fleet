defmodule ProyectoUrbanFleet.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Aquí se listan los procesos supervisados
      Urbanfleet.UserManager,
      Urbanfleet.TripSupervisor,
      Urbanfleet.Server
    ]

    # Opciones del supervisor
    opts = [strategy: :one_for_one, name: ProyectoUrbanFleet.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
