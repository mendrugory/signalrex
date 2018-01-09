# Signalrex

Under development.

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

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/signalrex](https://hexdocs.pm/signalrex).

## Running

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



defmodule Test do
	use Signalrex

	def get_initial_message() do
	  %{"S" => 0, "M" => [], "C" => ""} |> Poison.encode!
	end

	def process_message(data, state) do
		IO.inspect data
		{:ok, state}
	end

end


Test.start_link args, []
```

Send new Websockets message, reusing same client:

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



defmodule Test do
	use Signalrex

	def get_initial_message() do
	  %{"S" => 0, "M" => [], "C" => ""} |> Poison.encode!
	end

	def process_message(data, state) do
		IO.inspect data
		Signalrex.WSClient.ws_send(
			state.ws_client_pid,
			%{
				"H" => "YourHub",
				"M" => "YourMethod",
				"A" => ["arg1", "arg2"]
			} |> Poison.encode!
		)
		{:ok, state}
	end

end


Test.start_link args, []
```
