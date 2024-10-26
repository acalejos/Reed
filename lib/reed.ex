defmodule Reed do
  if Code.ensure_loaded?(Req) do
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
