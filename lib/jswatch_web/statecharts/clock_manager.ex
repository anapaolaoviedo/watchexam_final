defmodule JswatchWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 10)
    Process.send_after(self(), :working_working, 1000)
    {:ok, %{ui_pid: ui, time: time, alarm: alarm, st: Working, indiglo_count: 0}}
  end

  def handle_info(:update_alarm, state) do
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 5)
    {:noreply, %{state | alarm: alarm}}
  end

  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: Working} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    if time == alarm do
      IO.puts("ALARM!!!")
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
    end
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, state |> Map.put(:time, time) }
  end

  def handle_info(_event, state), do: {:noreply, state}
end
