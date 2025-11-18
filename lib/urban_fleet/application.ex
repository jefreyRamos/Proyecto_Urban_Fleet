defmodule UrbanFleet.Application do
  #Punto de inicio de la aplicacion
  use Application

  def start(_type, _args) do
    children = [
      # REGISTRO GLOBAL PARA TODOS LOS NODOS
      {UrbanFleet.UserManager, []},
      {UrbanFleet.Server, []},
      {UrbanFleet.TripSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: UrbanFleet.Supervisor]
    Supervisor.start_link(children, opts)
  end
  #Mantiene la aplicacion corriendo con un supervisor
end
