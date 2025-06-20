defmodule JswatchWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 10)
    Process.send_after(self(), :working_working, 1000)
    IO.puts("ClockManager initialized with PID: #{inspect(self())}")
    {:ok, %{ui_pid: ui,time: time,alarm: alarm,st: :working,indiglo_count: 0,snooze_timer: nil}}
  end


  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: :working} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    if time == alarm do
      IO.puts("ALARM!!! - State changed to :alarm_on")
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


  def handle_info(:working_working, %{ui_pid: ui, time: time, st: :alarm_off} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    {:noreply, %{state | time: time}}
  end


  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: :snooze_on} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)


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


  def handle_info(:working_working, state) do
    Process.send_after(self(), :working_working, 1000)
    {:noreply, state}
  end


  def handle_info(:toggle_indiglo, %{ui_pid: ui, st: :alarm_on, indiglo_count: count} = state) do
    if rem(count, 2) == 0 do
      GenServer.cast(ui, :set_indiglo)
    else
      GenServer.cast(ui, :unset_indiglo)
    end
    Process.send_after(self(), :toggle_indiglo, 500)
    {:noreply, %{state | indiglo_count: count + 1}}
  end


  def handle_info(:toggle_indiglo, state), do: {:noreply, state}

  # Button press triggers snooze timer
  def handle_info(:bottom_right_pressed, %{st: :alarm_on} = state) do
    IO.puts(" BOTTOM RIGHT BUTTON PRESSED! State: #{state.st}")
    GenServer.cast(state.ui_pid, :unset_indiglo)
    snooze_timer = Process.send_after(self(), :activate_snooze, 2000)
    IO.puts(" Transitioning to :pre_snooze state")
    {:noreply, %{state | st: :pre_snooze, snooze_timer: snooze_timer}}
  end


  def handle_info(:bottom_right_released, %{st: :pre_snooze, snooze_timer: ref} = state)
      when ref != nil do
    Process.cancel_timer(ref)
    IO.puts(" Button released before 2s. Alarm canceled.")
    {:noreply, %{state | st: :alarm_off, snooze_timer: nil}}
  end

  # 2 SEC WAIT
  def handle_info(:activate_snooze, %{st: :pre_snooze, ui_pid: ui} = state) do
    IO.puts("Snooze activated! Alarm will ring again in 5 seconds.")
    GenServer.cast(ui, :unset_indiglo)
    send(self(), :update_alarm)
    {:noreply, %{state | st: :snooze_on, snooze_timer: nil}}
  end

  # IS IT?????
  def handle_info(:bottom_right_pressed, %{st: :snooze_on} = state) do
    IO.puts("Alarm completely turned off from snooze.")
    {:noreply, %{state | st: :alarm_off}}
  end

  # Update alarm time  FOR SNOOOZZEEE!!!!
  def handle_info(:update_alarm, %{time: current_time} = state) do
    alarm = Time.add(current_time, 5)
    IO.puts("Alarm updated to: #{Time.to_string(alarm)}")
    {:noreply, %{state | alarm: alarm}}
  end

  # ADD DEBUG FOR ALL UI EVENTS
  def handle_info(event, state) when is_atom(event) do
    IO.puts("RECEIVED UI EVENT: #{event} | Current state: #{state.st}")
    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
