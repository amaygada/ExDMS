defmodule Worker do

  use Application

  @impl true
  def start(_type, _args) do

    IO.puts("")

    IO.puts(IO.ANSI.blue_background() <> "WORKER GAME STRONG FR" <> IO.ANSI.reset())

    IO.puts("")

    IO.puts("CURRENT NODE")
    IO.inspect(node())
    IO.puts("")

    IO.puts("NODE LIST")
    IO.inspect(Network.Config.get_node_list())
    IO.puts("")

    IO.puts("NODE MAP")
    IO.inspect(Network.Config.get_node_map())
    IO.puts("")

    case Database.Init.start_mnesia() do
      :ok ->
        IO.puts("Mnesia Started Successfully")
      _ ->
        IO.puts("Error in starting Mnesia. Consider starting it Manually using :mnesia.start in the iex shell")
    end
    IO.puts("")

    worker_id = Network.Config.get_reverse_node_map()[node()]
    a = Database.WorkerTable.write_to_worker_table([worker_id: worker_id, space_remaining: Network.Config.get_space_map()[worker_id], space_used: 500, ram_size: 512])
    case a do
      {:ok, _} ->
        IO.puts("WORKER METADATA WRITTEN TO MNESIA")
        IO.puts("")
      _ ->
        IO.puts("ERROR IN WRITING WORKER METADATA TO MNESIA")
        IO.inspect(a)
        a
    end


    children = [
      {Worker.ChunkServer, name: Worker.ChunkServer},
      {Task, fn -> Worker.ChunkServer.connect(Worker.ChunkServer) end},
      {Worker.ListenTCPSupervisor, name: Worker.TCPSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Client.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
