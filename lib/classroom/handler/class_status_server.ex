defmodule Classroom.Server.ClassStatus do
  use Classroom.ClassStatus.Protocol
  require Logger

  # ----------
  # Clients at the same classroom receive these events

  @impl true
  def handle_info(:group_change_event, json = %{group: group, members: member}, state = %{identity: :user}) do
    {:event, :group_status_change, json, state}
  end

  @impl true
  def handle_info(msg_type, _params, state) do
    Logger.info("ClassStatus service sending message to invalid client, msg_type: #{inspect msg_type}")
    {:noreply, state} # use stop in production
  end

  # ----------
  # cast

  # @impl true
  # def handle_cast(
  #     "?",
  #     %{"?" => func},
  #     state = %{at: {owner, class_name}}
  #   ) do
  #   :ok = Classroom.Class.func(owner, class_name)
  #   {:noreply, state}
  # end

  @impl true
  def handle_cast(msg_type, _params, state = %{at: {owner, class_name}}) do
    Logger.info("ClassStatus service received invalid CAST message, msg_type: #{msg_type} #{"inspect state"}")
    {:noreply, state} # use stop in production
  end

  # ----------
  # async call

  @impl true
  def handle_call("change_group", %{"student" => student, "group" => group}, state = %{at: {owner, class_name}}) do
    {
      :reply,
      %{result: Classroom.Class.change_group(owner, class_name, student, group)},
      state
    }
  end

  @impl true
  def handle_call("get_groups", _, state = %{at: {owner, class_name}}) do
    {
      :reply,
      %{result: Classroom.Class.get_groups(owner, class_name)},
      state
    }
  end

  @impl true
  def handle_call(msg_type, _params, state) do
    Logger.info("ClassStatus service received invalid CALL message, msg_type: #{msg_type}")
    {:reply, %{type: :unexpected}, state} # use stop in production
  end

end
