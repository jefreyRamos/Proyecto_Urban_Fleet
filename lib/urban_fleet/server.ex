defmodule UrbanFleet.Server do
  # Es el cerebro del sistema, reibe y gestiona las solicitudes de viajes
  use GenServer
  alias UrbanFleet.{UserManager, Persistence,  Location, Trip}

  # REGISTRO GLOBAL
  def start_link(_opts \\ []),
    do: GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})

  # API usando global
  def crear_viaje(cli, cond, ori, dest, dur \\ 90000),
    do: GenServer.call({:global, __MODULE__}, {:crear_viaje, cli, cond, ori, dest, dur})

  def request_trip(usuario, origen, destino),
    do: GenServer.call({:global, __MODULE__}, {:request_trip, usuario, origen, destino})

  def list_trips,
    do: GenServer.call({:global, __MODULE__}, :list_trips)

  def accept_trip(id, conductor),
    do: GenServer.call({:global, __MODULE__}, {:accept_trip, id, conductor})

  def mostrar_resultados,
    do: GenServer.call({:global, __MODULE__}, :mostrar_resultados)

  def mostrar_ranking,
    do: GenServer.call({:global, __MODULE__}, :mostrar_ranking)

  def trip_status(id),
    do: GenServer.call({:global, __MODULE__}, {:trip_status, id})

  # Init es donde se inicializa el estado del GenServer
  @impl true
  def init(_) do
    {:ok,
      %{
        pending_trips: %{},
        active_trips: %{},
        trip_counter: 0
      }}
  end

  # GRUPO COMPLETO handle_call/3
  @impl true
  def handle_call({:crear_viaje, cliente, conductor, origen, destino, duracion}, _from, state) do
    if not Location.valid?(origen) or not Location.valid?(destino) do
      {:reply, {:error, "Ubicación inválida"}, state}
    else
      {:ok, pid} =
        DynamicSupervisor.start_child(
          {:global, UrbanFleet.TripSupervisor},
          {UrbanFleet.Trip,
            %{cliente: cliente, conductor: conductor, origen: origen, destino: destino,
              duracion_ms: duracion}}
        )

      {:reply, {:ok, pid}, %{state | trip_counter: state.trip_counter + 1}}
    end
  end

  # handle_call/3 es donde se manejan las llamadas síncronas al GenServer
  @impl true
  def handle_call({:request_trip, cliente, ori, dest}, _from, st) do
    if Location.valid?(ori) and Location.valid?(dest) do
      id = "trip#{st.trip_counter + 1}"

      info = %{cliente: cliente, origen: ori, destino: dest}
      ref = Process.send_after(self(), {:expire_trip, id}, 90_000)

      pending = Map.put(st.pending_trips, id, Map.put(info, :timer_ref, ref))

      {:reply, {:ok, id},
      %{st | pending_trips: pending, trip_counter: st.trip_counter + 1}}
    else
      {:reply, {:error, "Ubicación inválida"}, st}
    end
  end

  @impl true
  def handle_call(:list_trips, _from, st),
    do: {:reply, st.pending_trips, st}

  @impl true
  def handle_call({:accept_trip, id, cond}, _from, st) do
    case Map.get(st.pending_trips, id) do
      nil ->
        {:reply, {:error, "Viaje no encontrado"}, st}

      info ->
        Process.cancel_timer(info.timer_ref)

        full_info =
          info
          |> Map.put(:conductor, cond)
          |> Map.put(:duracion_ms, 90_000)

        case DynamicSupervisor.start_child({:global, UrbanFleet.TripSupervisor}, {UrbanFleet.Trip, full_info}) do
          {:ok, pid} ->
            new_pending = Map.delete(st.pending_trips, id)
            new_active = Map.put(st.active_trips, id, pid)

            {:reply, {:ok, pid},
            %{st | pending_trips: new_pending, active_trips: new_active}}

          error ->
            {:reply, {:error, "Error al iniciar viaje: #{inspect(error)}"}, st}
        end
    end
  end

  @impl true
  def handle_call(:mostrar_resultados, _from, st) do
    path = "data/results.log"

    if File.exists?(path) do
      contenido = Persistence.read_lines(path) |> Enum.join("\n")
      IO.puts("\n HISTORIAL\n" <> contenido)
      {:reply, :ok, st}
    else
      {:reply, {:error, "No hay registros"}, st}
    end
  end

  @impl true
  def handle_call(:mostrar_ranking, _from, st) do
    IO.puts("\n RANKING\n------------------")

    UserManager.ranking(10)
    |> Enum.each(fn {u, p, r} ->
      IO.puts("#{u} (#{r}): #{p} pts")
    end)

    {:reply, :ok, st}
  end

  @impl true
  def handle_call({:trip_status, id}, _from, st) do
    case Map.get(st.active_trips, id) do
      nil ->
        {:reply, {:error, "Viaje no encontrado o no activo"}, st}

      pid ->
        {:reply, {:ok, Trip.status(pid)}, st}
    end
  end

  #GRUPO handle_info/2
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

  @impl true
  def handle_info({:trip_finished, pid}, st) do
    case Enum.find(st.active_trips, fn {_id, p} -> p == pid end) do
      nil ->
        {:noreply, st}

      {id, _} ->
        new_active = Map.delete(st.active_trips, id)
        {:noreply, %{st | active_trips: new_active}}
    end
  end
end
# Da manejo a los viajes, puntajes y es un genserver global
