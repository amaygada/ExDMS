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
  def get_node_list(), do: [node()]

  @doc """
    Node map defines which node in the DFS has what IP
  """
  def get_node_map(), do: %{"master" => node()}

  @doc """
    Get master IP
  """
  def get_master_ip(), do: {192, 168, 29, 43}


  @doc """
    Get TCP port
  """
  def get_port(), do: 4040

end
