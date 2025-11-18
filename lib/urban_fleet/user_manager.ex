defmodule UrbanFleet.UserManager do
  # Gestor de usuarios, registro, login, sesiones y puntajes
  use GenServer
  alias UrbanFleet.Persistence

  @data_file "data/users.dat"

  # REGISTRO GLOBAL
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})
  end

  # API usando global
  def register(username, role, password),
    do: GenServer.call({:global, __MODULE__}, {:register, String.trim(username), String.trim(role), to_string(password)})

  def login(username, password),
    do: GenServer.call({:global, __MODULE__}, {:login, String.trim(username), to_string(password)})

  def connect(username),
    do: GenServer.cast({:global, __MODULE__}, {:connect, String.trim(username)})

  def disconnect(username),
    do: GenServer.cast({:global, __MODULE__}, {:disconnect, String.trim(username)})

  def sessions(),
    do: GenServer.call({:global, __MODULE__}, :sessions)

  def get_score(username),
    do: GenServer.call({:global, __MODULE__}, {:get_score, String.trim(username)})

  def update_score(username, delta) when is_integer(delta),
    do: GenServer.call({:global, __MODULE__}, {:update_score, String.trim(username), delta})

  def ranking(limit \\ 10, role_filter \\ nil),
    do: GenServer.call({:global, __MODULE__}, {:ranking, limit, role_filter})

  def all_users,
    do: GenServer.call({:global, __MODULE__}, :all_users)

  # Init
  @impl true
  def init(_arg) do
    users = load_users_from_file()
    {:ok, %{users: users, sessions: %{}, stats: %{}}}
  end

  # CASTS
  @impl true
  def handle_cast({:connect, username}, state) do
    {:noreply, %{state | sessions: Map.put(state.sessions, username, System.system_time(:second))}}
  end

  def handle_cast({:disconnect, username}, state) do
    {:noreply, %{state | sessions: Map.delete(state.sessions, username)}}
  end

  # CALLS
  @impl true
  def handle_call({:register, username, role, pass}, _from, state) do
    if Map.has_key?(state.users, username) do
      {:reply, {:error, :already_exists}, state}
    else
      user = %{role: role, pass: pass, points: 0}
      new_users = Map.put(state.users, username, user)
      persist_users(new_users)
      {:reply, {:ok, Map.put(user, :username, username)}, %{state | users: new_users}}
    end
  end

  def handle_call({:login, username, pass}, _from, state) do
    case Map.get(state.users, username) do
      nil -> {:reply, {:error, :no_user}, state}
      %{pass: ^pass} = u -> {:reply, {:ok, Map.put(u, :username, username)}, state}
      _ -> {:reply, {:error, :wrong_pass}, state}
    end
  end

  def handle_call(:sessions, _from, state), do: {:reply, state.sessions, state}

  def handle_call({:get_score, username}, _from, state) do
    case Map.get(state.users, username) do
      nil -> {:reply, {:error, :no_user}, state}
      %{points: p} -> {:reply, {:ok, p}, state}
    end
  end

  def handle_call({:update_score, username, delta}, _from, state) do
    case Map.get(state.users, username) do
      nil -> {:reply, {:error, :no_user}, state}

      user ->
        new_points = user.points + delta
        updated = Map.put(user, :points, new_points)
        new_users = Map.put(state.users, username, updated)
        persist_users(new_users)
        {:reply, {:ok, new_points}, %{state | users: new_users}}
    end
  end

  def handle_call({:ranking, limit, role_filter}, _from, state) do
    users =
      state.users
      |> Enum.filter(fn {_u, v} -> is_nil(role_filter) or v.role == role_filter end)
      |> Enum.map(fn {u, v} -> {u, v.points, v.role} end)
      |> Enum.sort_by(fn {_u, pts, _} -> -pts end)
      |> Enum.take(limit)

    {:reply, users, state}
  end

  def handle_call(:all_users, _from, state), do: {:reply, state.users, state}

  # HELPERS
  defp load_users_from_file do
    Persistence.read_lines(@data_file)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ";") do
        [user, role, pass, pts] ->
          pts_i =
            case Integer.parse(pts || "0") do
              {n, _} -> n
              :error -> 0
            end

          Map.put(acc, String.trim(user), %{role: String.trim(role), pass: pass, points: pts_i})

        _ ->
          acc
      end
    end)
  end

  defp persist_users(map) when is_map(map) do
    lines =
      map
      |> Enum.map(fn {u, %{role: r, pass: p, points: pts}} -> "#{u};#{r};#{p};#{pts}" end)

    case Persistence.write_lines(@data_file, lines) do
      :ok -> :ok
      {:error, e} -> IO.puts("Error persisting users: #{inspect(e)}")
    end
  end
end
