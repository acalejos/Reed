defmodule Reed.Handler do
  @moduledoc false
  require Logger
  @behaviour Saxy.Handler

  defmodule State do
    defstruct feed_info: %{},
              current_item: nil,
              current_text: "",
              current_path: [],
              namespaces: %{},
              transform: nil,
              current_special_element: nil,
              special_element_attrs: %{},
              halted: false,
              private: %{}
  end

  @client_keys [:feed_info, :current_item, :halted, :private]

  # Special channel elements that have sub-elements or attributes
  @special_elements %{
    "image" => ["url", "title", "link", "width", "height", "description"],
    "cloud" => ["domain", "port", "path", "registerProcedure", "protocol"],
    "textInput" => ["title", "description", "name", "link"],
    "skipHours" => ["hour"],
    "skipDays" => ["day"],
    "category" => ["domain"]
  }

  def client_state(state), do: Map.take(state, @client_keys)

  # Saxy Handler Callbacks
  @impl Saxy.Handler
  def handle_event(:start_document, _prolog, state) do
    Logger.debug("Starting RSS document parsing")
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:end_document, _data, state) do
    Logger.debug("Completed RSS document parsing")
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:start_element, {name, attributes}, state) do
    Logger.debug("Starting element: #{name}")
    {namespaces, regular_attrs} = extract_namespaces(attributes)
    updated_namespaces = Map.merge(state.namespaces, namespaces)
    {_namespace, local_name} = parse_name(name)

    new_state =
      cond do
        local_name == "item" ->
          Logger.debug("Found new item")

          %{
            state
            | current_item: %{},
              current_path: ["item" | state.current_path],
              namespaces: updated_namespaces
          }

        is_special_element?(local_name) and Enum.at(state.current_path, 0) == "channel" ->
          Logger.debug("Found special element: #{local_name}")

          %{
            state
            | current_special_element: local_name,
              special_element_attrs: process_attributes(regular_attrs),
              current_path: [local_name | state.current_path],
              namespaces: updated_namespaces
          }

        true ->
          %{
            state
            | current_path: [local_name | state.current_path],
              namespaces: updated_namespaces
          }
      end

    {:ok, new_state}
  end

  @impl Saxy.Handler
  def handle_event(:end_element, name, state) do
    {namespace, local_name} = parse_name(name)

    new_state =
      cond do
        not is_nil(state.current_item) and local_name == "item" ->
          Logger.debug("Completed item processing")

          client_state =
            state
            |> client_state()
            |> state.transform.()

          state = Map.merge(state, client_state)

          %{
            state
            | current_item: nil,
              current_text: "",
              current_path: tl(state.current_path)
          }

        # Handle elements inside an item
        not is_nil(state.current_item) ->
          field_name = get_field_name(namespace, local_name)

          %{
            state
            | current_item:
                Map.put(state.current_item, field_name, String.trim(state.current_text)),
              current_text: "",
              current_path: tl(state.current_path)
          }

        # Handle channel-level elements
        Enum.at(state.current_path, 1) == "channel" and local_name != "channel" ->
          field_name = get_field_name(namespace, local_name)

          updated_feed_info =
            Map.put(state.feed_info, field_name, String.trim(state.current_text))

          %{
            state
            | feed_info: updated_feed_info,
              current_text: "",
              current_path: tl(state.current_path)
          }

        # Handle channel end
        local_name == "channel" ->
          %{state | current_text: "", current_path: tl(state.current_path)}

        # Handle all other elements
        true ->
          %{state | current_text: "", current_path: tl(state.current_path)}
      end

    if state.halted do
      {:stop, new_state}
    else
      {:ok, new_state}
    end
  end

  @impl Saxy.Handler
  def handle_event(:characters, chars, state) do
    {:ok, %{state | current_text: state.current_text <> chars}}
  end

  defp is_special_element?(name), do: Map.has_key?(@special_elements, name)

  defp process_attributes(attrs) do
    Enum.into(attrs, %{}, fn {key, value} -> {key, value} end)
  end

  defp get_field_name(nil, local_name), do: local_name
  defp get_field_name(namespace, local_name), do: "#{namespace}:#{local_name}"

  defp parse_name(name) do
    case String.split(name, ":", parts: 2) do
      [name] -> {nil, name}
      [prefix, name] -> {prefix, name}
    end
  end

  defp extract_namespaces(attributes) do
    Enum.reduce(attributes, {%{}, []}, fn
      {"xmlns:" <> prefix, uri}, {namespaces, attrs} ->
        {Map.put(namespaces, prefix, uri), attrs}

      {"xmlns", uri}, {namespaces, attrs} ->
        {Map.put(namespaces, nil, uri), attrs}

      attr, {namespaces, attrs} ->
        {namespaces, [attr | attrs]}
    end)
  end
end
