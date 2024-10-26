defmodule Reed.Transformers do
  @moduledoc """
  Convenient transformer functions to be used during parsing with `Reed.Handler`.

  When composing functions from `Reed.Transformers`, be aware that order matters
  and is preserved.

  For example, if you use `transform_item/2` and `collect/2` in your pipeline,
  in order for `collect/2` to collect the transformed version of the item it
  must come after `transform_item/2`.
  """

  @type state :: map()
  @type transformer :: (state -> state)

  @doc """
  Transforms the current RSS feed item according to the
  given an arity-1 transformation function.
  """
  def transform_item(%{current_item: item} = state, transformer)
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

    if Map.fetch!(private, :count) >= count, do: halt(state), else: state
  end

  @doc """
  Collects all items into a list.

  The final list will be under the `:items` key in the state, and
  will be in reverse order.
  """
  def collect(%{current_item: item, private: private} = state) do
    %{state | private: Map.update(private, :items, [item], &[item | &1])}
  end

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
  Reed.get!(url, transform:
    fn state ->
      state
      |> stop_after(1)
      |> collect()
    end
  )
  ```

  ```elixir
  Reed.get!(url, transform:
    stop_after(1)
    |> collect()
    |> transform()
  )
  ```
  """
  defmacro transform(pipeline) do
    quote do
      fn state ->
        state |> unquote(pipeline)
      end
    end
  end
end
