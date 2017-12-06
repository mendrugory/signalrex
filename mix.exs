defmodule Signalrex.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :signalrex,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: [main: "Signalrex", source_ref: "v#{@version}",
      source_url: "https://github.com/mendrugory/signalrex"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Signalrex is a signalr client library written in Elixir.
    """
  end  

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:tesla, "~> 0.9.0"},
      {:enchufeweb, "~> 0.1.0"},
      {:uuid, ">= 0.0.0"},
      {:earmark, ">= 0.0.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [name: :signalrex,
     maintainers: ["Gonzalo Jiménez Fuentes"],
     licenses: ["MIT License"],
     links: %{"GitHub" => "https://github.com/mendrugory/signalrex"}]
  end  
end
