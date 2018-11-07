# defmodule Classroom.Class do
#   use GenServer
#   import Logger
#
#   def start_link(_args) do
#     GenServer.start_link(__MODULE__, self(), name: __MODULE__)
#   end
#
#   def join(class, user_name) do
#     GenServer.call(class, {:join, self(), user_name})
#   end
#
#   def leave(class) do
#     GenServer.call(class, {:leave, self()})
#   end
#
#   def change(class) do
#     GenServer.call(class, {:change, self()})
#   end
#
#   def register(class) do
#     GenServer.call(class, {:register, self()})
#   end
#
#   def unregister(class) do
#     GenServer.call(class, {:unregister, self()})
#   end
#
#   def init(owner, room_id) do
#     {:ok, %{clients: %{}, whiteboards: [], owner: owner, room_id: room_id}}
#   end
#
#   def handle_call({:join, pid, :guest, room_id, user_data}, _from, state = %{room_id: id}) do
#     Process.monitor(pid)
#     case state.room_id do
#       nil -> {:reply, :error, state}
#       room_id ->
#         if room_id == id do
#           {:reply, :ok, state.clients |> Map.put_new(pid, ))}
#         else
#           {:reply, :error, state}
#         end
#     end
#   end
#
#   def handle_info({:DOWN, _ref, :process, pid, _reason}, users) do
#     {:noreply, users} # same as above
#   end
#
#   def handle_call({:connect, pid}, _from, state) do
#     {:reply, state.lines, Map.update!(state, :clients, fn clients -> [pid | clients] end)}
#   end
#
#   def handle_call({:disconnect, pid}, _from, state) do
#     {:reply, :ok, Map.update!(state, :clients, fn clients -> List.delete(clients, pid) end)}
#   end
#
#   def handle_cast({:draw, owner_pid, line}, state = %{owner: owner_pid}) do
#     Enum.each(state.clients, fn client -> send(client, {:update, line}) end)
#     {:noreply, Map.update!(state, :lines, fn lines -> [line | lines] end)}
#   end
#
#   def handle_cast({:draw, _, _}, state) do
#     {:noreply, state}
#   end
# end
