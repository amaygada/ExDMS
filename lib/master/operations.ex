defmodule Master.Operations do

  @moduledoc """
    This module defines all the unix operations that the client may request
    Eg. cmd operations like
     - cd, ls, mkdir, cp, mv, etc.

    Operations are divided into two categories
      - Most operations can be performed on the virtual directory hierarchy defined in the FileAccessTable
        Hence, a master node access is enough
      - Some operations will need accessing the worker nodes for file access
        This will demand a tcp connection to the worker nodes
  """


  @doc """
    mimics the UNIX command "ls"
      Checks if path exists
      If exists, prints path contents in different colours depending on file or folder
  """
  def ls_operation(parent_folder_path) do
    case Database.FileAccess.does_folder_exist([folder_path: parent_folder_path]) do
      {:ok, "folder exists", _} ->
        {:ok, :read_successful, ls_list} = Database.FileAccess.get_all_files_in_folder([folder_path: parent_folder_path])
        out = ""
        out = Enum.map(
          ls_list, fn l ->
            o = case l do
              {_, _, _, "", _, _} ->
                ""
              {_, _, _, name, _, "file"} ->
                name<>"   "
              {_, _, _, name, _, "folder"} ->
                name<>"/"<>"   "
            end
            out<>o
          end
        )
        {:ok, Enum.join(out, "")}
      {:error, "folder doesn't exist"} ->
        {:error, "invlaid path"}
    end
  end


  @doc """
    mimics the UNIX command "touch"
      Checks if file exists in the given path
      If it doesn't, then creates a file in the desired path
  """
  def touch_operation(_parent_folder_path, "") do
    {"error", "file name can't be empty"}
  end
  def touch_operation(parent_folder_path, file_name) do
    # make sure that the parent_folder_path ends with a "/" and file name has no "/"
    # IO.inspect(parent_folder_path)
    case Database.FileAccess.does_file_exist([folder_path: parent_folder_path, file_name: file_name]) do
      {:ok, "file exists", _} ->
        {:error, "file with this name already exists"}
      {:error, "file doesn't exist"} ->
        case Database.FileAccess.does_folder_exist([folder_path: parent_folder_path]) do
          {:ok, "folder exists", _} ->
            Database.FileAccess.write_to_file_access_table(
              [folder_path: parent_folder_path, file_name: file_name, file_size: 0, type: "file"])
            {:ok, "write_successful"}
          {:error, "folder doesn't exist"} ->
            {:error, "invalid path"}
        end
    end
  end


  @doc """
    mimcs the UNIX command "mkdir"
      check if folder exists
      If it doesn't write to DB
      Else deny write
  """
  def mkdir_operation(_parent_folder_path, "") do
    {"error", "folder name can't be empty"}
  end
  def mkdir_operation(parent_folder_path, folder_name) do
    # make sure that the parent_folder_path ends with a "/" and folder name has no "/"
    case Database.FileAccess.does_folder_exist([folder_path: parent_folder_path<>folder_name<>"/"]) do
      {:ok, "folder exists", _} ->
        {:error, "folder already exists"}
      {:error, "folder doesn't exist"} ->
        case Database.FileAccess.does_folder_exist([folder_path: parent_folder_path]) do
          {:ok, "folder exists", _} ->
            Database.FileAccess.write_to_file_access_table(
              [folder_path: parent_folder_path, file_name: folder_name, file_size: 0, type: "folder"])
            Database.FileAccess.write_to_file_access_table(
              [folder_path: parent_folder_path<>folder_name<>"/", file_name: "", file_size: 0, type: "folder"])
            {:ok, "write_successful"}
          {:error, "folder doesn't exist"} ->
            {:error, "invalid path"}
        end
    end
  end


  @doc """
    mimics the UNIX command "cd"
  """
  def cd_operation(parent_folder_path) do
    # IO.inspect(parent_folder_path)
    case Database.FileAccess.does_folder_exist([folder_path: parent_folder_path]) do
      {:ok, "folder exists", _} ->
        {:ok, parent_folder_path}
      {:error, "folder doesn't exist"} ->
        {:error, "invlaid path"}
    end
  end


  @doc """
    mimics the UNIX operation "rm"
      Only works for files
      To remove folders, use the command "rmr"

      Checks if file exists, if it does, removes it from the database
  """
  def rm_operation(parent_folder_path, file_name) do
    {:idle, "To be implemented"}
  end


  @doc """
    mimics the UNIX operation "rm"
      Only works for files
      To remove folders, use the command "rmr"

      Checks if file exists, if it does, removes it from the database
  """
  def rmr_operation(parent_folder_path, file_name) do
    {:idle, "To be implemented"}
  end


  @doc """
    mimics the UNIX command "mv"
  """
  def mv_operation() do
    {:idle, "To be implemented"}
  end


  @doc """
    mimics the UNIX command "cp"
  """
  def cp_operation(_from_parent_folder_path, _from_file_name, _to_parent_folder_path, _to_file_name) do
    {:idle, "To be implemented"}
  end

end
