defmodule Worker.MixProject do
  use Mix.Project

  def project do
    [
      app: :worker,
      version: "0.1.0",
      elixir: "~> 1.7.4",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Worker, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end
end
