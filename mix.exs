defmodule UrbanFleet.MixProject do
  use Mix.Project

  def project do
    [
      app: :urban_fleet,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {UrbanFleet.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end
end
