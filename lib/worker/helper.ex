# defmodule Worker.Helper do

#   @doc """
#   Sends write requests to other workers
#   """
#   defp send_to_worker(h, data, gentcp_socket) do
#     case :ets.lookup(:connections, h) do
#       [] ->
#         # IO.inspect("Connecting new")
#         {:ok, socket} = DynamicSupervisor.start_child(Worker.DynamicTCPSupervisor, Worker.SocketServer)
#         Worker.SocketServer.connect(socket, Network.Config.get_port_map()[h], Network.Config.get_ip_map()[h])
#         :ets.insert(:connections, {h, socket})
#         Worker.SocketServer.send_message(socket, Jason.encode!(data))
#         #wait for acknowledgement
#         a = Worker.SocketServer.async_recv_handler(socket)
#         #Writes acknowledgement to the process before it
#         #WRITE HERE
#         write_line("recv "<>Kernel.inspect(data["seq"])<>"delim", gentcp_socket)

#       [{_, socket}] ->
#         # IO.inspect("Found connection")
#         reply = Worker.SocketServer.send_message(socket, Jason.encode!(data))
#         case reply do
#           {:ok, :sent} ->
#             #wait for acknowledgement
#             a = Worker.SocketServer.async_recv_handler(socket)
#             #Writes acknowledgement to the process before it
#             write_line("recv "<>Kernel.inspect(data["seq"])<>"delim",gentcp_socket)
#           {:error, _} ->
#             {:ok, socket} = DynamicSupervisor.start_child(Worker.DynamicTCPSupervisor, Worker.SocketServer)
#             Worker.SocketServer.connect(socket, Network.Config.get_port_map()[h], Network.Config.get_ip_map()[h])
#             :ets.insert(:connections, {h, socket})
#             Worker.SocketServer.send_message(socket, Jason.encode!(data))
#             #wait for acknowledgement
#             a = Worker.SocketServer.async_recv_handler(socket)
#             #Writes acknowledgement to the process before it
#             write_line("recv "<>Kernel.inspect(data["seq"])<>"delim", gentcp_socket)
#         end
#     end
#   end

#   @doc """
#     Writes data to worker and cascades to the next worker in the cascade list
#   """
#   defp write_and_cascade(gentcp_socket, %{"type" => "write", "data" => data, "seq" => seq, "cascade_list" => [h | rest], "replica" => replica, "dfs_path" => dfs_path}) do
#     #created chunk_id
#     {a,b,c} = :os.timestamp
#     chunk_id = Kernel.inspect(a)<>" "<>Kernel.inspect(b)<>" "<>Kernel.inspect(c)

#     #write data to file: chunk_id.txt
#     worker = Network.Config.get_reverse_node_map()[node()]
#     path = "data/"<>worker<>"/"<>chunk_id<>".txt"
#     File.write(path, data)

#     #Add chunk data to mnesia
#     #TRANSACTION HERE
#     Database.Chunk.write_to_chunk([chunk_id: chunk_id, sequence_id: seq, file_path: dfs_path, worker_id: worker, replica_number: replica, hash_value: ""])

#     #cascade the request to next worker
#     case h do
#       "end" ->
#         #send response to previous worker
#         #SEND RESPONSE HERE
#         write_line("recv "<>Kernel.inspect(seq)<>"delim", gentcp_socket)
#         1+1
#       _ ->
#         send_to_worker(h, %{"type" => "write", "data" => data, "seq" => seq, "cascade_list" => rest, "replica" => replica+1, "dfs_path" => dfs_path}, gentcp_socket)
#     end
#   end
# end
