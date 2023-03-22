defmodule Network.Helper do

  @moduledoc """
    Contains helper functions that would aid in any network related functionality
  """

  @doc """
      check_alive checks if the node is alive
  """
  def check_alive(node) do
    case Node.ping(node) do
      :pong ->
        {:ok, :alive}
      :pang ->
        {:error, :down}
      _ ->
        {:error, Node.ping(node)}
    end
  end
  def check_alive(node, n) when n>0 do
    case Node.ping(node) do
      :pong ->
        {:ok, :alive}
      :pang ->
        IO.puts("Unable to reach "<>Kernel.inspect(node)<>" Trying again in 10 seconds")
        :timer.sleep(10000)
        check_alive(node, n-1)
      _ ->
        {:error, Node.ping(node)}
    end
  end
  def check_alive(node, 0) do
    {:error, :down}
  end


  @doc """
    Checks if all nodes in the node list are alive
    Used at startup
  """
  def check_all_node_alive_at_startup(node_list) do

  end

end
