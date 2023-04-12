defmodule Database.Chunk do

  @moduledoc """
    Chunk table
    Used to access chunks of files
      :chunk_id  [PK]          //denotes the id of the file chunk (based on timestamp + replica no)
      :sequence_id            // denotes the numerical sequence of that chunk
      :append_list              // a list of sub ids in case files are appended or updated
      :file_path                   //denotes the file path for the chunk parent. (index table here)
      :worker_id                 //denotes the id of the worker node where the chunk is stored
      :replica_number        //denotes the replica number of the chunk
      :hash_value              //denotes the hash value of the chunk

    This module will define all helper functions for the Chunk Table
  """

  alias :mnesia, as: Mnesia


  @doc """
    Writes a record to the Chunk Table
    Takes as input a keyword list
    Eg. write_to_chunk([chunk_id: "abc", sequence_id: 1, file_path: "/home/folder1/a.txt", worker_id: 1, replica_number: 1, hash_value: "lalalalala"])
  """
  def write_to_chunk(attributes) do
    Mnesia.transaction(
      fn ->
        Mnesia.write(
          {
            Chunk_Table,
            attributes[:chunk_id],
            attributes[:sequence_id],
            [],
            attributes[:file_path],
            attributes[:worker_id],
            attributes[:replica_number],
            attributes[:hash_value]
          }
        )
      end
    ) |> Database.Init.check_transactions()
  end


  @doc """
    Allows reading a particular file, given the file path, sequence id and replica number
    Takes as input a keyword list
    Eg. read_file_in_sequence([sequence_id: 1, file_path: "/home/folder1/a.txt", replica_number: 1])
  """
  def read_file_in_sequence(attributes) do
    Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            Chunk_Table,
            :_,
            attributes[:sequence_id],
            :_,
            attributes[:file_path],
            attributes[:worker_id],
            :_,
            :_
          }
        )
      end
    ) |> Database.Init.check_transactions()
  end

  @doc """
    Helps in finding which workers have which files
  """
  def find_workers(attributes) do
    Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            Chunk_Table,
            :_,
            :_,
            :_,
            attributes[:file_path],
            attributes[:worker_id],
            :_,
            :_
          }
        )
      end
    ) |> Database.Init.check_transactions()
  end


  @doc """
    Allows reading a particular file in batches of chunks
    Batch size is defined in the keyword list passed as argument
    Eg. [file_path: "/home/folder1/a.txt", replica_number: 1, sequence_id_start: 0, sequence_id_end: 3]
  """
  def read_file_in_sequence_batch(attributes) do
    Mnesia.transaction(
      fn ->
        Mnesia.select(
            Chunk_Table,
            [
              {
                {Chunk_Table, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"},
                [
                  {:>, :"$2", attributes[:sequence_id_start]},
                  {:<, :"$2", attributes[:sequence_id_end]},
                  {:==, :"$4", attributes[:file_path]},
                  {:==, :"$6", attributes[:replica_number]}
                ],
                [:"$$"]
              }
            ]
        )
      end
    ) |> Database.Init.check_transactions()
  end


  @doc """
    Allows reading a particular file, given the file path, sequence id and replica number
    Takes as input a keyword list
    Eg. read_file_in_sequence([sequence_id: 1, file_path: "/home/folder1/a.txt", replica_number: 1])
  """
  def check_if_replica_is_valid(attributes) do
    trans = Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            Chunk_Table,
            :_,
            :_,
            :_,
            attributes[:file_path],
            :_,
            attributes[:replica_number],
            :_
          }
        )
      end
    ) |> Database.Init.check_transactions()

    case trans do
      {:ok, :read_successful, []} ->
        {:ok, []}
      {:ok, :read_successful, files} ->
        {:ok, files}
      _ ->
        trans
    end
  end
end
