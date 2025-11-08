defmodule Urbanfleet.Trip do
  @moduledoc """
  GenServer que representa un viaje activo entre un cliente y un conductor.
  """

  use GenServer
  alias Urbanfleet.{Persistence, UserManager}

  # ==============
  #  API Pública
  # ==============

  @doc """
  Inicia un viaje. Se pasa un mapa con:
  %{
    cliente: "ana",
    conductor: "luis",
    origen: "Quindio",
    destino: "Calarca",
    duracion_ms: 10000
  }
  """
  def start_link(info) do
    GenServer.start_link(__MODULE__, info)
  end

  @doc "Consulta el estado del viaje actual."
  def status(pid) do
    GenServer.call(pid, :status)
  end

  @doc "Finaliza manualmente un viaje antes del temporizador."
  def finish(pid) do
    GenServer.cast(pid, :finish)
  end

  # =====================
  #  Callbacks del GenServer
  # =====================

  @impl true
  def init(info) do
    IO.puts("🚗 Iniciando viaje de #{info.cliente} hacia #{info.destino} con #{info.conductor}")

    # Guardamos la hora de inicio
    state =
      info
      |> Map.put(:estado, :activo)
      |> Map.put(:inicio, DateTime.utc_now())

    # Temporizador automático (duracion_ms o 15 seg por defecto)
    duracion = Map.get(info, :duracion_ms, 15_000)
    Process.send_after(self(), :auto_finish, duracion)

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  # Finalización manual
  @impl true
  def handle_cast(:finish, state) do
    {:noreply, completar_viaje(state, :manual)}
  end

  # Finalización automática
  @impl true
  def handle_info(:auto_finish, state) do
    {:noreply, completar_viaje(state, :auto)}
  end

  # =====================
  #  Funciones privadas
  # =====================

  defp completar_viaje(state, modo) do
    fin = DateTime.utc_now()
    duracion_seg =
      DateTime.diff(fin, state.inicio)
      |> max(1)

    # Actualizar puntajes
    _ = UserManager.update_score(state.cliente, 10)
    _ = UserManager.update_score(state.conductor, 15)

    # Registrar resultado en archivo
    linea = """
    #{DateTime.to_string(fin)};cliente=#{state.cliente};conductor=#{state.conductor};origen=#{state.origen};destino=#{state.destino};estado=Completado;modo=#{modo};duracion=#{duracion_seg}s
    """

    Persistence.append_line("data/results.log", linea)

    IO.puts("✅ Viaje finalizado: #{state.cliente} → #{state.destino} (#{duracion_seg}s)")

    Map.put(state, :estado, :finalizado)
  end
end
