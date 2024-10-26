defmodule Reed.MixProject do
  use Mix.Project

  def project do
    [
      app: :reed,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:saxy, "~> 1.6"},
      {:req, "~> 0.5", optional: true},
      {:ex_doc, "~> 0.31.0", only: :docs}
    ]
  end

  defp package do
    [
      maintainers: ["Andres Alejos"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/acalejos/reed"}
    ]
  end

  defp docs do
    [
      main: "Reed"
    ]
  end
end
