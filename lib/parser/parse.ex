defmodule Parser.Parse do

  @moduledoc """
    Module to parse all requests based on the assumption rules

    Requests are UNIX commands
  """

  def split_string(cmd) do
    [h|rest] = String.split(cmd)
    {h,rest}
  end

  def isolate_command(h, rest) do
    case h do
      "ls" ->
        {:ls, rest}
      "mkdir" ->
        {:mkdir, rest}
      "touch" ->
        {:touch, rest}
      "cd" ->
        {:cd, rest}
      "pwd" ->
        {:pwd, rest}
      "cpFromLocal" ->
        {:cpFromLocal, rest}
      "cpToLocal" ->
        {:cpToLocal, rest}
      _ ->
        {:invalid}
    end
  end

  @doc """
    Builds a command if given in short form
      - If it starts with a /, then we know it is a full path
      - If it starts with a ./, We have to remove the ./ and add the current directory path there
      - If it starts with none of them, then we have to add current directory path before the command
      - MAKE SURE THAT THE PATH DOESN'T END IN A '/'
  """
  def build(cmd, cd) do
    cmd = cond do
      String.slice(cmd, 0..0) == "/" ->
        cmd
      String.slice(cmd, 0..1) == "./" ->
        cd<>String.slice(cmd, 2..-1)
      true ->
        cd<>cmd
    end

    cond do
      cmd == "/" ->
        "/"
      String.slice(cmd, -1..-1) == "/" ->
        String.slice(cmd, 0..-2)
      true ->
        cmd
    end

  end


  @doc """
    Extracts parent folder and child folder/file from path
  """
  def extract_parent_child_from_path(cmd, cd) do
    cmd = build(cmd, cd)
    len = String.length(cmd)
    file = List.last(String.split(cmd, "/"))
    parent_path = String.slice(cmd, 0..len-String.length(file)-1)
    {parent_path, file}
  end


  # @doc """
  #   Handles invalid commands
  # """
  def break({:invalid}) do
    {:error, "command not found"}
  end

  # @doc """
  #   Handles the ls command
  #   checks number of params (should be only one string path) => If more than 1, connect all using space
  # """
  def break({:ls, rest, cd}) do
    case rest do
      [] ->
        {:ok, build(cd,cd)}
      _ ->
        [h|_] = rest
        {:ok, build(h, cd)}
    end
  end

  # @doc """
  #   Handles the touch command
  # """
  def break({:touch, rest, cd}) do
    case rest do
      [] ->
        {:error, "No file path mentioned"}
      _ ->
        [h|_] = rest
        {:ok, extract_parent_child_from_path(h, cd)}
    end
  end

  # @doc """
  #   Handles the mkdir command
  # """
  def break({:mkdir, rest, cd}) do
    case rest do
      [] ->
        {:error, "No file path mentioned"}
      _ ->
        [h|_] = rest
        {:ok, extract_parent_child_from_path(h, cd)}
    end
  end

  # @doc """
  #   Handles the cd command
  # """
  def break({:cd, rest, cd}) do
    case rest do
      [] ->
        {:error, "No file path mentioned"}
      _ ->
        [h|_] = rest
        case h do
          ".." ->
            case cd do
              "/" ->
                {:ok, "/"}
              _ ->
                {p, _} = extract_parent_child_from_path(cd, cd)
                {:ok, p}
            end
          _ ->
            {:ok, build(h, cd)}
        end
    end
  end

  @doc """
    Handles the copyFromLocal command
    cpFromLocal local_path dfspath
  """
  def break({:cpFromLocal, rest, cd}) do
    case rest do
      [local_path, dfs_path] ->
        {:ok, local_path, extract_parent_child_from_path(dfs_path, cd)}
      _ ->
        {:error, "cpFromLocal takes 2 arguments: local_path, dfs_path"}
    end
  end

  @doc """
    Handles the copyToLocal command
    cpFromLocal local_path dfspath
  """
  def break({:cpToLocal, rest, cd}) do
    case rest do
      [local_path, dfs_path] ->
        {:ok, local_path, extract_parent_child_from_path(dfs_path, cd)}
      _ ->
        {:error, "cpToLocal takes 2 arguments: local_path, dfs_path"}
    end
  end


  def parse(cmd) do
    {h, rest} = split_string(cmd)
    isolate_command(h, rest)
  end

  def parse_response(resp) do
    resp = :erlang.iolist_to_binary(resp)
    [h | _] = String.split(resp)
    case h do
      "ok" ->
        {:ok, String.slice(resp, 3..-3)}
      "error" ->
        {:error, String.slice(resp, 6..-3)}
    end
  end

  def parse_worker_response(resp) do
    resp = :erlang.iolist_to_binary(resp)
    [h | _] = String.split(resp)
    case h do
      "ok" ->
        {:ok, String.slice(resp, 3..-1)}
      "error" ->
        {:error, String.slice(resp, 6..-1)}
    end
  end

end
