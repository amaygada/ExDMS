defmodule Client.TCPSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, name: Client.DynamicTCPSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Client.WriteTaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
