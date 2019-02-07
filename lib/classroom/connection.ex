defmodule Classroom.Connection do
  use Classroom.Handler.Protocol
  require Logger

  @impl true
  def init(_opts) do
    Logger.info("A client has connected #{inspect(self())}")
    {:ok, %{identity: :guest, at: :no, user_data: %{}}}
  end

  @impl true
  # TODO change _
  def handle_info(:get_started_class, state = %{identity: :user}) do
    # TODO should not return all started class without this user
    {:event, :get_started_class, %{result: Classroom.ClassStore.get_started_class()}, state}
  end

  @impl true
  # TODO change _
  def handle_info(:get_session_user, state = %{identity: :user, at: {owner, class_name}}) do
    {:event, %{result: Classroom.Class.get_session_user(owner, class_name)}, state}
  end

  @impl true
  def handle_info(msg_type, state) do
    Logger.debug("Server sending message to invalid client, msg_type: #{msg_type}")
    {:noreply, state}
  end

  @impl true
  def handle_call(
        "register",
        %{"username" => user, "password" => pass},
        state = %{identity: :guest}
      )
      when is_binary(user) and byte_size(user) <= 15 and byte_size(pass) <= 30 do
    case Classroom.UserStore.register(user, pass) do
      :ok ->
        {:reply, %{type: :ok}, state}

      :error ->
        {:reply, %{type: :reject, reason: :user_exist}, state}
    end
  end

  @impl true
  def handle_call(
        "register",
        %{"username" => _, "password" => _},
        state = %{identity: :guest}
      ) do
    {:reply, %{type: :reject, reason: :invalid_params_15}, state}
  end

  @impl true
  def handle_call(
        "login",
        %{"username" => name, "password" => pass},
        state = %{identity: :guest}
      ) do
    case Classroom.UserStore.valid_password?(name, pass) do
      true ->
        case Classroom.ActiveUsers.login(name) do
          :ok ->
            {:reply, %{type: :ok}, Map.update!(state, :identity, &(&1 = :user))}

          [:error, reason] ->
            {:reply, %{type: :reject, reason: reason}, state}
        end

      false ->
        {:reply, %{type: :reject, reason: :invalid_params}, state}
    end
  end

  @impl true
  # change _ to nil/""/%{}
  def handle_call("logout", _, state = %{identity: :user}) do
    :ok = Classroom.ActiveUsers.logout()
    Logger.debug("Logout: #{inspect(self())} logout")
    {:reply, %{type: :ok}, Map.update!(state, :identity, &(&1 = :guest))}
  end

  @impl true
  def handle_call("create_class", %{"class_name" => class_name}, state = %{identity: :user}) do
    case Classroom.ClassStore.created_class(class_name) do
      :ok ->
        {_, self_name} = Classroom.ActiveUsers.find_user_by_pid(self())
        :ok = Classroom.ClassStore.subscribe(self_name, class_name)
        {:reply, %{type: :ok}, state}

      # TODO change to {:reject, reason}
      [:error, reason] ->
        {:reply, %{type: :reject, reason: reason}, state}
    end
  end

  @impl true
  def handle_call(
        "enroll_class",
        %{"owner" => owner, "class_name" => class_name},
        state = %{identity: :user}
      ) do
    case Classroom.ClassStore.subscribe(owner, class_name) do
      :ok ->
        {:reply, %{type: :ok}, state}

      # TODO give reason
      :error ->
        {:reply, %{type: :reject}, state}
    end
  end

  @impl true
  def handle_call(
        "unenroll_class",
        %{"owner" => owner, "class_name" => class_name},
        state = %{identity: :user}
      ) do
    case Classroom.ClassStore.unsubscribe(owner, class_name) do
      :ok ->
        {:reply, %{type: :ok, owner: owner, class_name: class_name}, state}

      # TODO give reason
      :error ->
        {:reply, %{type: :reject}, state}
    end
  end

  @impl true
  # TODO change _
  def handle_call("get_created_class", _, state = %{identity: :user}) do
    {:reply, %{result: Classroom.ClassStore.get_created_class()}, state}
  end

  @impl true
  def handle_call(
        "start_class",
        %{"class_name" => class_name},
        state = %{identity: :user}
      ) do
    case Enum.member?(Classroom.ClassStore.get_created_class(), class_name) do
      true ->
        case Classroom.ClassStore.start_class(class_name) do
          :ok -> {:reply, %{type: :ok}, state}
          :error -> {:reply, %{type: :reject, reason: :unknow_error}, state}
        end

      false ->
        {:reply, %{type: :reject, reason: :class_not_exist}, state}
    end
  end

  @impl true
  def handle_call(
        "join_class",
        %{"owner" => owner, "class_name" => class_name},
        state = %{identity: :user}
      ) do
    {:ok, self} = Classroom.ActiveUsers.find_user_by_pid(self())

    case Enum.member?(Classroom.ClassStore.get_subscribers(owner, class_name), self) do
      true ->
        case Classroom.Class.join(owner, class_name) do
          :ok ->
            case state.at do
              {^owner, ^class_name} ->
                # {:reply, %{type: "join_class success", owner: owner, class_name: class_name},
                #  state}
                {:reply, %{type: :reject, reason: :invalid_action}, state}

              {o, c} ->
                :ok = Classroom.Class.leave(o, c)

                {:reply, %{type: :ok}, Map.update!(state, :at, &(&1 = {"owner", "class_name"}))}

              _ ->
                {:reply, %{type: :ok}, Map.update!(state, :at, &(&1 = {"owner", "class_name"}))}
            end

          [:reject, reason] ->
            {:reply, %{type: :reject, reason: reason}, state}
        end

      false ->
        {:reply, %{type: :reject, reason: :not_enrolled}, state}
    end
  end

  @impl true
  def handle_call(
        "leave_class",
        %{"owner" => owner, "class_name" => class_name},
        state = %{identity: :user, at: {owner, class_name}}
      ) do
    :ok = Classroom.Class.leave(owner, class_name)
    {:reply, %{type: :ok}, Map.update!(state, :at, &(&1 = :no))}
  end

  @impl true
  # TODO change _
  def handle_call("get_enrolled_class", _, state = %{identity: :user}) do
    {:reply, %{result: Classroom.ClassStore.get_subscribed_class()}, state}
  end

  @impl true
  # TODO change _
  def handle_call("get_started_class", _, state = %{identity: :user}) do
    {:reply, %{result: Classroom.ClassStore.get_started_class()}, state}
  end

  @impl true
  # TODO change _
  def handle_call("get_session_user", _, state = %{at: {owner, class_name}}) do
    {:reply, %{result: Classroom.Class.get_session_user(owner, class_name)}, state}
  end

  @impl true
  def handle_call(msg_type, _, state) do
    Logger.info("Unexpected call action msg_type: #{inspect(msg_type)}")
    # {:stop, state}
    {:reply, %{type: :unexpected}, state}
  end

  @impl true
  def handle_cast(msg_type, _, state) do
    Logger.info("Unexpected cast action msg_type: #{inspect(msg_type)}")
    # {:stop, state}
    # TODO should report error
    {:reply, %{type: :unexpected}, state}
  end
end
