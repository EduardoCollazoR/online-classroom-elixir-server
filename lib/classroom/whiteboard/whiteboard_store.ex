defmodule Classroom.WhiteboardStore do
  use GenServer

  def start_link(args) do
    # , debug: [:trace])
    whiteboards = Keyword.get(args, :whiteboards, %{})
    GenServer.start_link(__MODULE__, whiteboards, name: __MODULE__)
  end

  def created(id) do
    GenServer.call(__MODULE__, {:create, self(), id})
  end

  def destroy() do
    GenServer.call(__MODULE__, {:destroy, self()})
  end

  def start(id) do
    GenServer.call(__MODULE__, {:start, self(), id})
  end

  def get_created() do
    GenServer.call(__MODULE__, {:get_created, self()})
  end

  def get_started() do
    GenServer.call(__MODULE__, :get_started)
  end

  # Server

  # TODO change state format
  def init(whiteboards) do
    # [ %{id, owner, subscriber: [], } ]
    {:ok, whiteboards}
  end

  # need whiteboard id as diff teacher can hv whiteboards with name
  # def handle_call({:create, pid, id}, _from, whiteboards) do
  #   {:ok, owner} = Classroom.ActiveUsers.find_user_by_pid(pid)

  #   case whiteboards
  #        |> Enum.find(fn %{id: name, owner: o} -> name == owner end) do
  #     nil -> {:reply, :ok, [%{id: id, owner: owner} | whiteboards]}
  #     _ -> {:reply, [:error, :whiteboard_already_exist], whiteboards}
  #   end
  # end

  # def handle_call({:get_created, pid}, _from, whiteboards) do
  #   {:ok, owner} = Classroom.ActiveUsers.find_user_by_pid(pid)

  #   case whiteboards |> Enum.filter(fn %{id: _, owner: o} -> o == owner end) do
  #     [] ->
  #       {:reply, [], whiteboards}

  #     list ->
  #       {:reply, list |> Enum.map(fn x -> x[:id] end), whiteboards}
  #   end
  # end

  # def handle_call(:get_started, _from, whiteboards) do
  #   {:reply,
  #     :sys.get_state(:whiteboard_registry)
  #       |> Map.keys
  #       |> Enum.map(fn {owner, id} -> %{owner: owner, id: id} end),
  #     whiteboards
  #   }
  # end

  # def handle_call({:start, pid, target}, _from, whiteboards) do
  #   {:ok, target} = Classroom.ActiveUsers.find_user_by_pid(pid)
  #   case Classroom.ActiveWhiteboard.start({target}) do
  #     {:ok, _} ->
  #       {:reply, :ok, whiteboards}

  #     _ ->
  #       {:reply, :error, whiteboards}
  #   end
  # end

end
