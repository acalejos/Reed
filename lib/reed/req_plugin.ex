if Code.ensure_loaded?(Req) || Mix.env() == :docs do
  defmodule Reed.ReqPlugin do
    @moduledoc """
    A `Req` plugin for `Reed`.

    This will stream the RSS feed over the network and apply the transformation to each item lazily.

    This will store the result into the `Req.Response` struct under the `:rss` key in the `:private`
    field.

    This is streamed chunk-by-chunk, meaning you can stop reading the RSS feed at any point, and
    you only store in memory what you decide to using the `:transform` option.

    You can get the result using `Req.Response.get_private(response, :rss)`.

    ## Options
    * `:transform` - The transformation function / pipeline to apply to each item in the RSS feed. Check
                      the documentation for `Reed` for more information.
    """
    alias Req.{Request, Response}

    @doc """
    Attaches `Reed.ReqPlugin` to the given `Req.Request` struct.
    """
    def attach(%Req.Request{} = request, options \\ []) do
      request
      |> Request.register_options([:transform])
      |> Request.merge_options(options)
      |> Request.prepend_request_steps(setup_rss_stream: &setup_rss_stream/1)
    end

    def setup_rss_stream(request) do
      item_handler = Map.get(request.options, :transform, [& &1])

      item_handler =
        cond do
          is_function(item_handler, 1) ->
            [item_handler]

          is_list(item_handler) && Enum.all?(item_handler, &is_function/1) ->
            item_handler

          true ->
            raise ArgumentError,
                  "`:transform` must either be an arity-1 function or a list of arity-1 functions"
        end

      {:ok, partial} =
        Saxy.Partial.new(Reed.Handler, %Reed.State{
          transform: item_handler
        })

      request
      |> Request.put_private(:partial, partial)
      |> Map.put(
        :into,
        fn {:data, chunk}, {req, resp} ->
          partial = Request.get_private(req, :partial)

          try do
            case Saxy.Partial.parse(partial, chunk) do
              {:cont, new_partial} ->
                request = Request.put_private(req, :partial, new_partial)

                client_state =
                  new_partial
                  |> Saxy.Partial.get_state()
                  |> Reed.Handler.client_state()

                resp = Response.put_private(resp, :rss, client_state)
                {:cont, {request, resp}}

              {:halt, final_user_state} ->
                request =
                  Request.update_private(
                    req,
                    :partial,
                    nil,
                    fn %{
                         state:
                           %{
                             user_state: %{}
                           } = state
                       } = partial ->
                      %{partial | state: %{state | user_state: final_user_state}}
                    end
                  )

                resp =
                  Response.put_private(resp, :rss, Reed.Handler.client_state(final_user_state))

                {:halt, {request, resp}}

              {:error, reason} ->
                raise reason
            end
          rescue
            Saxy.ParseError ->
              client_state =
                partial
                |> Saxy.Partial.get_state()
                |> Reed.Handler.client_state()

              resp = Response.put_private(resp, :rss, client_state)
              {:halt, {request, resp}}
          end
        end
      )
    end
  end
end
