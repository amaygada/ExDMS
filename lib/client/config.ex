defmodule Client.Config do
  @moduledoc """
  Handles all the configuration details relevant to the client (eg. chunk size, number of replicas, etc)
  """


  @doc """
  Defines the chunk size of the DFS in Bytes
  """
  def get_chunk_size(), do: 128000


  @doc """
  Defines the replication factor of the DFS
  """
  def get_replication_factor(), do: 2


end
