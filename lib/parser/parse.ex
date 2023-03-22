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
      #WORKER
      "worker_info" ->
        {:worker_info, rest}

      #CLIENT
      "ls" ->
        {:ls, rest}
      "mkdir" ->
        {:mkdir, rest}
      "touch" ->
        {:touch, rest}
      "cd" ->
        {:cd, rest}
      _ ->
        {:invalid}
    end
  end

  def parse(cmd) do
    {h, rest} = split_string(cmd)
    isolate_command(h,rest)
  end

end
