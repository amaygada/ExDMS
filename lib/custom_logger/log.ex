defmodule CustomLogger.Log do

  @moduledoc """
    HELPER FUNCTION FOR ALL THE COLOURFUL LOGGING NEEDS OF THE SYSTEM
  """

  def success_log(msg) do
    IO.ANSI.green() <> msg <> IO.ANSI.reset()
  end

  def error_log(msg) do
    IO.ANSI.red() <> msg <> IO.ANSI.reset()
  end

  def file_log(msg) do
    IO.ANSI.white() <> msg <> IO.ANSI.reset()
  end

  def folder_log(msg) do
    IO.ANSI.blue() <> msg <> IO.ANSI.reset()
  end

end
