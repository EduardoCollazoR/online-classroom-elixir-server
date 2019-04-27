defmodule Classroom.Server.GroupWhiteboard do
  use Classroom.GroupWhiteboard.Protocol
  require Logger

  # ----------
  # All connected clients receive these events

  @impl true
  def handle_info(:draw_event, [target, lines], state = %{identity: :user, at: {_owner, _class_name}}) do
    # Logger.info("#{inspect self()} received draw_event for whiteboard: #{target}")
    {:event, "group_whiteboard_draw_" <> target, lines, state}
  end

  # @impl true
  # def handle_info(:offer, [stream_owner, offer, sender_name], state = %{identity: :user}) do
  #   {:event, :offer, %{stream_owner: stream_owner, from: sender_name, offer: offer}, state}
  # end

  @impl true
  def handle_info(msg_type, _params, state) do
    Logger.info("Group Whiteboard server sending message to invalid client, msg_type: #{msg_type}")
    {:noreply, state} # use stop in production
  end

  # ----------
  # cast

  @impl true
  def handle_cast(
      "draw",
      %{"target" => group, "lines" => lines},
      state = %{at: {owner, class_name}}
    ) do
    :ok = Classroom.GroupWhiteboard.draw(owner, class_name, group, lines)
    {:noreply, state}
  end

  @impl true
  def handle_cast("disconnect", target, state = %{identity: :user, at: {owner, class_name}}) do
    case Classroom.ActiveGroupWhiteboard.Registry.whereis_name({:group_whiteboard, owner, class_name, target}) do
      :undefined ->
        {:noreply, state}

      _pid ->
        case Classroom.GroupWhiteboard.disconnect(owner, class_name, target) do
          [:reject, _reason] ->
            {:noreply, state}

          _lines ->
            {:noreply,
              Map.update!(state, :connected_whiteboard, fn cw ->
                List.delete(cw, target) end
              )
            }
        end
    end
  end

  @impl true
  def handle_cast(msg_type, _params, state) do
    Logger.info("Whiteboard server received invalid CAST message, msg_type: #{msg_type} #{"inspect state"}")
    {:noreply, state} # use stop in production
  end

  # ----------
  # async call

  # @impl true
  # def handle_call("start", _nil, state = %{identity: :user}) do
  #   {:ok, target} = Classroom.ActiveUsers.find_user_by_pid(self())

  #   case Classroom.ActiveGroupWhiteboard.start({target}) do
  #     {:ok, _} ->
  #       case Classroom.GroupWhiteboard.connect(target) do
  #         [:reject, reason] ->
  #           {:reply, %{type: :error, reason: reason}, state}

  #         lines ->
  #           {:reply, lines, state}
  #         end

  #     _ ->
  #       {:reply, :error, state}
  #   end
  # end

  @impl true
  def handle_call("connect", target, state = %{identity: :user, at: {owner, class_name}}) do
    case Classroom.ActiveGroupWhiteboard.Registry.whereis_name({:group_whiteboard, owner, class_name, target}) do
      :undefined ->
        {:reply, %{type: :error, reason: :pending}, state}

      _pid ->
        case Classroom.GroupWhiteboard.connect(owner, class_name, target) do
          [:reject, reason] ->
            {:reply, %{type: :error, reason: reason}, state}

          lines ->
            {:reply, lines,
              Map.update!(state, :connected_whiteboard,
                &(&1 = [target | state.connected_whiteboard])
              )
            }
        end
    end
  end

  @impl true
  def handle_call(msg_type, _params, state) do
    Logger.info("Group Whiteboard server received invalid CALL message, msg_type: #{msg_type}")
    {:reply, %{type: :unexpected}, state} # use stop in production
  end

end
