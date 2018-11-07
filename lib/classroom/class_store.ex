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

  def subscribe(name_of_class) do
    GenServer.call(__MODULE__, {:subscribe, name_of_class})
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
    # %{ "teacher": %{created_class: [class_name,],} }
    # [ %{name_of_class, owner, subscriber: []} ]
    {:ok, classes}
  end

  # def handle_call({:old_created_class, pid, name_of_class}, _from, classes) do # not in list with same teacher
  #   # Map put(info, :room_id, Ecto.UUID.generate())
  #   {:ok, owner} =  Classroom.ActiveUsers.find_user_by_pid(pid)
  #   case classes[owner] do
  #     nil -> {:reply, :ok, classes |> Map.put(owner, [name_of_class])}
  #     list ->
  #       case list |> Enum.member?(name_of_class) do
  #         true -> {:reply, :error, classes}
  #         false ->
  #           {:reply, :ok, classes |> Map.replace!(owner, [name_of_class | list])}
  #       end
  #   end
  # end

  def handle_call({:create_class, pid, name_of_class}, _from, classes) do # need class id as diff teacher can hv classes with name
    {:ok, owner} =  Classroom.ActiveUsers.find_user_by_pid(pid)
    IO.inspect classes |> Enum.find(fn %{name: name, owner: o} -> name == name_of_class and o == owner end)
    case classes |> Enum.find(fn %{name: name, owner: o} -> name == name_of_class && o == owner end) do
      nil -> {:reply, :ok, [%{name: name_of_class, owner: owner, subscriber: []} | classes]}
      _ -> {:reply, :error, classes}
    end
  end

  def handle_call({:subscribe, %{:room_id => room_id}}, _from, classes) do # require teacher's & class's name
    case classes |> Enum.find(fn {_, val} -> val == room_id end) do
      # TODO change user's location
      {_, _} -> {:reply, :ok, classes}
      nil -> {:reply, :error, classes}
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
