defmodule Classroom.Handler.Protocol do
  @type msg_type :: term() # string()
  @type state :: term()
  @type reply :: term()
  @type params :: term()
  @type event :: term()

  @callback init(opts :: term()) :: {:ok, state}

  @callback handle_cast(msg_type, params(), state()) ::
    {:noreply, state()} |
    {:event, event(), state()} |
    {:stop, state()}

  @callback handle_call(msg_type, params(), state()) ::
    {:reply, reply(), state()} |
    {:event, msg_type(), event(), state()} |
    {:stop, state()}

  @callback handle_info(msg_type :: atom(), state()) ::
    {:noreply, state()} |
    {:event, msg_type(), event(), state()} |
    {:stop, state()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Classroom.Handler.Protocol
    end
  end
end
