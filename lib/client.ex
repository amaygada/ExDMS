defmodule Client do
  use Application

  @impl true
  def start(_type, _args) do

    IO.puts("")

    IO.puts(IO.ANSI.blue_background() <> "COMING IN WITH THAT CLIENT RIZZ" <> IO.ANSI.reset())

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

    #waits for master to be alive and connects to it


    children = [
      {Client.StateServer, name: Client.StateServer},
      {Task, fn -> Client.StateServer.connect(Client.StateServer) end}
    ]

    opts = [strategy: :one_for_one, name: Client.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
