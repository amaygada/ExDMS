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
  def rm_operation(_parent_folder_path, _file_name) do
    {:idle, "To be implemented"}
  end


  @doc """
    mimics the UNIX operation "rm"
      Only works for files
      To remove folders, use the command "rmr"

      Checks if file exists, if it does, removes it from the database
  """
  def rmr_operation(_parent_folder_path, _file_name) do
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


  @doc """
    mimics the hadoop command cpFromLocal
    Pushes a local file in the client machine to the DFS
  """
  def cpFromLocal_operation(rest, socket) do
    #check which workers are alive, and get the space in each alive worker in descending order
    node_list = Network.Config.get_node_list()
    node_reverse_map = Network.Config.get_reverse_node_map()
    worker_list= Master.Operations.populate_worker_map(node_list, node_reverse_map, [])

    #check if dfs path is a valid file
    [file_size, dfs_path_parent, dfs_path_file] = rest
    case Database.FileAccess.does_file_exist([folder_path: dfs_path_parent, file_name: dfs_path_file]) do
      {:ok, _, [file_details | _]} ->
        {File_Access_Table, _, _, _, size, _} = file_details
        case size do
          0 ->
            #extract file size from command
            {file_size, _} = Integer.parse(file_size)
            #Apply the chunk allocation algorithm
            num_replicas = Master.Config.get_replication_factor()
            chunk_size = Master.Config.get_chunk_size()
            a = chunk_allocation_algo(worker_list, file_size, num_replicas, chunk_size)
            case a do
              {:ok, reply} ->
                {File_Access_Table, id, folder, file, _, type} = file_details
                Database.FileAccess.update_file_record([id: id, folder_path: folder, file_name: file, file_size: file_size, type: type])
                {:ok, reply}
              {:error, reason} ->
                {:error, reason}
            end
          _ ->
            {:error, "This file path is full already. To override it, please delete the file using rm first"}
        end
      {:error, _} ->
        {:error, "Invalid DFS path"}
    end
  end


  @doc """
    mimics the hadoop command cpToLocal
    Downloads a DFS file into local machine
  """
  def cpToLocal_operation(rest, socket) do
    [_, dfs_path_parent, dfs_path_file] = rest
    case Database.FileAccess.does_file_exist([folder_path: dfs_path_parent, file_name: dfs_path_file]) do
      {:ok, _, [file_details | _]} ->
        {File_Access_Table, _, _, _, size, _} = file_details
        case size do
          0 ->
            {:error, "This dfs file path is empty. Cannot download from an empty file."}
          _ ->
            create_file_read_plan(size, dfs_path_parent<>dfs_path_file)
        end
      {:error, _} ->
        {:error, "Invalid DFS path"}
    end
  end


  ################################################################################################################################################
  # HELPER FUNCTIONS FOR OPERATIONS WILL BE DEFINED HERE

  defp loop_sequences([], _, _, _, plan_map, _), do: {:ok, plan_map}
  defp loop_sequences([h|rest], {[],[]}, queue_copy, dfs_path, plan_map, count) do
    case count do
      0 ->
        loop_sequences([h|rest], queue_copy, queue_copy, dfs_path, plan_map, count+1)
      1 ->
        {:error, "Cannot find the whole file in the available workers"}
    end
  end
  defp loop_sequences([h|rest], worker_queue, queue_copy, dfs_path, plan_map, count) do
    w = case worker_queue do
      {[w], []} ->
        w
      {_, [w]} ->
        w
      _ ->
        {:error, "queue empty error"}
    end
    case Database.Chunk.read_file_in_sequence([sequence_id: h, file_path: dfs_path, worker_id: w]) do
      {:ok, _, []} ->
        #seq not found in worker, check in another worker
        {_, worker_queue} = :queue.out(worker_queue)
        loop_sequences([h|rest], worker_queue, queue_copy, dfs_path, plan_map, count)
      {:ok, _, [file]} ->
        #seq found, add in plan, find next sequence with the same worker
        plan_map = case plan_map[w] do
          nil ->
            Map.put(plan_map, w, [h])
          l ->
            Map.put(plan_map, w, l++[h])
        end
        loop_sequences(rest, worker_queue, queue_copy, dfs_path, plan_map, count)
    end
  end

  def compress_list([h | []], list) do
    Enum.sort(list, fn [h1|_], [h2|_] ->
      cond do
        h1<h2 ->
          true
        true ->
          false
        end
      end
    )
  end
  def compress_list([h | [h1 | rest]], list) do
    case list do
      [] ->
        list = list++[[h,h]]
        compress_list([h | [h1 | rest]], list)
      _ ->
        list = cond do
          h+1==h1 ->
            [lh | lrest] = list
            [a,b] = lh
            list = [[a,h1] | lrest]
            compress_list([h1 | rest], list)
          true ->
            list = [[h1,h1] | list]
            compress_list([h1 | rest], list)
        end
    end
  end
  defp compress_plan(plan, []), do: plan
  defp compress_plan(plan, [h | rest]) do
    plan = Map.put(plan, h, compress_list(plan[h], []))
    compress_plan(plan, rest)
  end

  defp create_queue_from_list([], q), do: q
  defp create_queue_from_list([h | rest], q) do
    {w, _} = h
    create_queue_from_list(rest, :queue.in(w, q))
  end

  def create_file_read_plan(file_size, dfs_path) do
    #check which workers are alive
    node_list = Network.Config.get_node_list()
    node_reverse_map = Network.Config.get_reverse_node_map()
    worker_list = Master.Operations.populate_worker_map(node_list, node_reverse_map, [])
    worker_queue = create_queue_from_list(worker_list, :queue.new)

    #find total blocks in file
    chunk_size = Master.Config.get_chunk_size()
    num_blocks = file_size/chunk_size
    num_blocks = cond do
      num_blocks==trunc(num_blocks) ->
        trunc(num_blocks)
      true ->
        trunc(num_blocks) + 1
      end

    #find which workers have which sequences
    a = loop_sequences(Enum.to_list(1..num_blocks), worker_queue, worker_queue, dfs_path, %{}, 0)
    case a do
      {:ok, plan} ->
        {:ok, compress_plan(plan, Map.keys(plan))}
      {:error, r} ->
        {:error, r}
    end
  end


  @doc """
  Function to populate a list of tuples
  {worker_id, space_remaining_in_worker}
  """
  def populate_worker_map([], _node_reverse_map, worker_list) do
    #sort worker_list in descending order
    Enum.reverse(List.keysort(worker_list, 1))
  end
  def populate_worker_map(node_list, node_reverse_map, worker_list) do
    [h|rest] = node_list
    case node_reverse_map[h] do
      "master" ->
        populate_worker_map(rest, node_reverse_map, worker_list)
      _ ->
        case Network.Helper.check_alive(h) do
          {:ok, _alive} ->
            populate_worker_map(rest, node_reverse_map, [{node_reverse_map[h], Database.WorkerTable.get_space_remaining([worker_id: node_reverse_map[h]])}|worker_list])
          {:error, _} ->
            IO.puts(IO.ANSI.red() <> node_reverse_map[h] <> " DOWN" <> IO.ANSI.reset())
            populate_worker_map(rest, node_reverse_map, worker_list)
        end
    end
  end

  #Client.StateServer.send_message("cpFromLocal aa aa")
  defp resize_worker_list([], _, new_list, tot), do: {new_list, tot}
  defp resize_worker_list([{worker_id, space}|rest], file_size, new_list, tot) do
    {new_list, tot} = cond do
      space>file_size ->
        {new_list++[{worker_id, file_size}], tot+file_size}
      true ->
        {new_list++[{worker_id, space}], tot+space}
    end
    resize_worker_list(rest, file_size, new_list, tot)
  end

  #populate queue fr the chunk allocation algorithm
  defp populate_queue(worker_list, queue) do
    case worker_list do
      [{a,sa},{b,sb},{c,sc}] ->
        queue = :queue.in(a<>" "<>b,queue)
        queue = :queue.in(a<>" "<>c,queue)
        queue = :queue.in(b<>" "<>c,queue)
        {
          queue,
          %{a<>" "<>b => 0, a<>" "<>c => 0, b<>" "<>c => 0, "trail" => 0},
          %{a => sa, b => sb, c => sc}
        }
      [{a,sa},{b,sb}] ->
        queue = :queue.in(a<>" "<>b,queue)
        {
          queue,
          %{a<>" "<>b => 0, "trail" => 0},
          %{a => sa, b => sb}
        }
    end
  end

  defp loop_queue(_, combination_map, _, 0, _) do
    IO.inspect(combination_map)
    {:ok, combination_map}
  end
  defp loop_queue(queue, combination_map,worker_map, file_size, chunk_size) when file_size<chunk_size do
    {{:value, head}, queue} = :queue.out(queue)
    [a, b] = String.split(head, " ")
    cond do
      worker_map[a]>=file_size ->
        cond do
          worker_map[b]>=file_size ->
            combination_map = %{combination_map | "trail" => a<>" "<>b<>" "<>Kernel.inspect(file_size)}
            loop_queue(queue, combination_map, worker_map, 0, chunk_size)
          true ->
            loop_queue(queue, combination_map, worker_map, file_size, chunk_size)
        end
      true ->
        loop_queue(queue, combination_map, worker_map, file_size, chunk_size)
    end
  end
  defp loop_queue({[],[]}, _,_,_,_) do
    {:error, "chunk size is too large to divide the remaining file. Please reduce chunk size to store the file."}
  end
  defp loop_queue(queue, combination_map, worker_map, file_size, chunk_size) do
    {{:value, head}, queue} = :queue.out(queue)
    queue = :queue.in(head, queue)
    [a, b] = String.split(head, " ")
    cond do
      worker_map[a]>=chunk_size ->
        cond do
          worker_map[b]>=chunk_size ->
            combination_map = %{combination_map | head => combination_map[head]+1}
            worker_map = %{worker_map | a => worker_map[a]-chunk_size}
            worker_map = %{worker_map | b => worker_map[b]-chunk_size}
            loop_queue(queue, combination_map, worker_map, file_size-chunk_size, chunk_size)
          true ->
            loop_queue(queue, combination_map, worker_map, file_size, chunk_size)
        end
      true ->
        loop_queue(queue, combination_map, worker_map, file_size, chunk_size)
    end
  end


  defp create_plan(worker_list, file_size, chunk_size) do
    {queue, combination_map, worker_map} = populate_queue(worker_list, :queue.new)
    loop_queue(queue, combination_map, worker_map, file_size, chunk_size)
  end

  def chunk_allocation_algo(worker_list, file_size, num_replicas, chunk_size) do
    # resize remaining space in worker list according to file size
    {worker_list, tot} = resize_worker_list(worker_list, file_size, [], 0)
    cond do
      length(worker_list) == 0 ->
        {:error, "No workers available"}
      length(worker_list) == 1 ->
        {:error, "Can't store 2 replicas in 1 available worker. Change replication factor to 1"}
      tot >= num_replicas*file_size ->
        create_plan(worker_list, file_size, chunk_size)
      true ->
        {:error, "Not enough space to store this file in the DFS"}
    end
  end

end
