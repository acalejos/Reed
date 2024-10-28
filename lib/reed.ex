defmodule Reed do
  if Code.ensure_loaded?(Req) do
    @moduledoc """
    #{File.cwd!() |> Path.join("README.md") |> File.read!() |> then(&Regex.run(~r/.*<!-- BEGIN MODULEDOC -->(?P<body>.*)<!-- END MODULEDOC -->.*/s, &1, capture: :all_but_first)) |> hd()}
    """
    @doc """
    Stream the RSS feed at the specified URL.

    ## Options
    * `:transform` - The transformation pipeline to apply while streaming the RSS feed's items.
     Accepts passes through option to `Req`.
    """
    def get(url, req_opts \\ []) do
      Req.new(url: url)
      |> Reed.ReqPlugin.attach()
      |> Req.merge(req_opts)
      |> Req.get()
    end

    def get!(url, req_opts \\ []) do
      case get(url, req_opts) do
        {:ok, resp} -> resp
        {:error, err} -> raise err
      end
    end
  end
end
