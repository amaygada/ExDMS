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
        handle_request(Parser.Parse.parse(data), socket)
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


  ################################################## WORKER HANDLE REQUESTS ######################################################



  ################################################## CLIENT HANDLE REQUESTS #######################################################
  @doc """
    Handle Requests and send reply via tcp
  """
  defp handle_request({:ls, rest}, socket) do
    [path] = rest
    path = case path do
      "/" ->
        "/"
      _ ->
        path<>"/"
    end
    case Master.Operations.ls_operation(path) do
      {:ok, reply} ->
        write_line("ok "<>reply<>" \n", socket)
      {:error, e} ->
        write_line("error "<>e<>" \n", socket)
    end
  end

  defp handle_request({:touch, rest}, socket) do
    [parent_folder_path, file_name] = rest
    case Master.Operations.touch_operation(parent_folder_path, file_name) do
      {:ok, reply} ->
        write_line("ok "<>reply<>" \n", socket)
      {:error, e} ->
        write_line("error "<>e<>" \n", socket)
    end
  end

  defp handle_request({:mkdir, rest}, socket) do
    [parent_folder_path, folder_name] = rest
    case Master.Operations.mkdir_operation(parent_folder_path, folder_name) do
      {:ok, reply} ->
        write_line("ok "<>reply<>" \n", socket)
      {:error, e} ->
        write_line("error "<>e<>" \n", socket)
    end
  end

  defp handle_request({:cd, rest}, socket) do
    [path] = rest
    path = case path do
      "/" ->
        "/"
      _ ->
        path<>"/"
    end
    case Master.Operations.cd_operation(path) do
      {:ok, reply} ->
        write_line("ok "<>reply<>" \n", socket)
      {:error, e} ->
        write_line("error "<>e<>" \n", socket)
    end
  end

  defp handle_request({:cpFromLocal, rest}, socket) do
    case Master.Operations.cpFromLocal_operation(rest, socket) do
      {:ok, reply} ->
        write_line("ok "<>Jason.encode!(reply)<>" \n", socket)
      {:error, reason} ->
        write_line("error "<>reason<>" \n", socket)
    end
  end

  defp handle_request({:cpToLocal, rest}, socket) do
    case Master.Operations.cpToLocal_operation(rest, socket) do
      {:ok, reply} ->
        write_line("ok "<>Jason.encode!(reply)<>" \n", socket)
      {:error, reason} ->
        write_line("error "<>reason<>" \n", socket)
    end
  end
end
