defmodule LibclusterPostgres.MixProject do
  use Mix.Project

  def project do
    [
      name: "libcluster_postgres",
      app: :libcluster_postgres,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/supabase/libcluster_postgres",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Postgres strategy for libcluster"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:libcluster, "~> 3.3"},
      {:postgrex, ">= 0.0.0"}
    ]
  end

  defp package do
    [
      files: ["lib", "test", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Supabase"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/supabase/libcluster_postgres"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      formatters: ["html", "epub"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
