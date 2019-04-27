defmodule Classroom.Class do
  use GenServer

  require Logger

  # API

  def start_link({owner, class_name}) do
    # , debug: [:trace])
    GenServer.start_link(__MODULE__, [{owner, class_name}], name: via_tuple(owner, class_name))
  end

  def join(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), {:join, self()})
  end

  def leave(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), {:leave, self()})
  end

  def get_session_user(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), :get_session_user)
  end

  def handle_class_direct_message(owner, class_name, message) do
    GenServer.call(via_tuple(owner, class_name), {:handle_class_direct_message, message, self()})
  end

  def handle_request_offer(owner, class_name, to) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_request_offer, to, self()}
    )
  end

  def handle_offer(owner, class_name, stream_owner, offer, to) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_offer, stream_owner, offer, to, self()}
    )
  end

  def handle_answer(owner, class_name, stream_owner, answer, to) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_answer, stream_owner, answer, to, self()}
    )
  end

  def handle_got_media(owner, class_name) do
    GenServer.call(
      via_tuple(owner, class_name),
      {:handle_got_media, self()}
    )
  end

  def handle_candidate(owner, class_name, stream_owner, candidate, to) do
    GenServer.call(via_tuple(owner, class_name), {:handle_candidate, stream_owner, candidate, to, self()})
  end

  def handle_action(owner, class_name, action) do
    GenServer.call(via_tuple(owner, class_name), {:handle_action, action, self()})
  end

  # def add_group(owner, class_name, group_id) do
  #   GenServer.call(via_tuple(owner, class_name), {:add_group, group_id})
  # end

  def change_group(owner, class_name, student, group) do
    GenServer.call(via_tuple(owner, class_name), {:change_group, student, group})
  end

  def get_groups(owner, class_name) do
    GenServer.call(via_tuple(owner, class_name), :get_groups)
  end

  def change_webcam_permission(owner, class_name, user, webcamPermission) do
    GenServer.call(via_tuple(owner, class_name), {:change_webcam_permission, user, webcamPermission})
  end

  defp via_tuple(owner, class_name) do
    # {:via, module_name, term}
    {:via, Classroom.ActiveClasses.Registry, {owner, class_name}}
  end

  # Server

  def init(args) do
    [{owner, class_name}] = args
    # %{ users => %{pid => %{pc: false, self_name: self_name, ref: ref, mic: true, camera: true}},
    #              group => [%{students: [], whiteboard_id: }]}

    {:ok, _} = Classroom.ActiveGroupWhiteboard.start({owner, class_name, "Group1"})
    {:ok, _} = Classroom.ActiveGroupWhiteboard.start({owner, class_name, "Group2"})
    {:ok, _} = Classroom.ActiveGroupWhiteboard.start({owner, class_name, "Group3"})

    [] = Classroom.GroupWhiteboard.connect(owner, class_name, "Group1")
    [] = Classroom.GroupWhiteboard.connect(owner, class_name, "Group2")
    [] = Classroom.GroupWhiteboard.connect(owner, class_name, "Group3")

    {:ok, %{users: %{}, groups: []}}
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    leave_class(pid, state)
    # {:noreply, Map.delete(state, pid)}
    {:noreply, remove_user_from_state(state, pid)}
  end

  def handle_call({:leave, pid}, _from, state) do
    leave_class(pid, state)
    %{ref: ref} = state |> Map.fetch!(:users) |> Map.fetch!(pid)
    Process.demonitor(ref)
    # {:reply, :ok, Map.delete(state, pid)}
    {:reply, :ok, remove_user_from_state(state, pid)}
  end

  def handle_call({:join, pid}, _from, state) do
    case state |> Map.fetch!(:users) |> Map.has_key?(pid) do
      true ->
        {:reply, [:reject, :already_joined], state}

      false ->
        ref = Process.monitor(pid)
        {:ok, self_name} = Classroom.ActiveUsers.find_user_by_pid(pid)
        {_, new_state} =
          Kernel.get_and_update_in(state, [:users, pid],
            &{&1, %{pc: false, self_name: self_name, ref: ref, mic: true, camera: true, group: nil}}
          )
          # Map.put(state, pid,
          #   %{pc: false, self_name: self_name, ref: ref, mic: true, camera: true}
          # )

        send(pid, [:signaling, [:update_exist_peer_conn, get_exist_peer_conn(new_state)]])

        update_class_state_to_clients(new_state)

        # broadcast_to_pc_ready(new_state, pid)

        {:reply, :ok, new_state}
    end
  end

  def handle_call(:get_session_user, _from, state) do
    {:reply,
     state
     |> Map.get(:users)
     |> Map.keys()
     |> Enum.map(fn pid ->
        {_, user} = Classroom.ActiveUsers.find_user_by_pid(pid)
        user
      end),
    state}
  end

  # Signaling

  def handle_call({:handle_got_media, sender_pid}, _from, state) do
    {:ok, stream_owner} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)
    new_state = update_pc_in_state(sender_pid, state)

    new_state
    |> Map.get(:users)
    |> Map.keys()
    |> Enum.filter(fn pid -> pid != sender_pid end) # broadcast to all besides sender
    |> Enum.map(fn pid -> send(
        pid,
        [:signaling, [
          :got_media,
          stream_owner #owner
        ]]
      ) end)

    {:reply, :ok, new_state}
  end

  def handle_call({:handle_class_direct_message, message, sender_pid}, _from, state) do
    if message["type"] in ["offer", "answer", "candidate", "request_offer"] do
      {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(message["to"])
      {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

      send(target, %{
        type: :broadcast_message,
        message: Map.put(message, "from", sender_name),
        DEBUG: :handle_class_direct_message
      })

      {:reply, :ok, state}
    end
  end

  def handle_call({:handle_request_offer, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :request_offer,
        sender_name
    ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_offer, stream_owner, offer, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)
    mic = state[:users][sender_pid][:mic]
    camera = state[:users][sender_pid][:camera]

    send(target, [
      :signaling, [
        :offer,
        stream_owner,
        offer,
        sender_name,
        [mic, camera]
    ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_answer, stream_owner, answer, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :answer,
        stream_owner,
        answer,
        sender_name
    ]])

    {:reply, :ok, state}
  end

  def handle_call({:handle_candidate, stream_owner, candidate, to, sender_pid}, _from, state) do
    {:ok, target} = Classroom.ActiveUsers.find_pid_by_user(to)
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    send(target, [
      :signaling, [
        :candidate,
        stream_owner,
        candidate,
        sender_name
      ]])

    {:reply, :ok, state}
  end

  # hangup, toggleMic, toggleCamera
  def handle_call({:handle_action, action, sender_pid}, _from, state) do
    {:ok, sender_name} = Classroom.ActiveUsers.find_user_by_pid(sender_pid)

    broadcast_except_sender(state, sender_pid, [
      :signaling, [
        :action,
        action,
        sender_name
    ]])

    case action do
      "hangup" ->
        {:reply, :ok, update_pc_in_state(sender_pid, state)}
      "toggleCamera" ->
        {:reply, :ok, Kernel.update_in(state, [:users, sender_pid, :camera], &(!&1))}
      "toggleMic" ->
        {:reply, :ok, Kernel.update_in(state, [:users, sender_pid, :mic], &(!&1))}
    end
  end

  def handle_call({:change_group, student, group}, _from, state) do
    {:ok, s_pid} = Classroom.ActiveUsers.find_pid_by_user(student)
    originalGroup = state.users[s_pid].group

    new_state =
      case group do
        "All" ->
          new_s = put_in(state, [:users, s_pid, :group], nil)
          send(s_pid, [
            :class_status_server, [
              :group_change_event,
              %{group: nil, members: []}
          ]])
          new_s

        _ ->
          new_s = put_in(state, [:users, s_pid, :group], group)
          # lines = Classroom.Whiteboard.connect({target}, s_pid)
          notify_group(
            group,
            :group_change_event,
            %{group: group, members: get_group_members(group, new_s)},
            new_s
          )
          new_s
      end

    case originalGroup do
      nil -> nil
      "All" -> nil
      _ ->
        notify_group(
          originalGroup,
          :group_change_event,
          %{group: originalGroup, members: get_group_members(originalGroup, new_state)},
          new_state
        )
    end

    {:reply, :ok, new_state}
  end

  def handle_call(:get_groups, _from, state) do
    groups =
      state.users
      |> Enum.map(fn {_, b} ->
        case b.group do
          nil ->
            nil

          _ ->
            %{status: b.group, id: b.self_name, name: b.self_name}
        end
      end)
      |> Enum.filter(fn each -> each != nil end)

    {:reply, groups, state}
  end

  # Change to cast
  def handle_call({:change_webcam_permission, user, %{"camera" => camera, "mic" => mic}}, _from, state) do
    {:ok, pid} = Classroom.ActiveUsers.find_pid_by_user(user)
    send(pid, [
      :class_status_server, [
        :webcam_permission_changed_event,
        %{audio: mic, video: camera}
    ]])
    new_state =
      state
      |> Kernel.update_in([:users, pid, :mic], &(&1 = mic)) # mic is unused
      |> Kernel.update_in([:users, pid, :camera], &(&1 = camera)) # same
    {:reply, :ok, new_state}
  end

  defp leave_class(pid, state) do
    # send hangup to each remote peer connection
    %{self_name: sender_name} = state |> Map.fetch!(:users) |> Map.fetch!(pid)
    Logger.info("#{sender_name} leaving class...")
    broadcast_except_sender(state, pid, [
      :signaling, [
        :action,
        "hangup",
        sender_name
    ]])

    # notify other clients when a user exit
    update_class_state_to_clients(remove_user_from_state(state, pid))
  end

  defp update_class_state_to_clients(state) do
    state.users
    |> Map.keys()
    |> Enum.map(fn pid -> send(pid, :get_session_user) end)
  end

  defp notify_group(group, event_type, json, state) do
    get_group_members(group, state)
    |> Enum.each(fn member ->
      {:ok, pid} = Classroom.ActiveUsers.find_pid_by_user(member)
      send(pid, [
        :class_status_server, [
          event_type,
          json
      ]])
    end)
  end

  defp broadcast_except_sender(state, sender_pid, json) do
    state
    |> Map.get(:users)
    |> Map.keys()
    |> Enum.filter(fn pid -> pid != sender_pid end)
    |> Enum.map(fn pid -> send(pid, json) end)
  end

  # defp broadcast_to_pc_ready(state, joiner_pid) do
  #   {:ok, joiner} = Classroom.ActiveUsers.find_user_by_pid(joiner_pid)

  #   exist_peer_conn(state)
  #   |> Enum.map(fn u ->
  #     case Classroom.ActiveUsers.find_pid_by_user(u) do
  #       {:ok, pid} ->
  #         send(pid, %{
  #           type: :broadcast_message,
  #           message: %{
  #             type: :join,
  #             stream_owner: u,
  #             joiner: joiner
  #           },
  #           DEBUG: :broadcast_to_pc_ready
  #         })

  #       _ ->
  #         Logger.debug(Classroom.ActiveUsers.find_pid_by_user(u))
  #     end
  #   end)
  # end

  defp update_pc_in_state(pid, state) do
    state |> Kernel.update_in([:users, pid, :pc], &(!&1))
  end

  defp get_exist_peer_conn(state) do
    exist_peer_conn(state)
    |> Enum.map(fn pid ->
        case Classroom.ActiveUsers.find_user_by_pid(pid) do
          {:ok, u} -> u
        end
      end)
  end

  defp exist_peer_conn(state) do
    state
    |> Map.get(:users)
    |> Enum.map(fn {k, v} ->
      if v.pc do
        k
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp remove_user_from_state(state, pid) do
    group = state.users[pid].group

    # remove_user_from_state
    {_, new_state} = Kernel.pop_in(state, [:users, pid])

    case group do
      nil ->
        nil

      _ ->
        # notify group member
        notify_group(
          group,
          :group_change_event,
          %{group: group, members: get_group_members(group, new_state)},
          new_state
        )
    end

    new_state
  end

  def get_group_members(group, state) do
    state.users
    |> Enum.reduce(%{}, fn {_pid, %{group: gp, self_name: sn}}, map ->
      Map.update(map, gp, [sn], &[sn | &1])
    end)
    |> Map.get(group, [])
  end
end
