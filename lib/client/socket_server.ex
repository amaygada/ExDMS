defmodule Client.SocketServer do

  @moduledoc """
    THIS MODULE ALLOWS THE Client TO CONNECT TO ANY OTHER WORKER VIA TCP
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
      "socket_id" => ""
    }
  """
  @impl true
  def init(:ok) do
    init_state = %{
      "socket" => "",
      "recv_queue" => :queue.new
    }
    {:ok, init_state}
  end

  @imp true
  def stop() do
    :normal
  end

  @doc """
    Connects to the TCP socket
  """
  @impl true
  def handle_call({:connect, port, ip}, _from, state) do
    connect = :gen_tcp.connect(ip, port, [active: false, packet: 4])
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
  def handle_call({:write_operation, message}, _from, state) do
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
  def handle_call({:read_seq_operation, message}, _from, state) do
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

  @impl true
  def handle_call({:async_recv}, _from, state) do
    case :queue.out(state["recv_queue"]) do
      {{:value, val}, queue} ->
        {:reply, {:ok, val}, %{state | "recv_queue" => queue}}
      {:empty, _} ->
        case :gen_tcp.recv(state["socket"], 0, 5000) do
          {:ok, data} ->
            data = Kernel.inspect(data)
            data = String.replace(data, "'", "")
            [h | rest] = String.split(data, "delim")
            #append replies to queue
            queue = populate_reply_queue(rest, state["recv_queue"])
            {:reply, {:ok, h}, %{state | "recv_queue" => queue}}
          {:error, :closed} ->
            IO.puts(IO.ANSI.red() <> "Connection has been terminated" <> IO.ANSI.reset())
            {:reply, {:error, :closed}, state}
          {:error, reason} ->
            IO.puts(IO.ANSI.red() <> "There was an error" <> IO.ANSI.reset())
            IO.inspect(reason)
            {:reply, {:error, reason}, state}
        end
    end
  end


  ###########################################################################
  ###########################################################################


  @doc """
    Called whenever there is a new connection
  """
  def connect(socket, port, ip) do
    reply = GenServer.call(socket, {:connect, port, ip})
    case reply do
      {:ok, _socket} ->
        # IO.puts(IO.ANSI.green() <> "WORKER CONNECTED TO " <> Enum.join(Tuple.to_list(ip), ".") <> " on port " <> Kernel.inspect(port) <> IO.ANSI.reset())
        # IO.puts("")
        {:ok, "connected"}
      {:error, {:error, reason}} ->
        IO.puts(IO.ANSI.red() <> "Error in connecting to desired IP. Error Description: #{reason}" <> IO.ANSI.reset())
        IO.puts(IO.ANSI.red() <> "Try again" <> IO.ANSI.reset())
        {:error, "unable to connect"}
    end
  end


  @doc """
    SEND MESSAGE OVER TCP
  """
  def send_message(message, socket) do
    case String.split(message) do
      ["Write_Operation"] ->
        GenServer.call(socket, {:send_tcp, :write_operation, message})
    end
  end

  def graceful_shutdown(socket) do
    GenServer.stop(socket, :normal)
  end

  def write_operation(socket, message) do
    GenServer.call(socket, {:write_operation, message})
  end

  def read_seq_operation(socket, message) do
    GenServer.call(socket, {:read_seq_operation, message})
  end

  @doc """
    RECEIVE MESSAGES OVER TCP
  """
  def recv_message(socket) do
    GenServer.call(socket, {:recv})
  end

  @doc """
    HANDLE ASYNCHRONOUS RECEIVE MESSAGES OVER TCP
  """
  def async_recv_handler(socket) do
    GenServer.call(socket, {:async_recv})
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

  defp populate_reply_queue([], queue), do: queue
  defp populate_reply_queue(["" | rest], queue), do: populate_reply_queue(rest, queue)
  defp populate_reply_queue([h|rest], queue), do: populate_reply_queue(rest, :queue.in(h, queue))

end
