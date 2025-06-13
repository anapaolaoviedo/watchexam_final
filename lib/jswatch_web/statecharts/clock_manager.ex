defmodule JswatchWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 10)
    Process.send_after(self(), :working_working, 1000)
    {:ok, %{ui_pid: ui, time: time, alarm: alarm, st: Working, indiglo_count: 0, snooze_timer: nil }}
  end

  def handle_info(:update_alarm, state) do
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 5)
    {:noreply, %{state | alarm: alarm}}
  end

   def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: :working} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    if time == alarm do
      IO.puts("ALARM!!!")
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
      GenServer.cast(ui, :set_indiglo)
      Process.send_after(self(), :toggle_indiglo, 500)
      state =
        state
        |> Map.put(:st, :alarm_on)
        |> Map.put(:indiglo_count, 0)
        |> Map.put(:time, time)
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
      {:noreply, state}
    else
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
      {:noreply, %{state | time: time}}
    end
  end


    # ticking even in alarmoff state
  def handle_info(:working_working, %{ui_pid: ui, time: time, st: :alarm_off} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    {:noreply, %{state | time: time}}
  end


   def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: :snooze_on} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)

    # Check if snooze alarm should trigger again
    if time == alarm do
      IO.puts("SNOOZE ALARM TRIGGERED AGAIN!")
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
      GenServer.cast(ui, :set_indiglo)
      Process.send_after(self(), :toggle_indiglo, 500)
      state = %{state | st: :alarm_on, indiglo_count: 0, time: time}
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
      {:noreply, state}
    else
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
      {:noreply, %{state | time: time}}
    end
  end

end
