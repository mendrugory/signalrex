defmodule WSClient do
  use Enchufeweb

  require Logger

  def handle_message(data, state) do 
    pid = Keyword.get(state, :client)
    send(pid, {:signalr_message, data})
    {:ok, state}
  end
  
  def handle_connection(_, state) do 
    Logger.info("Connecting #{state.message}")
    init_message = Keyword.get(state, :init_message, " ")
    {:reply, init_message, state}
  end

  def handle_disconnection(_, state), do: {:close, "end", state}
end