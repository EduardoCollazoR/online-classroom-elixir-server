defmodule Classroom.Websocket do
  @behaviour :cowboy_websocket
  @idle_timeout 60 * 60 * 1000

  def start(port, mod, args) do
    routes = [
      {:_,
       [
         {"/", __MODULE__, {mod, args}}
       ]}
    ]

    router = :cowboy_router.compile(routes)

    :cowboy.start_clear(:http, [port: port], %{env: %{dispatch: router}})
  end

  def init(req, params) do
    {:cowboy_websocket, req, params, %{idle_timeout: @idle_timeout}}
  end

  def websocket_init({mod, args}) do
    {:ok, state} = mod.init(args)
    {:ok, {mod, state}}
  end

  def websocket_handle({:binary, _}, state) do
    {:reply, {:close, 1003, "Unsupported Data"}, state}
  end

  def websocket_handle({:ping, _}, state) do
    {:ok, state}
  end

  def websocket_handle({:pong, _}, state) do
    {:ok, state}
  end

  def websocket_handle({:text, text}, s = {mod, state}) do
    case Poison.decode(text) do
      {:ok, ["cast", type, params]} ->
        mod.handle_cast(type, params, state) |> cast_result(mod)

      {:ok, ["call", id, type, params]} ->
        mod.handle_call(type, params, state) |> call_result(mod, id)

      {:ok, ["signal_cast", type, params]} ->
        Classroom.Signaling.handle_cast(type, params, state) |> cast_result(mod)

      {:ok, ["signal_call", id, type, params]} ->
        Classroom.Signaling.handle_cast(type, params, state) |> call_result(mod, id)

      {:error, _} ->
        {:reply, {:close, 1003, "Unsupported Data"}, s}
    end
  end

  def websocket_info([:signaling, [term, params]], {mod, state}) do
    Classroom.Signaling.handle_info(term, params, state) |> info_result(mod)
  end

  def websocket_info([:signaling, [term | params]], {mod, state}) do
    Classroom.Signaling.handle_info(term, params, state) |> info_result(mod)
  end

  def websocket_info(term, {mod, state}) do
    mod.handle_info(term, state) |> info_result(mod)
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  defp info_result(result, mod), do: cast_result(result, mod) # identical

  defp cast_result(result, mod) do
    case result do
      {:noreply, new_state} ->
        {:ok, {mod, new_state}}

      {:event, type, params, new_state} ->
        {:reply, {:text, Poison.encode!([:event, type, params])}, {mod, new_state}}

      {:stop, new_state} ->
        {:stop, {mod, new_state}}
    end
  end

  defp call_result(result, mod, id) do
    case result do
      {:reply, reply, new_state} ->
        {:reply, {:text, Poison.encode!([:reply, id, reply])}, {mod, new_state}}

      {:stop, reply, new_state} ->
        {:reply, [{:text, Poison.encode!([:reply, id, reply])}, :close], {mod, new_state}}
    end
  end

end
