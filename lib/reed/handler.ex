defmodule Reed.Handler do
  @moduledoc false
  @behaviour Saxy.Handler

  defmodule State do
    defstruct feed_info: %{},
              current_item: nil,
              current_text: "",
              current_path: [],
              transform: nil,
              halted: false,
              private: %{}
  end

  @client_keys [:feed_info, :current_item, :halted, :private]

  def client_state(state), do: Map.take(state, @client_keys)

  @impl Saxy.Handler
  def handle_event(:start_document, _prolog, state), do: {:ok, state}

  @impl Saxy.Handler
  def handle_event(:end_document, _data, state), do: {:ok, state}

  @impl Saxy.Handler
  def handle_event(:start_element, {name, attributes}, state) do
    current_path = [name | state.current_path]

    new_state =
      cond do
        name == "item" ->
          %{
            state
            | current_item: %{},
              current_path: current_path
          }

        not is_nil(state.current_item) ->
          current_item =
            if attributes != [] do
              put_in(
                state.current_item,
                current_path
                |> item_path()
                |> access(),
                Map.new(attributes)
              )
            else
              state.current_item
            end

          %{
            state
            | current_path: current_path,
              current_item: current_item
          }

        true ->
          feed_info =
            if attributes != [] do
              put_in(
                state.feed_info,
                current_path
                |> feed_path()
                |> access(),
                Map.new(attributes)
              )
            else
              state.feed_info
            end

          %{
            state
            | current_path: current_path,
              feed_info: feed_info
          }
      end

    {:ok, new_state}
  end

  @impl Saxy.Handler
  def handle_event(:end_element, name, state) do
    [_current | parent_path] = state.current_path

    new_state =
      cond do
        not is_nil(state.current_item) and name == "item" ->
          client_state =
            state
            |> client_state()
            |> state.transform.()

          state = Map.merge(state, client_state)

          %{
            state
            | current_item: nil,
              current_text: "",
              current_path: parent_path
          }

        not is_nil(state.current_item) ->
          local_path =
            state.current_path |> item_path()

          value =
            get_in(state.current_item, local_path) ||
              String.trim(state.current_text)

          %{
            state
            | current_item:
                put_in(
                  state.current_item,
                  local_path
                  |> access(),
                  value
                ),
              current_text: "",
              current_path: parent_path
          }

        true ->
          value =
            get_in(state.feed_info, state.current_path |> feed_path()) ||
              String.trim(state.current_text)

          %{
            state
            | feed_info:
                put_in(
                  state.feed_info,
                  state.current_path |> feed_path() |> access(),
                  value
                ),
              current_text: "",
              current_path: parent_path
          }
      end

    if state.halted, do: {:stop, new_state}, else: {:ok, new_state}
  end

  @impl Saxy.Handler
  def handle_event(:characters, chars, state) do
    {:ok, %{state | current_text: state.current_text <> chars}}
  end

  defp item_path(path) do
    path
    |> Enum.split_while(&(&1 != "item"))
    |> elem(0)
    |> Enum.reverse()
  end

  defp feed_path(path) do
    path |> Enum.reverse()
  end

  defp access(path) do
    path |> Enum.map(&Access.key(&1, %{}))
  end
end
