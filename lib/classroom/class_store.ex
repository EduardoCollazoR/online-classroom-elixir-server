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

  def start_class(class_name) do
    GenServer.call(__MODULE__, {:start_class, self(), class_name})
  end

  def get_started_class() do
    GenServer.call(__MODULE__, :get_started_class)
  end

  def get_subscribers(owner, class_name) do
    GenServer.call(__MODULE__, {:get_subscribers, owner, class_name})
  end

  # Server

  # TODO change state format
  def init(classes) do
    # [ %{class_name, owner, subscriber: [], } ]
    {:ok, classes}
  end

  # need class id as diff teacher can hv classes with name
  def handle_call({:create_class, pid, class_name}, _from, classes) do
    {:ok, owner} = Classroom.ActiveUsers.find_user_by_pid(pid)

    case classes
         |> Enum.find(fn %{class_name: name, owner: o} -> name == class_name && o == owner end) do
      nil -> {:reply, :ok, [%{class_name: class_name, owner: owner, subscriber: []} | classes]}
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

    case classes |> Enum.filter(fn %{class_name: _, owner: o} -> o == owner end) do
      [] ->
        {:reply, [], classes}

      list ->
        {:reply, list |> Enum.map(fn x -> x[:class_name] end), classes}
    end
  end

  def handle_call({:get_subscribed_class, pid}, _from, classes) do
    {:ok, user} = Classroom.ActiveUsers.find_user_by_pid(pid)

    {:reply,
     classes
     |> Enum.filter(fn class -> class.subscriber |> Enum.member?(user) end)
     |> Enum.map(fn class -> class |> Map.delete(:subscriber) end),
     classes}
  end

  def handle_call(:get_started_class, _from, classes) do
    {:reply,
      :sys.get_state(:registry)
        |> Map.keys
        |> Enum.map(fn {owner, class_name} -> %{owner: owner, class_name: class_name} end),
      classes
    }
  end

  def handle_call({:start_class, pid, class_name}, _from, classes) do
    {:ok, owner} = Classroom.ActiveUsers.find_user_by_pid(pid)
    case Classroom.ActiveClasses.start_class({owner, class_name}) do
      {:ok, _} ->
        json = %{type: :get_started_class}
        case get_sub(owner, class_name, classes) do
          [] ->
            nil
          sub ->
            # Classroom.ClassStore.get_subscribers(owner, class_name)
            sub
              |> Enum.map(fn u -> Classroom.ActiveUsers.find_pid_by_user(u) end)
              |> Enum.filter(&match?({:ok, _}, &1))
              |> Enum.map(fn {_, pid} -> send pid, json end)
        end
        {:reply, :ok, classes}
      _ ->
        {:reply, :error, classes}
    end
  end

  def handle_call({:get_subscribers, owner, class_name}, _from, classes) do
    {:reply, get_sub(owner, class_name, classes), classes}
  end

  defp get_sub(owner, class_name, classes) do
    case classes |> Enum.find(fn c -> c.owner == owner and c.class_name == class_name end) do
      nil ->
        []
      class ->
        class.subscriber
    end
  end

  defp update_classroom(classes, name, owner, task) do
    Enum.map(classes, fn
      class = %{class_name: ^name, owner: ^owner} -> task.(class)
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
