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
      "socket" => ""
    }
    {:ok, init_state}
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
            {:reply, {:ok, :sent}, state}
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
            {:reply, {:ok, :sent}, state}
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
            {:reply, {:ok, :sent}, state}
          _ ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated. Master seems to be down :(" <> IO.ANSI.reset())
            {:reply, {:error, reply}, state}
        end
      {:error, _}->
        {:reply, {:error, "unable to parse command"}, state}
    end
  end


  @impl true
  def handle_call({:recv}, _from, state) do
    case :gen_tcp.recv(state["socket"], 0, 5000) do
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
    case reply do
      {:ok, _socket} ->
        IO.puts(IO.ANSI.green() <> "CLIENT CONNECTED TO MASTER" <> IO.ANSI.reset())
        IO.puts("")
      {:error, {:error, reason}} ->
        IO.puts(IO.ANSI.red() <> "Error in connecting to the Master. Error Description: #{reason}" <> IO.ANSI.reset())
        IO.puts(IO.ANSI.red() <> "Try connecting manually using the command:" <> IO.ANSI.reset())
        IO.puts("    " <> IO.ANSI.blue() <> "Client.StateServer.connect(Client.StateServer)" <> IO.ANSI.reset())
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
    case :gen_tcp.recv(socket, 0, 5000) do
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
