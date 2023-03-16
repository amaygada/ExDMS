defmodule Network.Helper do

  @moduledoc """
    Contains helper functions that would aid in any network related functionality
  """

  @doc """
      check_alive checks if the node is alive
  """
  def check_alive(node) do
    case Node.ping(node) do
      :ping ->
        {:ok, :alive}
      :pang ->
        {:error, :down}
      _ ->
        {:error, :unknown}
    end
  end


  @doc """
    Checks if all nodes in the node list are alive
    Used at startup
  """
  def check_all_node_alive_at_startup(node_list) do

  end

end
