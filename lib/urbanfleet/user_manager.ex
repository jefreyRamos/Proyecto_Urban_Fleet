defmodule Urbanfleet.UserManager do
  @moduledoc """
  GenServer que administra usuarios, login, registro, puntajes y ranking.

  Estado interno:
    %{
      users: %{
        username => %{role: "cliente" | "conductor", pass: "plain", points: integer()}
      }
    }

  Persistencia en: "data/users.dat" con formato por línea:
    username;role;password;points
  """

  use GenServer
  alias Urbanfleet.Persistence

  @data_file "data/users.dat"

  ## API (métodos públicos)

  @doc "Inicia el GenServer y lo registra con el nombre del módulo."
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Registra un usuario nuevo. Devuelve {:ok, user_map} o {:error, :already_exists}."
  def register(username, role, password) when is_binary(username) and is_binary(role) and is_binary(password) do
    GenServer.call(__MODULE__, {:register, String.trim(username), String.trim(role), password})
  end

  @doc "Realiza login: {:ok, user_map} | {:error, :no_user} | {:error, :wrong_pass}"
  def login(username, password) when is_binary(username) and is_binary(password) do
    GenServer.call(__MODULE__, {:login, String.trim(username), password})
  end

  @doc "Obtiene el puntaje actual del usuario: {:ok, points} | {:error, :no_user}"
  def get_score(username) when is_binary(username) do
    GenServer.call(__MODULE__, {:get_score, String.trim(username)})
  end

  @doc "Actualiza el puntaje (suma delta, puede ser negativo). Devuelve {:ok, new_points} o {:error, :no_user}."
  def update_score(username, delta) when is_binary(username) and is_integer(delta) do
    GenServer.call(__MODULE__, {:update_score, String.trim(username), delta})
  end

  @doc "Devuelve ranking top N. Opcional: filtrar por rol (\"cliente\" | \"conductor\" | nil)."
  def ranking(limit \\ 10, role_filter \\ nil) when is_integer(limit) do
    GenServer.call(__MODULE__, {:ranking, limit, role_filter})
  end

  @doc "Lista todos los usuarios (mapa)."
  def all_users() do
    GenServer.call(__MODULE__, :all_users)
  end

  ## GenServer callbacks

  @impl true
  def init(_init_arg) do
    users = load_users_from_file()
    {:ok, %{users: users}}
  end

  @impl true
  def handle_call({:register, username, role, password}, _from, state) do
    if Map.has_key?(state.users, username) do
      {:reply, {:error, :already_exists}, state}
    else
      user = %{role: role, pass: password, points: 0}
      new_users = Map.put(state.users, username, user)
      persist_users(new_users)
      {:reply, {:ok, Map.put(user, :username, username)}, %{state | users: new_users}}
    end
  end

  def handle_call({:login, username, password}, _from, state) do
    case Map.get(state.users, username) do
      nil ->
        {:reply, {:error, :no_user}, state}

      %{pass: ^password} = user ->
        {:reply, {:ok, Map.put(user, :username, username)}, state}

      _ ->
        {:reply, {:error, :wrong_pass}, state}
    end
  end

  def handle_call({:get_score, username}, _from, state) do
    case Map.get(state.users, username) do
      nil -> {:reply, {:error, :no_user}, state}
      %{points: pts} -> {:reply, {:ok, pts}, state}
    end
  end

  def handle_call({:update_score, username, delta}, _from, state) do
    case Map.get(state.users, username) do
      nil ->
        {:reply, {:error, :no_user}, state}

      user ->
        new_points = user.points + delta
        updated_user = Map.put(user, :points, new_points)
        new_users = Map.put(state.users, username, updated_user)
        persist_users(new_users)
        {:reply, {:ok, new_points}, %{state | users: new_users}}
    end
  end

  def handle_call({:ranking, limit, role_filter}, _from, state) do
    users_list =
      state.users
      |> Enum.filter(fn {_k, v} -> is_nil(role_filter) or v.role == role_filter end)
      |> Enum.map(fn {username, v} -> {username, v.points, v.role} end)
      |> Enum.sort_by(fn {_u, pts, _r} -> -pts end)
      |> Enum.take(limit)

    {:reply, users_list, state}
  end

  def handle_call(:all_users, _from, state) do
    {:reply, state.users, state}
  end

  ## Helpers

  defp load_users_from_file do
    Persistence.read_lines(@data_file)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ";") do
        [username, role, pass, points_str] ->
          points =
            case Integer.parse(points_str || "0") do
              {n, _} -> n
              :error -> 0
            end

          Map.put(acc, String.trim(username), %{role: String.trim(role), pass: pass, points: points})

        _ ->
          acc
      end
    end)
  end

  defp persist_users(users_map) when is_map(users_map) do
    lines =
      users_map
      |> Enum.map(fn {username, %{role: role, pass: pass, points: pts}} ->
        "#{username};#{role};#{pass};#{pts}"
      end)

    # write_lines reemplaza el archivo de forma atómica
    Persistence.write_lines(@data_file, lines)
    :ok
  end
end
