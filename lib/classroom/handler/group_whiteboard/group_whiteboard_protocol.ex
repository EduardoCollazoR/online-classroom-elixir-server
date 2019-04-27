defmodule Classroom.GroupWhiteboard.Protocol do
  @type msg_type :: atom()
  @type params :: term()
  @type state :: term()

  @callback handle_info(msg_type(), params(), state()) ::
    {:noreply, state()} |
    {:event, msg_type(), params(), state()} |
    {:stop, state()}

  @callback handle_cast(msg_type(), params(), state()) ::
  {:noreply, state()} |
  {:event, msg_type(), params(), state()} |
  {:stop, state()}

  @callback handle_call(msg_type, params(), state()) ::
  {:reply, params(), state()} |
  {:event, msg_type(), params(), state()} |
  {:stop, state()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Classroom.GroupWhiteboard.Protocol
    end
  end
end
