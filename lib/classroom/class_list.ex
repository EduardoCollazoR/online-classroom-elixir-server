defmodule Classroom.ClassList do
  use GenServer
  import Logger
  # import Ecto

  def start_link(_args) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, self(), name: __MODULE__)
  end

  def subscribe(data) do
    GenServer.call(__MODULE__, {:subscribe, data})
  end

  def unsubscribe() do
    GenServer.cast(__MODULE__, {:unsubscribe, self()})
  end

  def created_class() do
    GenServer.call(__MODULE__, :created_class)
  end

  def get_created_class() do
    GenServer.call(__MODULE__, :get_created_class)
  end

  def get_subscribed_class() do
    GenServer.call(__MODULE__, :get_subscribed_class)
  end

  def init(_) do
    Logger.debug("ClassList pid: #{inspect(self())}")
    # %{ pid1 => %{logged_in?: false}, pid2 => %{} }
    {:ok, %{}}
  end

  def handle_call({:subscribe, %{:room_id => room_id}}, _from, classes) do
    case classes |> Enum.find(fn {key, val} -> val == room_id end) do
      # TODO change user's location
      {_, _} -> {:reply, :ok, classes}
      nil -> {:reply, :error, classes}
    end
  end

  def handle_cast({:unsubscribe, pid}, {conns, classes}) do
    {:noreply, {conns, List.delete(classes, pid)}}
  end

  # TODO :user -> :teacher
  def handle_call(:created_class, %{:name => name, :info => info}, :user, _from, classes) do
    Map.put(info, :room_id, Ecto.UUID.generate())

    case Map.fetch(classes, name) do
      # need data validation
      :error -> {:reply, :ok, Map.put(classes, name, info)}
      {:ok, _} -> {:reply, :error, classes}
    end
  end

  def handle_call(:get_created_class, _from, classes) do
    {:reply, classes, classes}
  end

  def handle_call(:get_subscribed_class, _from, classes) do
    {:reply, classes, classes}
  end

  def handle_call(msg, _from, classes) do
    Logger.debug("ClassList: Unexpected action: #{msg}")
    {:reply, :error, classes}
  end
end
