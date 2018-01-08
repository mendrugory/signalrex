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
      require Logger
      @behaviour Signalrex

      plug Tesla.Middleware.JSON

      @init_time                    10
      @init_response_attempts       3
      @waiting_for_init_message     1_000
      
      def start_link(args, opts) do
        GenServer.start_link(__MODULE__, args, opts)
      end      

      def init(args) do
        Process.send_after(self(), :init, @init_time)
        {:ok, args}
      end

      def handle_call(_msg, _from, state), do: {:reply, :ok, state}

      def handle_cast(_msg, state), do: {:noreply, state}

      def handle_info(:init, state) do
        new_state = connect(state)
        {:noreply, new_state}
      end

      def handle_info({:signalr_message, data}, state) do
        new_state = 
          case data do
            "{}" ->
              Signalrex.HeartBeat.new_heart_beat(state.heart_beat_pid)
              state
            msg ->  
              case process_message(data, state) do
                {:ok, new_state} ->
                  new_state
                {:error, error} ->
                  state
              end
          end
        {:noreply, new_state}
      end

      def handle_info(_msg, state), do: {:noreply, state}

      defp connect(args) do
        base_url = Map.get(args, :url)
        nh = Map.get(args, :negotiate_headers)
        nqp = Map.get(args, :negotiate_query_params)
        case do_negotiate(base_url, nh, nqp) do
          {:error, error} ->
            Logger.error("Negotiating error: #{error}")
          {:ok, negotiate_result} ->
            ws_opts = Map.get(args, :ws_opts)
            cqp = 
              args
              |> Map.get(:connect_query_params)
              |> Keyword.put(:connection_token, Map.get(negotiate_result, :connection_token))
            args = Map.merge(args, negotiate_result)
            base_ws_url = Map.get(args, :base_ws_url)
            case do_connect(base_ws_url, cqp, ws_opts) do
              {:error, error} ->
                Logger.error("Connecting error: #{error}")
              {:ok, ws_client} ->
                {:ok, heart_beat_pid} = Signalrex.HeartBeat.start_link(negotiate_result, [])
                arguments = Map.put(args, :heart_beat_pid, heart_beat_pid)
                receive_init_response(arguments)
            end
        end
      end

      defp do_negotiate(base_url, headers, query_params) do
        Logger.info("Negotiating ...")
        response = get(negotiate_client(base_url, headers, query_params), "/negotiate")
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

      defp do_connect(base_url, query_params, ws_opts \\ %{conn_mode: :once}) do
        Logger.info("Connecting ...")
        case build_transport_url(base_url, query_params) do
          {:ok, url} -> 
            [
              url: url, 
              extra_headers: Map.get(ws_opts, :extra_headers, []),
              ws_opts: 
                ws_opts
                |> Map.put(:client, self())
                |> Map.put(:init_message, get_initial_message()),
            ]
            |> Signalrex.WSClient.start_link() 
          {:error, error} -> 
            {:error, error}
        end
      end

      defp do_start(base_url, headers, query_params) do
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
        create_client(base_url, headers, start_query_params(query_params))
      end         

      defp create_client(base_url, headers \\ %{}, query_params \\ []) do
        Tesla.build_client([
          {Tesla.Middleware.BaseUrl, base_url},
          {Tesla.Middleware.Headers, Map.merge(default_headers(), headers)},
          {Tesla.Middleware.Query, Keyword.merge(default_query_params(), query_params)}
        ])
      end

      defp build_transport_url(base_url, query_params) do
        final_query_params = connection_query_params(query_params)
        case Keyword.get(final_query_params, :transport) do
          "webSockets" -> 
            encoded_query_params = URI.encode_query(final_query_params)
            {:ok, "#{base_url}/connect?#{encoded_query_params}"} 
          _ -> 
            {:error, "Currently only Websockets are supported by #{__MODULE__}"}
        end
      end

      defp default_headers() do
        %{}
      end

      defp connection_query_params(query_params) do
        do_default_query_params(query_params, false)
      end

      defp start_query_params(query_params) do
        do_default_query_params(query_params, false)
      end

      defp do_default_query_params(query_params, encoded?) do
        default =
          Keyword.merge(
            default_query_params(),
            ["transport": "webSockets"]
          )

        query_params = 
          case Keyword.pop(query_params, :connection_token) do
            {nil, params} -> raise("Connection Token (:connection_token) is mandatory to connect the transport.")
            {ct, params} -> add_query_params(params, [connectionToken: ct], encoded?)
          end

        query_params = 
          case Keyword.pop(query_params, :connection_data) do
            {nil, params} -> params
            {cd, params} -> add_query_params(params, [connectionData: cd], encoded?)
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
        Keyword.merge(
          current,
          Enum.map(new, fn {k, v} -> {k, URI.encode_www_form(v)} end)
        )
      end       
      
      defp receive_init_response(args, attempts \\ @init_response_attempts) do
        receive do 
          {:signalr_message, msg} ->
            case Poison.decode(msg) do
              {:ok, %{"S" => 1, "M" => []}} ->
                base_url = Map.get(args, :url)
                sh = Map.get(args, :start_headers)
                sqp = 
                  Map.get(args, :start_query_params)   
                  |> Keyword.put(:connection_token, Map.get(args, :connection_token))
                do_start(base_url, sh, sqp)
              _ ->
                if attempts > 0 do
                  receive_init_response(args, attempts - 1)
                else
                  Logger.error("No initial reponse arrived in the first #{@init_response_attempts} attempts.")
                end
            end
          after 
            @waiting_for_init_message ->
              Logger.error("The init message has not arrived in #{@waiting_for_init_message} ms.")
        end  
        args      
      end
    
    end  
  end

end
