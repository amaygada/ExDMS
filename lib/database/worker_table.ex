defmodule Database.WorkerTable do


  @moduledoc """
    Worker table
    Has details about the workers
      :worker_id  (workera, workerb, workerc)
      :space_remaining
      :ram_size

    This module defines helper functions for the Worker table
  """

  alias :mnesia, as: Mnesia


  @doc """
    Writes to the ID Table
  """
  def write_to_worker_table(attributes) do
    Mnesia.transaction(
      fn ->
        Mnesia.write({Worker_Table, attributes[:worker_id], attributes[:space_remaining], attributes[:space_used], attributes[:ram_size]})
      end
    ) |> Database.Init.check_transactions()
  end

end
