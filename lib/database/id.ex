defmodule Database.ID do


  @moduledoc """
    ID Table
    (Special table with only one record)
    Maintains count of the file access table for easy update of ID in FileAccessTable
      :file_access_table_id

    This module defines helper functions for the ID table
  """

  alias :mnesia, as: Mnesia


  @doc """
    Fetches the ID from the ID Table
  """
  def get_id() do
    id = Mnesia.transaction(
      fn ->
        Mnesia.read({ ID_Table, 1})
      end
    )

    case id do
      {:atomic, []} ->
        {:ok, 0}
      {:atomic, [{ID_Table, 1, i}]}->
        {:ok, i}
      _ ->
        id
    end
  end


  @doc """
    Writes to the ID Table
  """
  def write_to_id(id) do
    Mnesia.transaction(
      fn ->
        Mnesia.write({ ID_Table, 1, id })
      end
    ) |> Database.Init.check_transactions()
  end

end
