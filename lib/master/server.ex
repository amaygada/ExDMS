defmodule Master.TCPServer do
  require Logger


  @doc """
    Sets up a socket on defined port and ip
    Listens till client connects
    passes request to an async loop acceptor
  """
  def accept(port) do
    ip = Network.Config.get_master_ip()
    port = Network.Config.get_port()

    {:ok, socket} = :gen_tcp.listen(
      port,
      [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true,
        ip: Network.Config.get_master_ip()
      ]
    )
    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end


  # @doc """
  #   The loop acceptor accepts connections from clients
  #   Asynchronously serves their request
  #   Waits for other connections
  # """
  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Master.TCPServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end


  # @doc """
  #   SERVE REQUEST DEPENDING ON REQUEST FROM CLIENT
  # """
  defp serve(socket) do
    case read_line(socket) do
      {:ok, data} ->
        # do operation depending on data received here
        handle_request(Parser.Parse.parse(data), socket)
        serve(socket)
      {:error, err} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated  =>  Reason: " <> Atom.to_string(err) <> IO.ANSI.reset())
    end
  end


  defp handle_request({:ls, rest}, socket) do
    [path] = rest
    case Master.Operations.ls_operation(path) do
      {:ok, reply} ->
        write_line("ok "<>reply<>" \n", socket)
      {:error, e} ->
        write_line("error "<>e<>" \n", socket)
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


  # @doc """
  #   Send message to client over TCP
  # """
  defp write_line(line, socket) do
    reply = :gen_tcp.send(socket, line)
    case reply do
      :ok ->
        {:ok, :sent}
      _ ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated. Client seems to be down :(" <> IO.ANSI.reset())
        {:error, reply}
    end
  end

end
