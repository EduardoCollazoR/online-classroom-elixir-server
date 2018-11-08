defmodule Classroom.ClassStore do
  use GenServer

  def start_link(args) do
    # , debug: [:trace])
    classes = Keyword.get(args, :classes, %{})
    GenServer.start_link(__MODULE__, classes, name: __MODULE__)
  end

  def created_class(name_of_class) do
    GenServer.call(__MODULE__, {:create_class, self(), name_of_class})
  end

  def destroy_class() do
    GenServer.call(__MODULE__, {:destroy_class, self()})
  end

  def subscribe(owner, name_of_class) do
    GenServer.call(__MODULE__, {:subscribe, self(), owner, name_of_class})
  end

  def unsubscribe(name_of_class) do
    GenServer.call(__MODULE__, {:unsubscribe, name_of_class})
  end

  def get_created_class() do
    GenServer.call(__MODULE__, {:get_created_class, self()})
  end

  def get_subscribed_class() do
    GenServer.call(__MODULE__, :get_subscribed_class)
  end

  def init(classes) do # TODO change state format
    # [ %{name_of_class, owner, subscriber: []} ]
    {:ok, classes}
  end

  def handle_call({:create_class, pid, name_of_class}, _from, classes) do # need class id as diff teacher can hv classes with name
    {:ok, owner} =  Classroom.ActiveUsers.find_user_by_pid(pid)
    case classes |> Enum.find(fn %{name: name, owner: o} -> name == name_of_class && o == owner end) do
      nil -> {:reply, :ok, [%{name: name_of_class, owner: owner, subscriber: []} | classes]}
      _ -> {:reply, :error, classes}
    end
  end

  def handle_call({:subscribe, pid, owner, class_name}, _from, classes) do # TODO owner cannot subscribe
    case classes |> Enum.find(fn %{name: name, owner: o} -> name == class_name && o == owner end) do
      # TODO change user's location
      nil -> {:reply, :error, classes}
      _ ->
        {:ok, subscriber} =  Classroom.ActiveUsers.find_user_by_pid(pid)
        {:reply,
          :ok,
          classes |> Enum.map(fn class ->
            Map.update!(class, :subscriber, fn list -> [ subscriber | list] end)
          end)
        }
    end
  end

  def handle_call({:unsubscribe, pid}, _from, {conns, classes}) do
    {:reply, :ok, {conns, List.delete(classes, pid)}}
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

  def handle_call(:get_subscribed_class, _from, classes) do
    {:reply, classes, classes}
  end

end
