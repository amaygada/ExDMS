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
    :ets.new(:connections, [:named_table, :public, read_concurrency: true])
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
        packet: 4,
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
        # IO.inspect(data)
        handle_request(socket, Jason.decode!(data))
        serve(socket)
      {:error, err} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated  =>  Reason: " <> Atom.to_string(err) <> IO.ANSI.reset())
    end
  end

  @doc """
  Handles request depending on the data in the request json
  """
  defp handle_request(gentcp_socket, %{"type" => "write"} = data) do
    # IO.inspect(data)
    {:ok, _pid} = Task.Supervisor.start_child(Worker.WriteTaskSupervisor, fn -> write_and_cascade(gentcp_socket, data) end)
  end

  defp handle_request(gentcp_socket, %{"type" => "read sequential"} = data) do
    # IO.inspect(data)
    {:ok, _pid} = Task.Supervisor.start_child(Worker.WriteTaskSupervisor, fn -> read_sequentially(gentcp_socket, data) end)
  end

  defp handle_request(gentcp_socket, %{"type" => "read async"} = data) do
    # IO.inspect(data)
    {:ok, _pid} = Task.Supervisor.start_child(Worker.WriteTaskSupervisor, fn -> read_async(gentcp_socket, data) end)
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


  def read_async(gentcp_socket, data) do
    #read_cid
    cid = data["cid"]

    #respons with chuk sequence
    seq = data["seq"]
  end


  @doc """
    Sends chunks to file
  """
  def send_chunk([], _dfs_path, _worker, _gentcp_socket), do: {:ok, "read_complete"}
  def send_chunk([h|rest], dfs_path, worker, gentcp_socket) do
    #find chunk in mnesia
    case Database.Chunk.read_file_in_sequence([sequence_id: h, file_path: dfs_path, worker_id: worker]) do
      {:ok, _, [file]} ->
        {_, cid, _, _, _, _, _, _} = file
        # IO.inspect("data/"<>worker<>"/"<>cid<>".txt")
        case File.read("data/"<>worker<>"/"<>cid<>".txt") do
          {:ok, val} ->
            write_line("ok "<>Jason.encode!(val), gentcp_socket)
          {:error, err} ->
            IO.inspect(err)
            write_line("error some error", gentcp_socket)
        end
    end
    send_chunk(rest, dfs_path, worker, gentcp_socket)
  end

  @doc """
    Given sequence number, read chunks and send them over tcp
  """
  def read_sequentially(gentcp_socket, data) do
    sequences = Enum.to_list(data["start"]..data["end"])
    worker = Network.Config.get_reverse_node_map()[node()]
    send_chunk(sequences, data["dfs_path"], worker, gentcp_socket)
  end

  @doc """
  Sends write requests to other workers
  """
  defp send_to_worker(h, data, gentcp_socket) do
    case :ets.lookup(:connections, h) do
      [] ->
        # IO.inspect("Connecting new")
        {:ok, socket} = DynamicSupervisor.start_child(Worker.DynamicTCPSupervisor, Worker.SocketServer)
        Worker.SocketServer.connect(socket, Network.Config.get_port_map()[h], Network.Config.get_ip_map()[h])
        :ets.insert(:connections, {h, socket})
        Worker.SocketServer.send_message(socket, Jason.encode!(data))
        #wait for acknowledgement
        a = Worker.SocketServer.async_recv_handler(socket)
        #Writes acknowledgement to the process before it
        #WRITE HERE
        write_line("recv "<>Kernel.inspect(data["seq"])<>"delim", gentcp_socket)

      [{_, socket}] ->
        # IO.inspect("Found connection")
        reply = Worker.SocketServer.send_message(socket, Jason.encode!(data))
        case reply do
          {:ok, :sent} ->
            #wait for acknowledgement
            a = Worker.SocketServer.async_recv_handler(socket)
            #Writes acknowledgement to the process before it
            write_line("recv "<>Kernel.inspect(data["seq"])<>"delim",gentcp_socket)
          {:error, _} ->
            {:ok, socket} = DynamicSupervisor.start_child(Worker.DynamicTCPSupervisor, Worker.SocketServer)
            Worker.SocketServer.connect(socket, Network.Config.get_port_map()[h], Network.Config.get_ip_map()[h])
            :ets.insert(:connections, {h, socket})
            Worker.SocketServer.send_message(socket, Jason.encode!(data))
            #wait for acknowledgement
            a = Worker.SocketServer.async_recv_handler(socket)
            #Writes acknowledgement to the process before it
            write_line("recv "<>Kernel.inspect(data["seq"])<>"delim", gentcp_socket)
        end
    end
  end

  @doc """
    Writes data to worker and cascades to the next worker in the cascade list
  """
  defp write_and_cascade(gentcp_socket, %{"type" => "write", "data" => data, "seq" => seq, "cascade_list" => [h | rest], "replica" => replica, "dfs_path" => dfs_path}) do
    #created chunk_id
    {a,b,c} = :os.timestamp
    chunk_id = Kernel.inspect(a)<>" "<>Kernel.inspect(b)<>" "<>Kernel.inspect(c)

    #write data to file: chunk_id.txt
    worker = Network.Config.get_reverse_node_map()[node()]
    path = "data/"<>worker<>"/"<>chunk_id<>".txt"
    File.write(path, data)

    #Add chunk data to mnesia
    #TRANSACTION HERE
    Database.Chunk.write_to_chunk([chunk_id: chunk_id, sequence_id: seq, file_path: dfs_path, worker_id: worker, replica_number: replica, hash_value: ""])

    #cascade the request to next worker
    case h do
      "end" ->
        #send response to previous worker
        #SEND RESPONSE HERE
        write_line("recv "<>Kernel.inspect(seq)<>"delim", gentcp_socket)
        1+1
      _ ->
        send_to_worker(h, %{"type" => "write", "data" => data, "seq" => seq, "cascade_list" => rest, "replica" => replica+1, "dfs_path" => dfs_path}, gentcp_socket)
    end
  end

end
