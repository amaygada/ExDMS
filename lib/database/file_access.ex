defmodule Database.FileAccess do

  @moduledoc """
    File access table
    Used to check file existence, etc (basically ease of access)
      :id  [PK]                // denotes id as the PK
      :folder_path             // denotes path of the parent folder (index here)
      :file_name               // denotes file name
      :file_size               // denotes the file size in bytes
      :type                    // denotes whether file or folder

    This module defines helper functions for the File_Access_Table

    HELPER RULES FOR EASY ASSUMPTIONS
      - All paths will end with a '/' if it is a folder path, otherwise, it won't end in a '/' (file)
  """

  alias :mnesia, as: Mnesia


  @doc """
    Writes to File Access Table and autoincrements the Primary Key: ID
    Takes as input, a keyword list of all attributes except ID
    Eg. write_to_file_access_table([folder_path: "/home/folder1", file_name: "b.txt", file_size: 0, type: "folder"])
  """
  def write_to_file_access_table(attributes) do
    id = Database.ID.get_id()

    case id do
      {:ok, i} ->
        trans = Mnesia.transaction(
          fn ->
            Mnesia.write(
              {
                File_Access_Table,
                i,
                attributes[:folder_path],
                attributes[:file_name],
                attributes[:file_size],
                attributes[:type]
              }
            )
          end
        ) |> Database.Init.check_transactions()
        case trans do
          {:error, _} ->
            trans
          {:ok, _} ->
            Database.ID.write_to_id(i+1)
        end
      _ ->
        {:error, "ID error while writing to File Access Table"}
    end
  end


  @doc """
    Given existing file details, this function updates file record in mnesia
  """
  def update_file_record(attributes) do
    trans = Mnesia.transaction(
      fn ->
        Mnesia.write(
              {
                File_Access_Table,
                attributes[:id],
                attributes[:folder_path],
                attributes[:file_name],
                attributes[:file_size],
                attributes[:type]
              }
            )
      end
    ) |> Database.Init.check_transactions()
  end

  @doc """
    Given Folder Path, this function returns all the files in it
    Takes as input Folder Path
  """
  def get_all_files_in_folder(attributes) do
    Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            File_Access_Table,
            :_, attributes[:folder_path], :_, :_, :_ }
          )
      end
    ) |> Database.Init.check_transactions()
  end


  @doc """
    Checks if file exists
    Takes as input parent folder path and file name
  """
  def does_file_exist(attributes) do
    trans = Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            File_Access_Table,
            :_, attributes[:folder_path], attributes[:file_name], :_, "file"}
          )
      end
    ) |> Database.Init.check_transactions()

    case trans do
      {:ok, :read_successful, []} ->
        {:error, "file doesn't exist"}
      {:ok, :read_successful, files} ->
        {:ok, "file exists", files}
      _ ->
        trans
    end
  end


  @doc """
    Checks if folder exists
    Takes as input folder path
  """
  def does_folder_exist(attributes) do
    trans = Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            File_Access_Table,
            :_, attributes[:folder_path], :_, :_, "folder"}
          )
      end
    ) |> Database.Init.check_transactions()

    case trans do
      {:ok, :read_successful, []} ->
        {:error, "folder doesn't exist"}
      {:ok, :read_successful, folders} ->
        {:ok, "folder exists", folders}
      _ ->
        trans
    end
  end


  @doc """
    Checks if path is valid
    Takes as input folder path
  """
  def is_path_valid(attributes) do
    trans = Mnesia.transaction(
      fn ->
        Mnesia.match_object(
          {
            File_Access_Table,
            :_, attributes[:folder_path], attributes[:file_name], :_, :_}
          )
      end
    ) |> Database.Init.check_transactions()

    case trans do
      {:ok, :read_successful, []} ->
        {:error, "doesn't exist"}
      {:ok, :read_successful, files} ->
        {:ok, "exists", files}
      _ ->
        trans
    end
  end


  @doc """
    Gets all files/folders with given path
    Performs a match without the transactional wrapper
  """
  def get_path_contents(attributes) do
    Mnesia.match_object({File_Access_Table, :_, attributes[:folder_path], attributes[:file_name], :_, :_})
  end


  @doc """
    Writes to file access table without the transactional wrapper
  """
  def write_file_access_table_without_trans(attributes, id) do
    Mnesia.write({File_Access_Table, id, attributes[:folder_path], attributes[:file_name], attributes[:file_size], attributes[:type] })
  end

end
