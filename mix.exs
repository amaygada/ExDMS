defmodule Master.MixProject do
  use Mix.Project

  def project do
    [
      app: :master,
      version: "0.1.0",
      elixir: "~> 1.14.3",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Master, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:axon, "~> 0.2.0"},
      {:exla, "~> 0.3.0"},
      {:nx, "~> 0.3.0"}
    ]
  end
end
