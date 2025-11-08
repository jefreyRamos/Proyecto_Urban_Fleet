defmodule ServerTest do
  use ExUnit.Case
  alias Urbanfleet.{Server, UserManager}

  setup do
    File.write!("data/users.dat", "")
    UserManager.register("ana", "cliente", "1234")
    UserManager.register("luis", "conductor", "abcd")
    :ok
  end

  test "crear_viaje/4 inicia un proceso" do
    {:ok, pid} = Server.crear_viaje("ana", "luis", "Armenia", "Montenegro")
    assert Process.alive?(pid)
  end

  test "mostrar_ranking imprime usuarios" do
    :ok = Server.mostrar_ranking()
  end
end
