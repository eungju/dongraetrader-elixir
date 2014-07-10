defmodule DongraeTrader.HTTPTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP, as: HTTP

  test "opening and closing a connection" do
    {:ok, conn} = HTTP.Connection.open("localhost", 1978)
    :ok = HTTP.Connection.close(conn)
  end

  test "GET request" do
    {:ok, conn} = HTTP.Connection.open("localhost", 1978)
    {:ok, _response} = HTTP.Connection.call(conn, HTTP.Request.get("/"))
    :ok = HTTP.Connection.close(conn)
  end
end