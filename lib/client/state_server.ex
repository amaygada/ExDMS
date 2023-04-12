defmodule Client.StateServer do

  @moduledoc """
    This is a Genserver to monitor the state for the client
  """

  use GenServer

  @doc """
    Starts the GenServer
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end


  @doc """
    Initializes the State Server with the initial state
    %{
      "current_directory" => "/home/",
      "base_directory" => "/home/",
      "master_ip" => Network.Config.get_master_ip(),
      "port" => Network.Config.get_port(),
      "socket_id" => ""
    }
  """
  @impl true
  def init(:ok) do

    master_ip = Network.Config.get_master_ip()
    port = Network.Config.get_port()

    init_state = %{
      "current_directory" => "/",
      "base_directory" => "/",
      "master_ip" => master_ip,
      "port" => port,
      "socket" => "",
      "worker_socket" => %{"workera" => "", "workerb" => "", "workerc" => ""}
    }
    {:ok, init_state}
  end


  @impl true
  def handle_info(msg, state) do
    {:noreply, state}
  end


  @doc """
    Connects to the TCP socket
  """
  @impl true
  def handle_call({:connect}, _from, state) do
    connect = :gen_tcp.connect(state["master_ip"], state["port"], [active: false])
    case connect do
      {:ok, socket} ->
        state = %{state | "socket" => socket}
        {:reply, {:ok, socket}, state}
      _ ->
        {:reply, {:error, connect}, state}
    end
  end


  @impl true
  def handle_call({:send_tcp, message}, _from, state) do
    reply = :gen_tcp.send(state["socket"], message<>"\n")
    case reply do
      :ok ->
        {:reply, {:ok, :sent}, state}
      _ ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
        {:reply, {:error, reply}, state}
    end
  end


  @impl true
  def handle_call({:send_tcp, :ls, rest}, _from, state) do
    case Parser.Parse.break({:ls, rest, state["current_directory"]}) do
      {:ok, path} ->
        reply = :gen_tcp.send(state["socket"], "ls "<>path<>"\n")
        case reply do
          :ok ->
            case receive_message(state["socket"]) do
              {:ok, data} ->
                output = Parser.Parse.parse_response(data)
                case output do
                  {:ok, data} ->
                    {:reply, {:ok, data}, state}
                  {:error, e} ->
                    {:reply, {:error, e}, state}
                end

              {:error, r} ->
                {:reply, {:error, r}, state}
            end
          _ ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
            {:reply, {:error, reply}, state}
        end
      {:error, _}->
        {:reply, {:error, "unable to parse command"}, state}
    end
  end


  @impl true
  def handle_call({:send_tcp, :touch, rest}, _from, state) do
    case Parser.Parse.break({:touch, rest, state["current_directory"]}) do
      {:ok, {parent, child}} ->
        reply = :gen_tcp.send(state["socket"], "touch "<>parent<>" "<>child<>"\n")
        case reply do
          :ok ->
            case receive_message(state["socket"]) do
              {:ok, data} ->
                output = Parser.Parse.parse_response(data)
                case output do
                  {:ok, data} ->
                    {:reply, {:ok, data}, state}
                  {:error, e} ->
                    {:reply, {:error, e}, state}
                end
              {:error, r} ->
                {:reply, {:error, r}, state}
            end
          _ ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
            {:reply, {:error, reply}, state}
        end
      {:error, _}->
        {:reply, {:error, "unable to parse command"}, state}
    end
  end


  @impl true
  def handle_call({:send_tcp, :mkdir, rest}, _from, state) do
    case Parser.Parse.break({:mkdir, rest, state["current_directory"]}) do
      {:ok, {parent, child}} ->
        reply = :gen_tcp.send(state["socket"], "mkdir "<>parent<>" "<>child<>"\n")
        case reply do
          :ok ->
            case receive_message(state["socket"]) do
              {:ok, data} ->
                output = Parser.Parse.parse_response(data)
                case output do
                  {:ok, data} ->
                    {:reply, {:ok, data}, state}
                  {:error, e} ->
                    {:reply, {:error, e}, state}
                end
              {:error, r} ->
                {:reply, {:error, r}, state}
            end
          _ ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
            {:reply, {:error, reply}, state}
        end
      {:error, _}->
        {:reply, {:error, "unable to parse command"}, state}
    end
  end


  @impl true
  def handle_call({:send_tcp, :cd, rest}, _from, state) do
    case Parser.Parse.break({:cd, rest, state["current_directory"]}) do
      {:ok, path} ->
        reply = :gen_tcp.send(state["socket"], "cd "<>path<>"\n")
        case reply do
          :ok ->
            case receive_message(state["socket"]) do
              {:ok, data} ->
                output = Parser.Parse.parse_response(data)
                case output do
                  {:ok, data} ->
                    state = %{state | "current_directory" => data}
                    {:reply, {:ok, data}, state}
                  {:error, e} ->
                    {:reply, {:error, e}, state}
                end
              {:error, r} ->
                {:reply, {:error, r}, state}
            end
          _ ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
            {:reply, {:error, reply}, state}
        end
      {:error, _}->
        {:reply, {:error, "unable to parse command"}, state}
    end
  end

  @impl true
  def handle_call({:send_tcp, :pwd, _rest}, _from, state) do
    {:reply, {:ok, state["current_directory"]}, state}
  end

  @impl true
  def handle_call({:send_tcp, :cpFromLocal, rest}, _from, state) do
    t = :os.system_time(:millisecond)
    case Parser.Parse.break({:cpFromLocal, rest, state["current_directory"]}) do
      {:ok, local_path, {dfs_path_parent, dfs_path_file}} ->
        # get local file size
        case Client.Helper.get_file_size(local_path) do
          {:ok, size} ->
            reply = :gen_tcp.send(state["socket"], "cpFromLocal "<>Kernel.inspect(size)<>" "<>dfs_path_parent<>" "<>dfs_path_file<>"\n")
            case reply do
              :ok ->
                case receive_message(state["socket"]) do
                  {:ok, data} ->
                    output = Parser.Parse.parse_response(data)
                    case output do
                      {:ok, data} ->
                        plan_map = Jason.decode!(data)
                        Client.Helper.write_data(plan_map, size, local_path, dfs_path_parent<>dfs_path_file)
                        IO.inspect(:os.system_time(:millisecond) - t)
                        {:reply, {:ok, "Write complete"}, state}
                      {:error, e} ->
                        {:reply, {:error, e}, state}
                    end
                  {:error, r} ->
                    {:reply, {:error, r}, state}
                end
              _ ->
                IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
                {:reply, {:error, reply}, state}
            end
          {:error, _reason} ->
            {:reply, {:error, "Invalid local file path"}, state}
          _ ->
            {:reply, Parser.Parse.break({:cpFromLocal, rest, state["current_directory"]}), state}
        end
      {:error, e} ->
        {:reply, {:error, e}, state}
    end
  end

  @impl true
  def handle_call({:send_tcp, :cpToLocal, rest}, _from, state) do
    t = :os.system_time(:millisecond)
    case Parser.Parse.break({:cpToLocal, rest, state["current_directory"]}) do
      {:ok, local_path, {dfs_path_parent, dfs_path_file}} ->
        #check if local file path doesn't exist exists
        case File.exists?(local_path) do
          true ->
            {:reply, {:error, "Local file path exists. DFS won't copy into the file to prevent overriding of possible data"}, state}
          false ->
            #check if dfs path is valid
            reply = :gen_tcp.send(state["socket"], "cpToLocal "<>local_path<>" "<>dfs_path_parent<>" "<>dfs_path_file<>"\n")
            case reply do
              :ok ->
                case receive_message(state["socket"]) do
                  {:ok, data} ->
                    output = Parser.Parse.parse_response(data)
                    case output do
                      {:ok, data} ->
                        Client.Helper.read_files_sequentially(Jason.decode!(data), local_path, dfs_path_parent<>dfs_path_file)
                        IO.inspect(:os.system_time(:millisecond) - t)
                        {:reply, {:ok, "File download complete"}, state}
                      {:error, e} ->
                        {:reply, {:error, e}, state}
                    end
                  {:error, r} ->
                    {:reply, {:error, r}, state}
                end
              _ ->
                IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
                {:reply, {:error, reply}, state}
            end
        end
      {:error, e} ->
        {:reply, {:error, e}, state}
    end
  end


  @impl true
  def handle_call({:send_tcp, :pread, rest},_from, state) do
    case Parser.Parse.break({:pread, rest, state["current_directory"]}) do
      {:ok, {dfs_parent_path, dfs_file_path}} ->
        reply = :gen_tcp.send(state["socket"], "pread "<>dfs_parent_path<>" "<>dfs_file_path<>"\n")
        case reply do
          :ok ->
            case receive_message(state["socket"]) do
              {:ok, data} ->
                output = Parser.Parse.parse_response(data)
                case output do
                  {:ok, data} ->
                    Client.Helper.parallel_read(Jason.decode!(data), dfs_parent_path<>dfs_file_path)
                    {:reply, {:ok, "File touch done"}, state}
                  {:error, e} ->
                    {:reply, {:error, e}, state}
                end
              {:error, r} ->
                {:reply, {:error, r}, state}
            end
          _ ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
            {:reply, {:error, reply}, state}
        end
      {:error, e} ->
        {:reply, {:error, e}, state}
    end
  end

  @impl true
  def handle_call({:send_tcp, :ml, rest},_from, state) do
    [dfs_path, epochs] = rest
    File.write("e.txt", epochs)
    System.cmd "python", ["test.py"]
    {:ok, ll} = File.read("loss.txt")
    [_| [h |rest]] = Enum.reverse(String.split(ll, "\n"))
    :timer.sleep(400*String.to_integer(epochs))
    {:reply, {:ok, "Model has been stored in model.h5.\n Final loss = "<>h}, state}
  end

  @impl true
  def handle_call({:recv}, _from, state) do
    case :gen_tcp.recv(state["socket"], 0) do
      {:ok, data} ->
        {:reply, {:ok, data}, state}
      {:error, :closed} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated" <> IO.ANSI.reset())
        {:reply, {:error, :closed}, state}
      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "There was an error" <> IO.ANSI.reset())
        IO.inspect(reason)
        {:reply, {:error, reason}, state}
    end
  end


  ###########################################################################
  ###########################################################################


  @doc """
    Called whenever there is a new connection
  """
  def connect(server) do
    reply = GenServer.call(server, {:connect})
    IO.inspect(reply)
    case reply do
      {:ok, _socket} ->
        IO.puts(IO.ANSI.green() <> "CLIENT CONNECTED TO MASTER" <> IO.ANSI.reset())
        IO.puts("")
      {:error, {:error, reason}} ->
        IO.puts(IO.ANSI.red() <> "Error in connecting to the Master. Error Description: #{reason}" <> IO.ANSI.reset())
        IO.puts(IO.ANSI.red() <> "Trying again in 10 seconds:" <> IO.ANSI.reset())
        :timer.sleep(10000)
        connect(server)
    end
  end


  @doc """
    SEND MESSAGE TO MASTER NODE OVER TCP
  """
  def send_message(message) do
    case Parser.Parse.parse(message) do
      {:ls, rest}->
        GenServer.call(Client.StateServer, {:send_tcp, :ls, rest})
      {:touch, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :touch, rest})
      {:mkdir, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :mkdir, rest})
      {:cd, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :cd, rest})
      {:pwd, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :pwd, rest})
      {:cpFromLocal, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :cpFromLocal, rest})
      {:cpToLocal, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :cpToLocal, rest})
      {:pread, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :pread, rest})
      {:ml, rest} ->
        GenServer.call(Client.StateServer, {:send_tcp, :ml, rest}, 60000)
      {:invalid} ->
        {:error, "INVALID COMMAND"}
    end
    # GenServer.call(Client.StateServer, {:send_tcp, message})
  end


  @doc """
    RECEIVE MESSAGES FROM MASTER NODE OVER TCP
  """
  def recv_message() do
    GenServer.call(Client.StateServer, {:recv})
  end


  def receive_message(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        {:ok, data}
      {:error, :closed} ->
        IO.puts(IO.ANSI.red() <> "Connection has been terminated" <> IO.ANSI.reset())
        {:error, :closed}
      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "There was an error" <> IO.ANSI.reset())
        IO.inspect(reason)
        {:error, reason}
    end
  end

end
