defmodule Worker.ListenServer do

  use GenServer
  require Logger

  @doc """
    Starts genserver
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    socket = accept()
    send(self(), :accept)

    init_state = %{"socket" => socket}
    {:ok, init_state}
  end

  def handle_info(:accept, state) do
    {:ok, client} = :gen_tcp.accept(state["socket"])
    {:ok, pid} = Task.Supervisor.start_child(Worker.ListenServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    send(self(), :accept)
    {:noreply, state}
  end

  def accept() do
    worker = Network.Config.get_reverse_node_map()[node()]
    ip = Network.Config.get_ip_map()[worker]
    port = Network.Config.get_port_map()[worker]

    {:ok, socket} = :gen_tcp.listen(
      port,
      [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true,
        ip: ip
      ]
    )
    Logger.info("Accepting connections on port #{port}")
    socket
  end

  defp serve(socket) do
    case read_line(socket) do
      {:ok, data} ->
        IO.inspect(data)
        serve(socket)
      {:error, err} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated  =>  Reason: " <> Atom.to_string(err) <> IO.ANSI.reset())
    end
  end

  # @doc """
  #   Read message from client over TCP
  # """
  defp read_line(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        {:ok, data}
      {:error, :closed} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated" <> IO.ANSI.reset())
        {:error, :closed}
      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated" <> IO.ANSI.reset())
        IO.inspect(reason)
        {:error, reason}
    end
  end

end
