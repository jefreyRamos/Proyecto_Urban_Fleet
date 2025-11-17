defmodule UrbanFleet.UserManager do
  @moduledoc """
  Administra usuarios, login, puntajes y ranking.
  """

  use GenServer
  alias UrbanFleet.Persistence

  @data_file "data/users.dat"

  ## API

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register(username, role, password) do
    GenServer.call(__MODULE__, {:register, String.trim(username), role, password})
  end

  def login(username, password) do
    GenServer.call(__MODULE__, {:login, String.trim(username), password})
  end

  def get_score(username) do
    GenServer.call(__MODULE__, {:get_score, String.trim(username)})
  end

  def update_score(username, delta) do
    GenServer.call(__MODULE__, {:update_score, String.trim(username), delta})
  end

  def ranking(limit \\ 10, role_filter \\ nil) do
    GenServer.call(__MODULE__, {:ranking, limit, role_filter})
  end

  def all_users, do: GenServer.call(__MODULE__, :all_users)

  ## Callbacks

  @impl true
  def init(_arg) do
    users = load_users_from_file()
    {:ok, %{users: users, sessions: %{}}}
  end

  @impl true
  def handle_cast({:connect, username}, state) do
    {:noreply, %{state | sessions: Map.put(state.sessions, username, true)}}
  end

  def handle_cast({:disconnect, username}, state) do
    {:noreply, %{state | sessions: Map.delete(state.sessions, username)}}
  end

  ## handle_call agrupados

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

  def handle_call({:get_score, username}, _from, state) do
    case state.users |> Map.get(username) do
      nil -> {:reply, {:error, :no_user}, state}
      %{points: p} -> {:reply, {:ok, p}, state}
    end
  end

  def handle_call({:update_score, username, delta}, _from, state) do
    case Map.get(state.users, username) do
      nil -> {:reply, {:error, :no_user}, state}

      user ->
        new_user = %{user | points: user.points + delta}
        new_users = Map.put(state.users, username, new_user)
        persist_users(new_users)
        {:reply, {:ok, new_user.points}, %{state | users: new_users}}
    end
  end

  def handle_call({:ranking, limit, role_filter}, _from, state) do
    ranking =
      state.users
      |> Enum.filter(fn {_u, v} -> is_nil(role_filter) or v.role == role_filter end)
      |> Enum.map(fn {u, v} -> {u, v.points, v.role} end)
      |> Enum.sort_by(fn {_u, pts, _r} -> -pts end)
      |> Enum.take(limit)

    {:reply, ranking, state}
  end

  def handle_call(:all_users, _from, state), do: {:reply, state.users, state}

  ## Helpers

  defp load_users_from_file do
    Persistence.read_lines(@data_file)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ";") do
        [user, role, pass, pts] ->
          Map.put(acc, user, %{role: role, pass: pass, points: String.to_integer(pts)})
        _ -> acc
      end
    end)
  end

  defp persist_users(map) do
    lines =
      map
      |> Enum.map(fn {u, %{role: r, pass: p, points: pts}} ->
        "#{u};#{r};#{p};#{pts}"
      end)

    Persistence.write_lines(lines, @data_file)
  end
end
