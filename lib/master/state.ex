defmodule Master.State do

  @moduledoc """
    Starts a bucket that maintains state for the client
    State includes the following
      - current directory
      - base directory

    Uses Agent -> A common abstraction to maintain state in elixir processes
  """

  use Agent, restart: :temporary


  @doc """
    Starts a new instance for the client with initial states
    Current Directory => "/home"
    Base DIrectory => "/home"

    start link outputs {:ok, pid}
    The pid defines the state for the client connecting to the master (This will allow multiple clients to connect and hence multiple states will be generated)
  """
  def start_link(_opts) do
    Agent.start_link(
      fn -> %{
        "current_directory" => "/home/",
        "base_directory" => "/home/"
        }
      end
    )
  end


  @doc """
    Gets current directory from the state
    Takes as input, the PID of the state initialized by start_link
  """
  def get_current_directory(state) do
    Agent.get(state, &Map.get(&1, "current_directory"))
  end


  @doc """
    Updates the current directory maintained in the state for a particular state PID
  """
  def update_current_directory(state, new_current_directory) do
    Agent.update(state, &Map.put(&1, "current_directory", new_current_directory))
  end

end
