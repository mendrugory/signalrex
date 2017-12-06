defmodule Signalrex do
  use GenServer
  @moduledoc """
  Documentation for Signalrex.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Signalrex.hello
      :world

  """

  @type state :: any
  @type data :: any
  @type error :: any

  @callback get_initial_message() :: binary
  @callback process_message(data, state) :: {:ok, state} | {:error, error}

  defmacro __using__(_) do
    quote location: :keep do
      use Tesla
      @behaviour Signalrex

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, [])
      end

      def init(args) do
        {:ok, args}
      end

      def handle_cast({:message, message}, _from, state) do
        case message
      end

      def handle_info({:signalr_message, data}, state) do
        case process_message(data, state) do
          {:ok, new_state} ->
            {:noreply, new_state}
          {:error, error} ->
            {:noreply, state}
        end
      end

      defp negotiate(base_url, headers, query_params) do
        Logger.info("Negotiating ...")
        response = get(negotiate_client(base_url), "/negotiate")
        if response.body["TryWebSockets"] do
          {
            :ok,
            %{
              connection_token: response.body["ConnectionToken"],
              connection_id: response.body["ConnectionId"],
              keep_alive_timeout: response.body["KeepAliveTimeout"],
              disconnect_timeout: response.body["DisconnectTimeout"],
              transport_connect_timeout: response.body["TransportConnectTimeout"],
              connection_timeout: response.body["ConnectionTimeout"]
            }
          }
        else
          {:error, "Websockets are not supported by the Server."}
        end
      end

      defp connect(base_url, query_params, ws_opts \\ %{conn_mode: :once}) do
        Logger.info("Connecting ...")
        case build_transport_url(base_url, query_params) do
          {:ok, url} -> 
            [
              url: url, 
              ws_opts: ws_opts, 
              init_message: get_initial_message(),
              client: self()
            ]
            |> WSClient.start_link() 
          {:error, error} -> 
            {:error, error}
        end
      end

      defp start(base_url, headers, query_params) do
        Logger.info("Starting ...")
        response = get(start_client(base_url, headers, query_params), "/start")
        case response.body do
          %{"Response" => "started"} ->
            Logger.info("Connection started.")
          msg ->
            Logger.error("Error: #{inspect msg}")
        end
      end

      defp negotiate_client(base_url, headers, query_params) do
        create_client(base_url, headers, query_params)
      end 

      defp start_client(base_url, headers, query_params) do
        create_client(base_url, headers, query_params)
      end       

      defp start_client(base_url, headers, query_params) do
        create_client(base_url, headers, start_query_params(query_params))
      end         

      defp create_client(base_url, headers \\ %{}, query_params \\ []) do
        Tesla.build_client([
          {Tesla.Middleware.BaseUrl, base_url},
          {Tesla.Middleware.JSON},
          {Tesla.Middleware.Headers, Keyword.merge(default_headers(), headers)},
          {Tesla.Middleware.Query, Keyword.merge(default_query_params(), query_params)}
        ])
      end

      defp build_transport_url(base_url, query_params) do
        final_query_params = default_connection_query_params(query_params)
        case Keyword.get(final_query_params, :transport) do
          "webSockets" -> 
            encoded_query_params = URI.encode_query(final_query_params)
            {:ok, "#{base_url}?#{encoded_query_params}"} 
          _ -> 
            {:error, "Currently only Websockets are supported by #{__MODULE__}"}
        end
      end

      defp default_headers() do
        %{}
      end

      defp default_connection_query_params(query_params) do
        default = Keyword.merge(default_query_params(), [transport: "webSockets"])
        
        query_params = 
          case Keyword.pop(query_params, :connection_token) do
            {nil, params} -> raise("Connection Token (:connection_token) is mandatory to connect the transport.")
            {ct, params} -> add_query_params(params, ["connectionToken": ct], true)
          end

        query_params = 
          case Keyword.pop(query_params, :connection_data) do
            {nil, params} -> params
            {cd, params} -> add_query_params(params, ["connectionData": Poison.encode!(ct)], true)
          end          

        Keyword.merge(default, query_params) 
      end

      defp start_query_params(query_params) do
        default =
          Keyword.merge(
            default_query_params(),
            ["transport": "webSockets"]
          )

        query_params = 
          case Keyword.pop(query_params, :connection_token) do
            {nil, params} -> raise("Connection Token (:connection_token) is mandatory to connect the transport.")
            {ct, params} -> add_query_params(params, ["connectionToken": ct], false)
          end

        query_params = 
          case Keyword.pop(query_params, :connection_data) do
            {nil, params} -> params
            {cd, params} -> add_query_params(params, ["connectionData": Poison.encode!(ct)], false)
          end          

        Keyword.merge(default, query_params)           
        
      end

      defp default_query_params() do
        ["clientProtocol": 1.5]
      end      

      defp add_query_params(current, new, encoded? \\ false)

      defp add_query_params(current, new, false) when is_list(new) do
        Keyword.merge(current, new)
      end
      
      defp add_query_params(current, new, true) when is_list(new) do
        Enum.map(
          new,
          fn {k, v} -> 
            Keyword.put(k, URI.encode_www_form(v))
          end
        )
      end     
    
    end  
  end
end
