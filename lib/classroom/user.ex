defmodule Classroom.User do
  # init: receive welcome message
  # handle: login
  # handle: register
  # handle: draw (u)
  # handle: chat (u)
  # handle: select classroom (u)
  # update: classroom
  # update: message
  # update: draw

  # Problems:
  # json attr atom?

  # API doc
  # register: %{type:"register", data: %{name, user_data: %{(login), pw, nickname, registered_class: []}}
  # login: %{type:"login", data: %{name, pw}}
  #

  require Logger

  @behaviour :cowboy_websocket

  def init(req, params) do
    {:cowboy_websocket, req, params, %{idle_timeout: 60 * 60 * 1000}}
  end

  # return value: {:ok, state} | {:reply, {:text, string()}, state} | {:stop, state}
  def websocket_init(_params) do
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
  def handle_in(%{"type" => "login", "username" => user, "password" => pass}, state = %{identity: :guest}) do
    case Classroom.PasswordStore.valid_password?(user, pass) do
      true ->
        Logger.debug("Login: #{user} login success")
        :ok = Classroom.ActiveUsers.login(user)
        {:reply, %{type: :login_success}, %{identity: user}}

      false ->
        Logger.debug("Login: #{user} login failed")
        {:reply, %{type: :login_failed}, state}
    end
  end

  def handle_in(%{"type" => "logout", "data" => data}, %{identity: :user}) do
    result = Classroom.UserList.login(data)
    Logger.debug("Logout#{result}")
    {:reply, %{type: :validate_logout, data: result}, %{identity: :guest}}
  end

  def handle_in(%{"type" => "register", "data" => data}, state = %{identity: :guest}) do
    result = Classroom.UserList.register(data)
    Logger.debug("Register #{result}")
    {:reply, %{type: :validate_register, data: result}, state}
  end

  def handle_in(%{"type" => "chat", "data" => _}, state = %{identity: :guest}) do
    Logger.debug("Guest attempts to send message")
    {:stop, state}
  end

  def handle_in(%{"type" => "chat", "data" => data}, state) do
    Logger.debug("Received chat data #{data}")
    {:ok, state}
  end

  def handle_in(%{"type" => "draw", "data" => _}, state = %{identity: :guest}) do
    Logger.debug("Guest attempts to draw")
    {:stop, state}
  end

  def handle_in(%{"type" => "draw", "data" => data}, state) do
    Logger.debug("Received draw data #{data}")
    {:ok, state}
  end

  def handle_in(%{"type" => "create_class", "data" => data}, state) do
    Logger.debug("Received create_class data #{data}")
    result = Classroom.ClassList.created_class()
    {:reply, %{type: :validate_create_class, data: result}, state}
  end

  def handle_in(_, state) do
    Logger.debug("Unexpected action")
    {:stop, state}
  end
end
