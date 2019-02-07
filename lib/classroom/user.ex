defmodule Classroom.User do
  # init: receive welcome message
  #
  # handle:
  #   login (g)                   {"type":"login","username":"herbert","password":"123"}
  #   register (g)                {"type":"register","username":"herbert","password":"123", nickname}
  #   logout (u)                  {"type":"logout"}
  #   draw (u+o)
  #   chat (u)
  #
  #   create classroom (u)        {"type":"create_class","class_name": class_name}
  #   get created class (u)       {"type":"get_created_class"}
  #   destroy classroom (u+owner)
  #
  #   subscribe classroom (u)     {"type":"subscribe_class", "owner": owner,"class_name": class_name}
  #   get subscribed class (u)    {"type":"get_subscribed_class"}
  #   unsubscribe classroom (u)   {"type":"unsubscribe_class", "owner": owner,"class_name": class_name}
  #
  #   start classroom (u+owner)   {"type": "start_class", "class_name": class_name}
  #   pause classroom (u+owner)
  #   join classroom (u)          {"type": "join_class", "owner": "dev", "class_name": "class"}
  #   leave classroom (u)         {"type": "leave_class", "owner": "dev", "class_name": "class"}
  #   get_session_user (o)        {type: "get_session_user"}
  #   get started class           {type: "get_started_class"}
  #
  # broadcast update:
  #   classroom (u)  : session_user
  #   start_class_success : to active participants
  #   message (u)
  #   draw (u)

  require Logger

  @behaviour :cowboy_websocket

  def init(req, params) do
    {:cowboy_websocket, req, params, %{idle_timeout: 60 * 60 * 1000}}
  end

  # return value: {:ok, state} | {:reply, {:text, string()}, state} | {:stop, state}
  def websocket_init(_params) do
    Logger.debug("A client has connected #{inspect(self())}")
    json = %{type: :init, data: "Welcome, your pid is #{inspect(self())}"}
    {:reply, {:text, Poison.encode!(json)}, %{identity: :guest, at: :no, user_data: %{}}}
  end

  def websocket_handle({:text, msg}, state) do
    case Poison.decode(msg) do
      {:ok, json} ->
        handle_in(json, state)
        |> handle_call_result()

      {:error, _} ->
        Logger.debug("websocket received malformed message: #{inspect(msg)}")
        {:stop, state}
    end
  end

  def websocket_info(json, state = %{identity: :user}) do
    # {:reply, json, state}
    handle_info(json, state)
    |> handle_call_result()
  end

  def websocket_info(json, state) do
    Logger.debug("Server sending message to invalid client, msg: #{json}")
    # {:stop, state}
    {:reply, %{type: :unexpected_internal_error}, state}
  end

  def handle_call_result({:ok, new_state}) do
    {:ok, new_state}
  end

  def handle_call_result({:reply, json_reply, new_state}) do
    {:reply, {:text, Poison.encode!(json_reply)}, new_state}
  end

  def handle_call_result({:stop, new_state}) do
    {:stop, new_state}
  end

  # return value: {:ok, state} | {:reply, json(), state} | {:stop, state}
  def handle_in(
        %{"type" => "login", "username" => name, "password" => pass},
        state = %{identity: :guest}
      ) do
    case Classroom.UserStore.valid_password?(name, pass) do
      true ->
        Logger.debug("Login: #{name} login success")
        :ok = Classroom.ActiveUsers.login(name)
        {:reply, %{type: :login_success}, Map.update!(state, :identity, fn _ -> :user end)}

      false ->
        Logger.debug("Login: #{name} login failed")
        {:reply, %{type: :login_failed}, state}
    end
  end

  # remove self() from active_user
  def handle_in(%{"type" => "logout"}, state = %{identity: :user}) do
    tmp = Classroom.ActiveUsers.logout()
    IO.inspect(tmp)

    case tmp do
      :ok ->
        Logger.debug("Logout: #{inspect(self())} logout success")
        {:reply, %{type: :logout_success}, Map.update!(state, :identity, fn _ -> :guest end)}
    end
  end

  def handle_in(
        %{"type" => "register", "username" => user, "password" => pass},
        state = %{identity: :guest}
      )
      when is_binary(user) and is_binary(user) and byte_size(user) <= 20 and byte_size(pass) <= 20 do
    case Classroom.UserStore.register(user, pass) do
      :ok ->
        Logger.debug("Register: #{user} register success")
        {:reply, %{type: :register_success}, state}

      :error ->
        Logger.debug("Register: #{user} register failed")
        {:reply, %{type: :register_failed}, state}
    end
  end

  def handle_in(%{"type" => "chat", "data" => data}, state = %{identity: :user})
      when is_binary(data) and is_binary(data) and byte_size(data) <= 20 and byte_size(data) <= 20 do
    Logger.debug("Received chat data #{data}")
    {:ok, state}
  end

  def handle_in(%{"type" => "draw", "data" => data}, state = %{identity: :user}) do
    Logger.debug("Received draw data #{data}")
    {:ok, state}
  end

  def handle_in(
        %{"type" => "create_class", "class_name" => class_name},
        state = %{identity: :user}
      ) do
    Logger.debug("Received create_class of class_name #{class_name}")

    case Classroom.ClassStore.created_class(class_name) do
      :ok ->
        {_, self_name} = Classroom.ActiveUsers.find_user_by_pid(self())
        :ok = Classroom.ClassStore.subscribe(self_name, class_name)
        {:reply, %{type: :create_class_success}, state}

      :error ->
        {:reply, %{type: :create_class_failed}, state}
    end
  end

  def handle_in(
        %{"type" => "subscribe_class", "owner" => owner, "class_name" => class_name},
        state = %{identity: :user}
      ) do
    Logger.debug("Received subscribe_class of class_name #{class_name}")

    case Classroom.ClassStore.subscribe(owner, class_name) do
      :ok ->
        {:reply, %{type: "subscribe_class success", owner: owner, class_name: class_name}, state}

      :error ->
        {:reply, %{type: "subscribe_class failed", owner: owner, class_name: class_name}, state}
    end
  end

  def handle_in(
        %{"type" => "unsubscribe_class", "owner" => owner, "class_name" => class_name},
        state = %{identity: :user}
      ) do
    Logger.debug("Received subscribe_class of class_name #{class_name}")

    case Classroom.ClassStore.unsubscribe(owner, class_name) do
      :ok ->
        {:reply, %{type: "unsubscribe_class success", owner: owner, class_name: class_name},
         state}

      :error ->
        {:reply, %{type: "unsubscribe_class failed", owner: owner, class_name: class_name}, state}
    end
  end

  def handle_in(%{"type" => "get_created_class"}, state = %{identity: :user}) do
    Logger.debug("Received get_created_class")

    {:reply,
     %{type: :get_created_class, created_classes: Classroom.ClassStore.get_created_class()},
     state}
  end

  def handle_in(
        %{"type" => "start_class", "class_name" => class_name},
        state = %{identity: :user}
      ) do
    Logger.debug("Received start_class of class_name #{class_name}")

    case Enum.member?(Classroom.ClassStore.get_created_class(), class_name) do
      true ->
        case Classroom.ClassStore.start_class(class_name) do
          :ok -> {:reply, %{type: "start_class success", class_name: class_name}, state}
          :error -> {:reply, %{type: "start_class failed", class_name: class_name}, state}
        end

      false ->
        {:reply, %{type: "start_class failed", class_name: class_name}, state}
    end
  end

  def handle_in(
        %{"type" => "join_class", "owner" => owner, "class_name" => class_name},
        state = %{identity: :user}
      ) do
    Logger.debug("Received join_class of class_name #{class_name}")
    {:ok, self} = Classroom.ActiveUsers.find_user_by_pid(self())

    case Enum.member?(Classroom.ClassStore.get_subscribers(owner, class_name), self) do
      true ->
        case Classroom.Class.join(owner, class_name) do
          :ok ->
            case state.at do
              {^owner, ^class_name} ->
                {:reply, %{type: "join_class success", owner: owner, class_name: class_name},
                 state}

              {o, c} ->
                :ok = Classroom.Class.leave(o, c)

                {:reply, %{type: "join_class success", owner: owner, class_name: class_name},
                 Map.update!(state, :at, fn _ -> {owner, class_name} end)}

              _ ->
                {:reply, %{type: "join_class success", owner: owner, class_name: class_name},
                 Map.update!(state, :at, fn _ -> {owner, class_name} end)}
            end

          :error ->
            {:reply, %{type: "join_class failed", owner: owner, class_name: class_name}, state}
        end

      false ->
        {:reply, %{type: "join_class failed", owner: owner, class_name: class_name}, state}
    end
  end

  def handle_in(
        %{"type" => "leave_class", "owner" => owner, "class_name" => class_name},
        state = %{identity: :user, at: {owner, class_name}}
      ) do
    Logger.debug("Received leave_class of class_name #{class_name}")

    case Classroom.Class.leave(owner, class_name) do
      :ok ->
        {:reply, %{type: "leave_class success", owner: owner, class_name: class_name},
         Map.update!(state, :at, fn _ -> :no end)}

      :error ->
        {:reply, %{type: "leave_class failed", owner: owner, class_name: class_name}, state}
    end
  end

  def handle_in(%{"type" => "get_subscribed_class"}, state = %{identity: :user}) do
    Logger.debug("Received get_subscribed_clas")

    {:reply,
     %{
       type: :get_subscribed_class,
       subscribed_class: Classroom.ClassStore.get_subscribed_class()
     }, state}
  end

  def handle_in(%{"type" => "get_started_class"}, state = %{identity: :user}) do
    handle_get_started_class(state)
  end

  # useless
  # def handle_in(%{"type" => "get_exist_peer_conn"}, state = %{at: {owner, class_name}}) do
  #   handle_get_exist_peer_conn(owner, class_name, state)
  # end

  def handle_in(%{"type" => "get_session_user"}, state = %{at: {owner, class_name}}) do
    handle_get_session_user(owner, class_name, state)
  end

  def handle_in(
        %{"type" => "class_direct_message", "message" => message},
        state = %{at: {owner, class_name}}
      ) do
    :ok = Classroom.Class.handle_class_direct_message(owner, class_name, message)
    {:ok, state}
  end

  def handle_in(
        %{"type" => "class_broadcast_message", "message" => message},
        state = %{at: {owner, class_name}}
      ) do
    :ok = Classroom.Class.handle_class_broadcast_message(owner, class_name, message)
    {:ok, state}
  end

  def handle_in(msg, state) do
    Logger.debug("Unexpected action", msg)
    IO.inspect("Unexpected action #{inspect(msg)}")
    # {:stop, state}
    {:reply, %{type: :unexpected}, state}
  end

  def handle_info(%{type: :get_started_class}, state = %{identity: :user}) do
    handle_get_started_class(state)
  end


  def handle_info(m = %{type: :broadcast_message, message: message}, state) do
    # IO.inspect({:handle_in, m})
    {:reply, message, state}
  end

  def handle_info(%{type: :get_session_user}, state = %{at: {owner, class_name}}) do
    handle_get_session_user(owner, class_name, state)
  end

  def handle_info(%{type: :get_exist_peer_conn}, state = %{at: {owner, class_name}}) do
    handle_get_exist_peer_conn(owner, class_name, state)
  end

  defp handle_get_started_class(state) do
    {:reply,
     %{
       type: :get_started_class,
       started_class: Classroom.ClassStore.get_started_class()
     }, state}
  end

  defp handle_get_session_user(owner, class_name, state) do
    {:reply,
     %{
       type: :get_session_user,
       session_user: Classroom.Class.get_session_user(owner, class_name)
     }, state}
  end

  defp handle_get_exist_peer_conn(owner, class_name, state) do
    {:reply,
     %{
       type: :get_exist_peer_conn,
       exist_peer_conn: Classroom.Class.get_exist_peer_conn(owner, class_name)
     }, state}
  end
end
