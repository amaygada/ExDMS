defmodule Network.Config do
  @moduledoc """
    The Network.Config module is responsible for
      - Setting and fetching the Node list
      - Checking which nodes are alive
      - Which node IP maps to which worker/master/client
    (basically any network related helper function)
  """

  @doc """
    Node list defines the list of nodes connected
  """
  def get_node_list(), do: [:"master@127.0.0.1", :"workera@127.0.0.1", :"workerb@127.0.0.1", :"workerc@127.0.0.1"]

  @doc """
    Node map defines which node in the DFS has what node name
  """
  def get_node_map(), do: %{"master" => :"master@127.0.0.1", "workera" => :"workera@127.0.0.1", "workerb" => :"workerb@127.0.0.1", "workerc" => :"workerc@127.0.0.1"}

  @doc """
    Node map defines which node in the DFS has what node name
  """
  def get_reverse_node_map(), do: %{:"master@127.0.0.1" => "master", :"workera@127.0.0.1" => "workera", :"workerb@127.0.0.1" => "workerb", :"workerc@127.0.0.1" => "workerc"}

  @doc """
    IP Map defines which node in the DFS has what IP
  """
  def get_ip_map, do: %{"master" => {127,0,0,1}, "workera" => {127,0,0,1}, "workerb" => {127,0,0,1}, "workerc" => {127,0,0,1}}

  @doc """
    Port Map defines which node listens on what port (this is temporary as we want to mimic a multiple node scenario)
  """
  def get_port_map, do: %{"master" => 4040, "workera" => 5000, "workerb" => 5001, "workerc" => 5002}

  @doc """
    Get master IP
  """
  def get_master_ip(), do: {127,0,0,1}

  @doc """
    Get TCP port
  """
  def get_port(), do: 4040

end
