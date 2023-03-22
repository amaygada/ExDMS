defmodule Master do

  use Application

  @impl true
  def start(_type, _args) do

    IO.puts("")

    IO.puts(IO.ANSI.blue_background() <> "BOW TO THE MASTER" <> IO.ANSI.reset())

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

    #handshake with each worker, check if they are alive, if they are alive, get available space and RAM (or maybe for now assume that RAM is same in all nodes)
    node_list = Network.Config.get_node_list()
    node_reverse_map = Network.Config.get_reverse_node_map()
    Enum.each(node_list, fn x ->
      case Network.Helper.check_alive(x,2) do
        {:ok, :alive} ->
          IO.puts(IO.ANSI.green() <> node_reverse_map[x] <> " ALIVE" <> IO.ANSI.reset())
        {:error, _} ->
          IO.puts(IO.ANSI.red() <> node_reverse_map[x] <> " DOWN" <> IO.ANSI.reset())
      end
    end)


    children = [
      {Task.Supervisor, name: Master.TCPServer.TaskSupervisor},
      {Task, fn -> Master.TCPServer.accept(4040) end}
    ]

    opts = [strategy: :one_for_all, name: Master.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
