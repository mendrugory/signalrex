defmodule Signalrex.WSClient do
  @moduledoc false
  
  use Enchufeweb
  require Logger

  def handle_message(data, state) do 
    pid = Keyword.get(state, :ws_opts).client
    send(pid, {:signalr_message, data})
    {:ok, state}
  end
  
  def handle_connection(_, state) do 
    {:ok, init_message} = Map.get(Keyword.get(state, :ws_opts), :init_message, " ")
    {:reply, init_message, state}
  end

  def handle_disconnection(_, state), do: {:close, "end", state}
end
