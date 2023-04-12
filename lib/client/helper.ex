defmodule Client.Helper do
  @moduledoc """
  This module contains helper functions used by the State server to run operations
  """

  def get_file_size(path) do
    case File.stat path do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_worker_sets(_, []) do
    {:ok, "write done"}
  end
  defp parse_worker_sets(plan_map, ["trail" | rest]=kay_list) do
    parse_worker_sets(plan_map, rest)
  end
  defp parse_worker_sets(plan_map, [h | rest] = key_list) do
    [a,b] = String.split(h)
    # Connect client to a, send b to a so that a can connect with b
    Client.SocketServer.connect(Network.Config.get_port_map()[a], Network.Config.get_ip_map()[a])
    Client.SocketServer.send_message("Connect_Worker "<>b)
  end

  @doc """
  Finds unique workers in the worker map
  """
  defp find_unique_workers([], set) do
    MapSet.to_list(set)
  end
  defp find_unique_workers(["trail" | rest], set) do
    find_unique_workers(rest, set)
  end
  defp find_unique_workers([h|rest], set) do
    [a,b] = String.split(h)
    set = MapSet.put(set, a)
    set = MapSet.put(set, b)
    find_unique_workers(rest, set)
  end

  @doc """
  Connects to all workers in the write plan for easier parallel communication
  """
  defp connect_to_all_workers([], map), do: map
  defp connect_to_all_workers([h|rest], map) do
    {:ok, socket} = DynamicSupervisor.start_child(Client.DynamicTCPSupervisor, Client.SocketServer)
    Client.SocketServer.connect(socket, Network.Config.get_port_map()[h], Network.Config.get_ip_map()[h])
    connect_to_all_workers(rest, Map.put(map, h, socket))
  end

  @doc """
  Expands plan map into a list for easy async writes
  """
  defp expand_plan(plan_map, [], list) do
    case plan_map["trail"] do
      0 ->
        list
      _ ->
        [a, b, _] = String.split(plan_map["trail"])
        list++[a<>" "<>b]
    end
  end
  defp expand_plan(plan_map, ["trail" | rest], list), do: expand_plan(plan_map, rest, list)
  defp expand_plan(plan_map, [h | rest], list) do
    expand_plan(plan_map, rest, list++List.duplicate(h, plan_map[h]))
  end

  @doc """
  This function is executed parallelly by the task initiallized in async_write_loop
  """
  defp write(seq, socket, list, data, dfs_path) do
    chunk_size = Client.Config.get_chunk_size()
    # data = "short data"
    # IO.inspect(seq)
    #send data and seq to the worker along with the cascade list
    map = %{"type" => "write", "data" => data, "seq" => seq, "cascade_list" => list, "replica" => 1, "dfs_path" => dfs_path}
    # IO.inspect(map)
    Client.SocketServer.write_operation(socket, Jason.encode!(map))
    #wait for acknowledgement
    {:ok, msg} = Client.SocketServer.async_recv_handler(socket)
    [_, seq] = String.split(msg)
    :ets.insert(:acknowledgement_checker, {seq, true})
  end


  @doc """
    This function loops and checks if all acknowldgements have been received
  """
  defp ack_loop([], count), do: count
  defp ack_loop([h | rest], count) do
    case :ets.lookup(:acknowledgement_checker, Kernel.inspect(h)) do
      [] ->
        ack_loop(rest, count)
      [{_, true}] ->
        ack_loop(rest, count+1)
    end
  end
  def check_ack(num_blocks) do
    count = ack_loop(Enum.to_list(1..num_blocks), 0)
    cond do
      count == num_blocks ->
        :ets.delete(:acknowledgement_checker)
        true
      true ->
        :timer.sleep(50)
        check_ack(num_blocks)
    end
  end


  defp shutdown_connections(map), do: Enum.each(map, fn {_k,v} -> Client.SocketServer.graceful_shutdown(v) end)

  @doc """
  Defines steps to write data to workers
  """
  def write_data(plan_map, file_size, local_file_path, dfs_path) do
    case :ets.whereis(:acknowledgement_checker) do
      :undefined ->
        :ets.new(:acknowledgement_checker, [:named_table, :public, read_concurrency: true])
      _ ->
        :null
    end
    unique_worker_list = find_unique_workers(Map.keys(plan_map), MapSet.new())
    socket_map = connect_to_all_workers(unique_worker_list, %{})
    plan = expand_plan(plan_map, Map.keys(plan_map), [])
    f = File.stream!(local_file_path, [], Client.Config.get_chunk_size())
    s = Stream.zip([f,plan, Enum.to_list(1..length(plan))])
    s = Stream.map(
      s,
      fn {data, h, seq} ->
        [a,b] = String.split(h)
        Task.Supervisor.start_child(Client.WriteTaskSupervisor, fn -> write(seq, socket_map[a], [b, "end"], data, dfs_path) end)
        # write(seq, socket_map[a], [b, "end"], data, dfs_path)
      end
    )
    Stream.run(s)

    #write an async service that checks if all packages have been received
    task = Task.async(fn -> check_ack(length(plan)) end)
    Task.await(task)
    #shutdown all open connections
    task = Task.async(fn -> shutdown_connections(socket_map) end)
    {:write_complete}
  end

  defp find_inner(_, []), do: {:loop}
  defp find_inner(seq, [[s,e] | rest]) do
    cond do
      s == seq ->
        {:ok, s, e}
      true ->
        find_inner(seq, rest)
    end
  end
  defp find_seq_in_plan(seq, _, []), do: {:error, "couldn't find"}
  defp find_seq_in_plan(seq, plan_map, [h | rest]) do
    case find_inner(seq, plan_map[h]) do
      {:ok, s, e} ->
        {s,e,h}
      {:loop} ->
        find_seq_in_plan(seq, plan_map, rest)
    end
  end


  def read_and_append(f, seq, plan_map, socket_map, dfs_path) do
    #find seq in plan_map
    case find_seq_in_plan(seq, plan_map, Map.keys(plan_map)) do
      {start_index, end_index, worker} ->
        map = %{"type" => "read sequential", "start" => start_index, "end" => end_index, "dfs_path" => dfs_path}
        Client.SocketServer.read_seq_operation(socket_map[worker], Jason.encode!(map))
        Enum.each(Enum.to_list(start_index..end_index),
          fn x ->
            #receive data here and append to file here
            reply = Client.SocketServer.recv_message(socket_map[worker])
            case reply do
              {:ok, data} ->
                case Parser.Parse.parse_worker_response(data) do
                  {:ok, d} ->
                    # IO.inspect({"Writing: ", x})
                    IO.write(f, Jason.decode!(d))
                  {:error, e} ->
                    IO.inspect({"Error in reading sequence ", x})
                end
            end
          end
        )
        read_and_append(f, end_index+1, plan_map, socket_map, dfs_path)
      {:error, _} ->
        {:ok, "read finish"}
    end
  end

  def read_files_sequentially(plan_map, local_path, dfs_path) do
    #connect to all workers present in plan_map
    socket_map = connect_to_all_workers(Map.keys(plan_map), %{})

    #create a file with path "local_path"
    File.touch(local_path)
    {:ok, f} = File.open(local_path, [:write, :utf8])

    #start reading files from workers
    read_and_append(f, 1, plan_map, socket_map, dfs_path)
  end



end



# Client.StateServer.send_message("cpFromLocal test.txt abcd")
#:mnesia.dirty_write({File_Access_Table, 4, "/fold/", "file", 0, "file"})
