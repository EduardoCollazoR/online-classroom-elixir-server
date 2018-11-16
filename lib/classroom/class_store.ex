defmodule Classroom.ClassStore do
  use GenServer

  def start_link(args) do
    # , debug: [:trace])
    classes = Keyword.get(args, :classes, %{})
    GenServer.start_link(__MODULE__, classes, name: __MODULE__)
  end

  def created_class(class_name) do
    GenServer.call(__MODULE__, {:create_class, self(), class_name})
  end

  def destroy_class() do
    GenServer.call(__MODULE__, {:destroy_class, self()})
  end

  def subscribe(owner, class_name) do
    GenServer.call(__MODULE__, {:subscribe, self(), owner, class_name})
  end

  def subscribe(owner, class_name, self) do
    GenServer.call(__MODULE__, {:subscribe, self, owner, class_name})
  end

  def unsubscribe(owner, class_name) do
    GenServer.call(__MODULE__, {:unsubscribe, self(), owner, class_name})
  end

  def get_created_class() do
    GenServer.call(__MODULE__, {:get_created_class, self()})
  end

  def get_subscribed_class() do
    GenServer.call(__MODULE__, {:get_subscribed_class, self()})
  end

  # TODO change state format
  def init(classes) do
    # [ %{class_name, owner, subscriber: [], } ]
    {:ok, classes}
  end

  # need class id as diff teacher can hv classes with name
  def handle_call({:create_class, pid, class_name}, _from, classes) do
    {:ok, owner} = Classroom.ActiveUsers.find_user_by_pid(pid)

    case classes
         |> Enum.find(fn %{name: name, owner: o} -> name == class_name && o == owner end) do
      nil -> {:reply, :ok, [%{name: class_name, owner: owner, subscriber: []} | classes]}
      _ -> {:reply, :error, classes}
    end
  end

  # TODO cannot re-sub
  def handle_call({:subscribe, pid, owner, name}, _from, classes) do
    {_, subscriber} = Classroom.ActiveUsers.find_user_by_pid(pid)
    new_state = update_classroom(classes, name, owner, &add_subscriber(&1, subscriber))

    case classes == new_state do
      false -> {:reply, :ok, new_state}
      true -> {:reply, :error, classes}
    end
  end

  def handle_call({:unsubscribe, pid, owner, name}, _from, classes) do
    {_, subscriber} = Classroom.ActiveUsers.find_user_by_pid(pid)

    new_state = update_classroom(classes, name, owner, &delete_subscriber(&1, subscriber))
    case classes == new_state do
      false -> {:reply, :ok, new_state}
      true -> {:reply, :error, classes}
    end
  end

  def handle_call({:get_created_class, pid}, _from, classes) do
    {:ok, owner} = Classroom.ActiveUsers.find_user_by_pid(pid)

    case classes |> Enum.filter(fn %{name: _, owner: o} -> o == owner end) do
      [] ->
        {:reply, [], classes}

      list ->
        {:reply, list |> Enum.map(fn x -> x[:name] end), classes}
    end
  end

  def handle_call({:get_subscribed_class, pid}, _from, classes) do
    {:ok, user} = Classroom.ActiveUsers.find_user_by_pid(pid)

    {:reply,
     classes
     |> Enum.filter(fn class -> class.subscriber |> Enum.member?(user) end)
     |> Enum.map(fn class -> class |> Map.delete(:subscriber) end), classes}
  end

  defp update_classroom(classes, name, owner, task) do
    Enum.map(classes, fn
      class = %{name: ^name, owner: ^owner} -> task.(class)
      class -> class
    end)
  end

  defp add_subscriber(class, subscriber) do
    Map.update!(class, :subscriber, fn l ->
      if !Enum.member?(l, subscriber) do
        [subscriber | l]
      else
        l
      end
    end)
  end

  defp delete_subscriber(class, subscriber) do
    Map.update!(class, :subscriber, fn l ->
      if Enum.member?(l, subscriber) do
        l |> List.delete(subscriber)
      else
        l
      end
    end)
  end
end
