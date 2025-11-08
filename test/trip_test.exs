defmodule TripTest do
  use ExUnit.Case
  alias Urbanfleet.{Trip, UserManager}

  setup do
    File.write!("data/users.dat", "")
    UserManager.register("ana", "cliente", "1234")
    UserManager.register("luis", "conductor", "abcd")
    :ok
  end

  test "viaje finaliza y actualiza puntajes" do
    {:ok, _pid} = Trip.start_link(%{
      cliente: "ana",
      conductor: "luis",
      origen: "Armenia",
      destino: "Calarca",
      duracion_ms: 1000
    })

    :timer.sleep(1500)

    assert {:ok, pts_ana} = UserManager.get_score("ana")
    assert {:ok, pts_luis} = UserManager.get_score("luis")

    assert pts_ana >= 10
    assert pts_luis >= 15
  end
end
