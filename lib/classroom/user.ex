defmodule Classroom.User do
  # init: receive welcome message
  #
  # handle:
  #   login (g)                   {"type":"login","username":"herbert","password":"123"}
  #   register (g)                {"type":"register","username":"herbert","password":"123", nickname}
  #   logout (u)                  {"type":"logout"}
  #   draw (u)
  #   chat (u)
  #   get created class (u)       {"type":"get_created_class"}
  #   get subscribed class (u)
  #   select classroom (u)
  #   create classroom (u)        {"type":"create_class","name_of_class": name_of_class}
  #   start classroom (u+owner)
  #   destroy classroom (u+owner)
  #
  # update:
  #   classroom (u)
  #   message (u)
  #   draw (u)

  require Logger

  @behaviour :cowboy_websocket

  def init(req, params) do
    {:cowboy_websocket, req, params, %{idle_timeout: 60 * 60 * 1000}}
  end

  # return value: {:ok, state} | {:reply, {:text, string()}, state} | {:stop, state}
  def websocket_init(_params) do
    Logger.debug("A client has connected #{inspect self()}")
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
    {:reply, json, state}
    |> handle_call_result()
  end

  def websocket_info(json, state) do
    Logger.debug("Server sending message to invalid client, msg: #{json}")
    {:stop, state}
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
    case Classroom.PasswordStore.valid_password?(name, pass) do
      true ->
        Logger.debug("Login: #{name} login success")
        :ok = Classroom.ActiveUsers.login(name)
        {:reply, %{type: :login_success}, %{identity: :user}}

      false ->
        Logger.debug("Login: #{name} login failed")
        {:reply, %{type: :login_failed}, state}
    end
  end

  # remove self() from active_user
  def handle_in(%{"type" => "logout"}, %{identity: :user}) do
    case Classroom.ActiveUsers.logout() do
      :ok ->
        Logger.debug("Logout: #{inspect(self())} logout success")
        {:reply, %{type: :logout_success}, %{identity: :guest}}
    end
  end

  def handle_in(
        %{"type" => "register", "username" => user, "password" => pass},
        state = %{identity: :guest}
      )
      when is_binary(user) and is_binary(user) and byte_size(user) <= 20 and byte_size(pass) <= 20 do
    case Classroom.PasswordStore.register(user, pass) do
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
        %{"type" => "create_class", "name_of_class" => name_of_class},
        state = %{identity: :user}
      ) do
    Logger.debug("Received create_class of class_name #{name_of_class}")

    case Classroom.ClassStore.created_class(name_of_class) do
      :ok -> {:reply, %{type: :create_class_success}, state}
      :error -> {:reply, %{type: :create_class_failed}, state}
    end
  end

  def handle_in(%{"type" => "get_created_class"}, state = %{identity: :user}) do
    Logger.debug("Received get_created_class")

    {:reply,
     %{type: :get_created_class, created_classes: Classroom.ClassStore.get_created_class()},
     state}
  end

  def handle_in(_, state) do
    Logger.debug("Unexpected action")
    # {:stop, state}
    {:reply, %{type: :unexpected}, state}
  end
end
