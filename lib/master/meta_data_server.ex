defmodule Master.MetaDataServer do

  @moduledoc """
    This is a Genserver to monitor the state for each client
  """

  use GenServer

  #SERVER API

  @doc """
    Initializes the MetaDataServer with the server state and the ref state
  """
  @impl true
  def init(:ok) do
    server_state = %{}       #stores the mapping between client names and PID
    refs = %{}               #stores the reference ids which are generated while monitoring a process
    {:ok, {server_state, refs}}
  end

  @impl true
  def handle_call(_, _from, _server_state) do

  end

  @impl true
  def handle_cast(_, _server_state) do

  end




  #CLIENT API

  @doc """
    Starts the GenServer
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

end
