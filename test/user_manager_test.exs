defmodule UserManagerTest do
  use ExUnit.Case
  alias UrbanFleet.UserManager

  setup do
    # Limpia el archivo de usuarios y reinicia el proceso antes de cada prueba
    File.write!("data/users.dat", "")
    if pid = Process.whereis(UserManager), do: GenServer.stop(pid, :normal)
    {:ok, _} = UserManager.start_link()
    :ok
  end

  test "registro y login exitosos" do
    {:ok, _} = UserManager.register("ana", "cliente", "1234")
    assert {:ok, _} = UserManager.login("ana", "1234")
  end

  test "no permite usuario duplicado" do
    {:ok, _} = UserManager.register("ana", "cliente", "1234")
    assert {:error, :already_exists} = UserManager.register("ana", "cliente", "1234")
  end

  test "actualización y consulta de puntaje" do
    {:ok, _} = UserManager.register("ana", "cliente", "1234")
    {:ok, 10} = UserManager.update_score("ana", 10)
    assert {:ok, 10} = UserManager.get_score("ana")
  end
end
