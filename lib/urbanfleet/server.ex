defmodule UrbanFleet.Server do
  use GenServer
  alias UrbanFleet.{UserManager, Persistence, TripSupervisor, Location}

  def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def crear_viaje(cli, cond, ori, dest, dur \\ 5000) do
    GenServer.call(__MODULE__, {:crear_viaje, cli, cond, ori, dest, dur})
  end

  def mostrar_resultados, do: GenServer.call(__MODULE__, :mostrar_resultados)
  def mostrar_ranking, do: GenServer.call(__MODULE__, :mostrar_ranking)

  def request_trip(usuario, origen, destino),
    do: GenServer.call(__MODULE__, {:request_trip, usuario, origen, destino})

  def list_trips, do: GenServer.call(__MODULE__, :list_trips)

  def accept_trip(id, conductor),
    do: GenServer.call(__MODULE__, {:accept_trip, id, conductor})

  @impl true
  def init(_arg), do: {:ok, %{pending_trips: %{}, trip_counter: 0}}

  ## --------------------
  ## handle_call
  ## --------------------

  @impl true
  def handle_call({:crear_viaje, cliente, conductor, origen, destino, duracion}, _from, state) do
    IO.puts("🚕 Creando viaje #{cliente} → #{destino} con #{conductor}")

    {:ok, pid} =
      DynamicSupervisor.start_child(
        UrbanFleet.TripSupervisor,
        {UrbanFleet.Trip, %{cliente: cliente, conductor: conductor, origen: origen, destino: destino, duracion_ms: duracion}}
      )

    new_state = %{state | trip_counter: state.trip_counter + 1}

    {:reply, {:ok, pid}, new_state}
  end

  def handle_call({:request_trip, cliente, ori, dest}, _from, st) do
    if Location.valid?(ori) and Location.valid?(dest) do
      id = "trip#{st.trip_counter + 1}"
      info = %{cliente: cliente, origen: ori, destino: dest}

      ref = Process.send_after(self(), {:expire_trip, id}, 30_000)

      pending = Map.put(st.pending_trips, id, Map.put(info, :timer_ref, ref))

      {:reply, {:ok, id}, %{st | pending_trips: pending, trip_counter: st.trip_counter + 1}}
    else
      {:reply, {:error, "Ubicación inválida"}, st}
    end
  end

  def handle_call(:list_trips, _from, st), do: {:reply, st.pending_trips, st}

  def handle_call({:accept_trip, id, cond}, _from, st) do
    case Map.get(st.pending_trips, id) do
      nil ->
        {:reply, {:error, "Viaje no encontrado"}, st}

      info ->
        Process.cancel_timer(info.timer_ref)
        new_pending = Map.delete(st.pending_trips, id)

        full =
          info
          |> Map.put(:conductor, cond)
          |> Map.put(:duracion_ms, 20_000)

        case TripSupervisor.start_trip(full) do
          {:ok, _pid} -> {:reply, {:ok, id}, %{st | pending_trips: new_pending}}
          _ -> {:reply, {:error, "Error al iniciar viaje"}, st}
        end
    end
  end

  def handle_call(:mostrar_resultados, _from, st) do
    path = "data/results.log"

    if File.exists?(path) do
      IO.puts("📜 HISTORIAL:\n" <> (Persistence.read_lines(path) |> Enum.join("\n")))
      {:reply, :ok, st}
    else
      {:reply, {:error, "No hay registros"}, st}
    end
  end

  def handle_call(:mostrar_ranking, _from, st) do
    IO.puts("\n🏆 RANKING\n------------------")
    UserManager.ranking(10)
    |> Enum.each(fn {u,p,r} -> IO.puts("#{u} (#{r}): #{p} pts") end)

    {:reply, :ok, st}
  end

  ## --------------------
  ## handle_info
  ## --------------------

  @impl true
  def handle_info({:expire_trip, id}, st) do
    case Map.get(st.pending_trips, id) do
      nil ->
        {:noreply, st}

      info ->
        UserManager.update_score(info.cliente, -5)

        Persistence.append_line(
          "data/results.log",
          "#{DateTime.utc_now()};cliente=#{info.cliente};origen=#{info.origen};destino=#{info.destino};estado=Expirado"
        )

        {:noreply, %{st | pending_trips: Map.delete(st.pending_trips, id)}}
    end
  end
end
