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
  def get_node_list(), do: [:"master@192.168.56.105", :"workera@192.168.56.106", :"workerb@192.168.56.107", :"workerc@192.168.56.108"]

  @doc """
    Node map defines which node in the DFS has what node name
  """
  def get_node_map(), do: %{"master" => :"master@192.168.56.105", "workera" => :"workera@192.168.56.106", "workerb" => :"workerb@192.168.56.107", "workerc" => :"workerc@192.168.56.108"}

  def get_space_map(), do: %{"workera" => 75000000, "workerb" => 75000000, "workerc" => 75000000}

  @doc """
    Node map defines which node in the DFS has what node name
  """
  def get_reverse_node_map(), do: %{:"master@192.168.56.105" => "master", :"workera@192.168.56.106" => "workera", :"workerb@192.168.56.107" => "workerb", :"workerc@192.168.56.108" => "workerc"}

  @doc """
    IP Map defines which node in the DFS has what IP
  """
  def get_ip_map, do: %{"master" => {192,168,56,105}, "workera" => {192,168,56,106}, "workerb" => {192,168,56,107}, "workerc" => {192,168,56,108}}

  @doc """
    Port Map defines which node listens on what port (this is temporary as we want to mimic a multiple node scenario)
  """
  def get_port_map, do: %{"master" => 4040, "workera" => 5000, "workerb" => 5001, "workerc" => 5002}

  @doc """
    Get master IP
  """
  def get_master_ip(), do: {192,168,56,105}

  @doc """
    Get TCP port
  """
  def get_port(), do: 4040

end
