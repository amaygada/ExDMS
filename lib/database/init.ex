defmodule Database.Init do
  @moduledoc """
    Database.Init module is responsible for all the Database initializations
      - create schema
      - create table
      - start Mnesia
      - Stop Mnesia, etc
    Also contains some helper functions for all the databases
  """

  alias :mnesia, as: Mnesia
  require Network.Config


  @doc """
    Creates a schema for the given node list (fetched from the Network.Config Mdoule)
  """
  def create_schema() do
    node_list = Network.Config.get_node_list()
    case Mnesia.create_schema(node_list) do
      :ok ->
        {:ok, :schema_created}
      {:error, {_, {:already_exists, _}}} ->
        {:error, :schema_already_exists}
      {:error, a} ->
        IO.inspect(a)
        {:error, :unknown}
    end
  end


  @doc """
    Deletes and resets schema that we havee created
    NOTE THAT THIS IS A DANGEROUS FUNCTION AND WILL KILL YOUR DB IF USED
    ALL DATA WILL BE LOST
  """
  def delete_and_reset_schema() do
    node_list = Network.Config.get_node_list()
    Mnesia.stop()
    Mnesia.delete_schema(node_list)
  end


  @doc """
    Starts Mnesia
  """
  def start_mnesia(), do: Mnesia.start


  @doc """
    Stops Mnesia
  """
  def stop_mnesia(), do: Mnesia.stop


  @doc """
    Creates all the necessary lookup tables for the DFS
    Initializes file_access_table_id in ID_Table to 0
  """
  def create_tables() do
    node_list = Network.Config.get_node_list()

    case create_chunk_table(node_list) do
      {:atomic, :ok} ->
        IO.inspect("chunk table created")
      {:aborted, reason} ->
        IO.inspect("Error in creating chunk table")
        IO.inspect(reason)
    end

    case create_file_access_table(node_list) do
      {:atomic, :ok} ->
        IO.inspect("File access table created")
      {:aborted, reason} ->
        IO.inspect("Error in creating file access table")
        IO.inspect(reason)
    end

    case create_worker_table(node_list) do
      {:atomic, :ok} ->
        IO.inspect("Worker table created")
      {:aborted, reason} ->
        IO.inspect("Error in creating worker table")
        IO.inspect(reason)
    end

    case create_id_table(node_list) do
      {:atomic, :ok} ->
        IO.inspect("ID table created")
      {:aborted, reason} ->
        IO.inspect("Error in creating ID table")
        IO.inspect(reason)
    end

    Database.ID.write_to_id(0)
    Database.FileAccess.write_to_file_access_table(
      [folder_path: "/", file_name: "", file_size: 0, type: "folder"]
    )

    {:ok, "Tables Created and ID Table Initialized"}
  end


  # @doc """
  #   Chunk table
  #   Used to access chunks of files
  #     :chunk_id  [PK]          //denotes the id of the file chunk (based on timestamp + replica no)
  #     :sequence_id            // denotes the numerical sequence of that chunk
  #     :append_list              // a list of sub ids in case files are appended or updated
  #     :file_path                   //denotes the file path for the chunk parent. (index table here)
  #     :worker_id                 //denotes the id of the worker node where the chunk is stored
  #     :replica_number        //denotes the replica number of the chunk
  #     :hash_value              //denotes the hash value of the chunk
  # """
  defp create_chunk_table(node_list) do
    Mnesia.create_table(
      Chunk_Table,
      [
        attributes: [:chunk_id, :sequence_id, :append_list, :file_path, :worker_id, :replica_number, :hash_value],
        disc_copies: node_list,
        index: [:file_path]
      ]
    )
  end


  # @doc """
  #   File access table
  #   Used to check file existence, etc (basically ease of access)
  #     :id  [PK]                    // denotes id as the PK
  #     :folder_path             // denotes path of the parent folder (index here)
  #     :file_name               // denotes file name
  #     :file_size                 // denotes the file size
  #     :type                       // denotes whether file or folder
  # """
  defp create_file_access_table(node_list) do
    Mnesia.create_table(
      File_Access_Table,
      [
        attributes: [:id, :folder_path, :file_name, :file_size, :type],
        disc_copies: node_list,
        index: [:folder_path]
      ]
    )
  end


  # @doc """
  #   Worker table
  #   Has details about the workers
  #     :worker_id
  #     :space_remaining
  #     :space_used
  #     :ram_size
  # """
  defp create_worker_table(node_list) do
    Mnesia.create_table(
      Worker_Table,
      [
        attributes: [:worker_id, :space_remaining, :space_used, :ram_size],
        disc_copies: node_list
      ]
    )
  end



  # @doc """
  #   ID Table
  #   Maintains count of the file access table for easy update of ID in FileAccessTable
  #     :file_access_table_id
  # """
  def create_id_table(node_list) do
    Mnesia.create_table(
      ID_Table,
      [
        attributes: [:id, :file_access_table_id],
        disc_copies: node_list
      ]
    )
  end


  @doc """
    Checks if transaction was successful and creates a generic response for any behaviour
    Takes as input, output of a transaction
  """
  def check_transactions(trans) do
    case trans do
      {:atomic, :ok} ->
        {:ok, :write_successful}
      {:atomic, read_value} ->
        {:ok, :read_successful, read_value}
      {:aborted, reason} ->
        {:error, reason}
    end
  end


  def transaction_wrapper(function) do
    Mnesia.transaction(function) |> check_transactions()
  end

end
