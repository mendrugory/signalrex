# Signalrex

`Signalrex` is a library writen in Elixir which will help you to interact with servers which implements [SignalR](https://www.asp.net/signalr). You can find more information in their [web](https://www.asp.net/signalr).

`Signalrex` only supports WebSockets as transport protocol using `Enchufeweb`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `signalrex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:signalrex, "~> 0.1.0"}
  ]
end
```

## Implementation

Define your Module, use `Signalrex` and implement the functions _get_initial_message/0_ (The first message that will be sent to the server) and _process_message/2_ (The function that will be called when a message arrived from the server)

```elixir
defmodule Test do
  use Signalrex

  def get_initial_message() do
    %{"S" => 0, "M" => [], "C" => ""}
  end

  def process_message(data, state) do
    IO.inspect data
    {:ok, state}
  end
end
```

## Start

`Signalrex` needs some mandatory arguments to work:

* url: A string with the signalR server url.
* negotiate_headers: A map with the additional headers of the negotiate request (it could be empty).
* negotiate_query_params: A keyword list with the additional parameters of the negotiate request (it could be empty).
* ws_opts: A map with the options for the websocket.
* connect_query_params: A keyword list with the additional parameters of the websocket connection request.
* base_ws_url: A string with the websocket server url.
* start_headers: A map with the additional headers of the start request (it could be empty).
* start_query_params: A keyword list with the additional parameters of the start request (it could be empty).

### Example

```elixir
args = %{
  url: "http://9.5.6.7:5555/signalr",
  negotiate_headers: %{},
  negotiate_query_params: ["my_auth": "asdfasdf", "connectionData": "[{\"id\":\"my_data\"}]"],
  ws_opts: %{conn_mode: :once},
  connect_query_params: ["my_auth": "asdfasdf", "connectionData": "[{\"id\":\"my_data\"}]"],
  base_ws_url: "ws://9.5.6.7:5555/signalr",
  start_headers: %{},
  start_query_params: ["my_auth": "asdfasdf", "connectionData": "[{\"id\":\"my_data\"}]"]
  }
```

After having your arguments, you only have to start your process:

```elixir
{:ok, signalrex} = Test.start_link(args, [])
```

## Sending data

```elixir
Test.send(_your_signalrex_process_, _your_message_)
```

## Docs
```bash
$ mix docs
```

## Tests
Looking for a public SignalR server in order to publish test against it.