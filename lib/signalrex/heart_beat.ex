defmodule Signalrex.HeartBeat do
  use GenServer

  require Logger

  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def new_heart_beat(pid), do: GenServer.cast(pid, :heart_beat)

  def init(args) do
    IO.inspect args
    Process.send_after(self(), :loop, time_out_millis(args.keep_alive_timeout))
    {:ok, Map.put(args, :heart_beat, false)}
  end

  def handle_cast(:heart_beat, state), do: {:noreply, %{state | heart_beat: true}}

  def handle_cast(_msg, state), do: {:noreply, state}

  def handle_info(:loop, %{heart_beat: heart_beat, keep_alive_timeout: keep_alive_timeout}=state) do
    if heart_beat do
      IO.puts "Heart beat: #{Time.utc_now()}"
      Process.send_after(self(), :loop, time_out_millis(keep_alive_timeout))
      {:noreply, %{state | heart_beat: false}}
    else
      Logger.error("No heart beat has been received.")
      {:stop, :killed, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp time_out_millis(t), do: round(t * 1_000)
end