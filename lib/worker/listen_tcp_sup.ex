defmodule Worker.ListenTCPSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {Task.Supervisor, name: Worker.ListenServer.TaskSupervisor},
      {Worker.ListenServer, name: Worker.ListenServer},
      {Worker.SocketTCPSupervisor, name: Worker.SocketTCPSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
