defmodule Reed.Transformers do
  @moduledoc """
  Convenient transformer functions to be used during parsing with `Reed.Handler`.

  When composing functions from `Reed.Transformers`, be aware that order matters
  and is preserved.

  For example, if you use `transform/2` and `collect/2` in your pipeline,
  in order for `collect/2` to collect the transformed version of the item it
  must come after `transform/2`.

  Each transformer function must accept a `state` as the first argument and must
  return either a new `state` or a return value matching those accepted by
  `Enum.reduce_while/3`.
  """

  @type transformer :: (Reed.State.t() ->
                          Reed.State.t() | {:cont, Reed.State.t()} | {:halt, Reed.State.t()})

  @doc """
  Filters out items according to the `filter_with` function. This will skip all remaining
  steps in the pipeline for the current item. This does NOT halt the reading overall, but
  rather only the current transformation pipeline for the current item.

  This means that its position in the pipeline has effects on downstream operations,
  (eg. if you call `limit` before `filter` it will count all items, but
  if you call `limit` after `filter` it will only count the filtered items).
  """
  def filter(%{current_item: item} = state, filter_with \\ fn _item -> true end)
      when is_function(filter_with, 1) do
    {(filter_with.(item) && :cont) || :halt, state}
  end

  @doc """
  Transforms the current RSS feed item according to the
  given an arity-1 transformation function.
  """
  def transform(%{current_item: item} = state, transformer \\ fn item -> item end)
      when is_function(transformer, 1) do
    %{state | current_item: transformer.(item)}
  end

  @doc """
  Keeps track of how many RSS feed items have been processed and will halt
  the stream after the given # of RSS feed items have been processed.
  """
  def limit(%{private: private} = state, count) when is_integer(count) do
    private =
      private
      |> Map.update(:count, 1, &(&1 + 1))

    state = %{state | private: private}

    if private[:count] >= count, do: halt(state), else: state
  end

  @doc """
  Collects all items into a list.

  The final list will be under the `:items` key in the state, and
  will be in reverse order.
  """
  def collect(%{current_item: item, private: private} = state) do
    %{state | private: Map.update(private, :items, [item], &[item | &1])}
  end

  @doc """
  Halt the RSS streaming after the current item.
  """
  def halt(%{} = state) do
    %{state | halted: true}
  end

  @doc """
  A convenient macro that will format take your pipeline correctly
  if you have a pipeline composed entirely of functions with the following
  function signature: `(state::state, opts::list() \\ [])`

  This is the function signature that all transformer functions within
  `Reed.Transformers` have.

  This macro should always be called last in a transformation pipeline.

  ## Example

  The following two are equivalent:

  ```elixir
  Reed.get!(url, transform: [
      fn state -> stop_after(state, 1),
      fn state -> collect(state)
    ]
  )
  ```

  ```elixir
  Reed.get!(url, transform:
    fn state ->
    state
    |> stop_after(1)
    |> collect()
  end)
  ```

  ```elixir
  Reed.get!(url, transform:
    stop_after(1)
    |> collect()
    |> pipeline()
  )
  ```
  """
  defmacro pipeline(pipeline) do
    Macro.unpipe(pipeline)
    |> Enum.map(fn {{name, meta, args}, _pos} ->
      ast = {name, meta, [{:state, [], __MODULE__} | args]}

      quote do
        fn state ->
          unquote(ast)
        end
      end
    end)
  end
end
