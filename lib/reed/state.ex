defmodule Reed.State do
  @moduledoc """
  The state tracked when reading an RSS stream with `Reed`.

  ## Fields

  ### Public Fields

  These fields are considered public and are passed to the pipeline transformation steps
  `:feed_info` - The feed-level metadata from the RSS feed. This will be collected before any items are parsed, and will
    be available during each transformation step.
  `:current_item` - Always references stores the current item in the stream.
  `:halted` - Whether to halt the stream after the current item is processed. Defaults to `false`.
  `:private` - A private map field that can be used during the transformation pipeline. Defaults to an empty map.

  ### Private Fields

  These fields are considered private and are used internally by `Reed` during the parsing process. These are NOT passed to
  the pipeline transformation functions.

  `:current_text`
  `:current_path`
  `:transform`
  """
  defstruct feed_info: %{},
            current_item: nil,
            current_text: "",
            current_path: [],
            transform: nil,
            halted: false,
            private: %{}
end
