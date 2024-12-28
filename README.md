# Reed

[![Reed version](https://img.shields.io/hexpm/v/reed.svg)](https://hex.pm/packages/reed)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/reed/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/Reed)](https://hex.pm/packages/reed)
[![Twitter Follow](https://img.shields.io/twitter/follow/ac_alejos?style=social)](https://twitter.com/ac_alejos)
<!-- BEGIN MODULEDOC -->

Streaming RSS parser with a built-in `Req` plugin for network-enabled chunked streaming.

## Installation

```elixir
def deps do
  [
    {:reed, "~> 0.1.0"}
  ]
end
```

Reed implements a Sax-based parser for RSS feeds using the [`Saxy`](https://github.com/qcam/saxy) library.

You can manually use the `Reed.Handler` (which implements the `Saxy.Handler` behaviour) with `Saxy` to parse
strings or from `Stream`s, but the killer feature of `Reed` is the `Reed.ReqPlugin` module, which powers the top-level
`Reed.get` / `Reed.get!` API.

`Reed` began as a need for a way to read RSS feeds by first reading the feed-level metadata followed
by item-by-item streaming without loading the entire feed into memory, all while doing so from a remote URL.

`Reed` combines the `Saxy.Partial` module with `Req`'s streaming `:into` option to do just that.

`Reed.ReqPlugin` takes advantage of `Req`'s chunking capability to parse RSS feeds directly from over the network, applying
transformation functions to each RSS item lazily.

This means you do not have to store the entire RSS feed in memory or on disk to convert to a traditional Elixir `Stream`
(as is required to use `Saxy.parse_stream/4`), but instead directly uses `Saxy.Partial` to parse chunk-by-chunk directly
over the wire.

The `Reed.Transformers` module provides some convenient transformation functions to be used during the parsing.

The transformation pipeline is invoked whenever a new RSS item is read, and works with an accumulating state that persists
during the entire RSS read.

`Reed` provides a dead-simple API that also allows for flexible handling of items during the stream through
the use of transformation pipelines (see `Reed.Transformers`).  These pipelines define how to handle the item
stream, and function as a reduction over an input state containing feed-level metadata, the current item, and
a private field where you can store other data.

The state also maintains a `:halted` field that controls whether to halt the stream after the current item has been
processed (had the whole `:transform` pipeline applied).

You can also control when to move on to the next item during a transformation pipeline by returning either `:halt`
or `{:halt, state}` from any step in the transformation pipeline (see `Reed.Transformers.filter/2` for an example).

You can compose the built-in pipeline function from `Reed.Transformers` or create your own unique steps to create very
simple yet powerful parsing instructions to carefully read only the exact parts of the RSS stream that you're interested in.

## Examples

### Get the feed metadata

```elixir
import Reed.Transformers
Reed.get!(rss_url, transform: transform(halt()))
```

### Get all items in a list

```elixir
import Reed.Transformers
Reed.get!(rss_url, transform: transform(collect()))
```

### Get the first 5 items in a list

```elixir
import Reed.Transformers
Reed.get!(rss_url, transform: collect() |> limit(5) |> transform())
```

### Get all `itunes:` namespaced elements from the first 2 items as a list

```elixir
import Reed.Transformers

Reed.get!(rss_url,
  transform:
    transform_item(
      &Map.filter(&1, fn
        {<<"itunes:", _rest::binary>>, _v} -> true
        _ -> false
      end)
    )
    |> collect()
    |> limit(2)
    |> transform()
)
```
<!-- END MODULEDOC -->