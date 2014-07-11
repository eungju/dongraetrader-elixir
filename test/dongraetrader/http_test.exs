defmodule DongraeTrader.HTTPTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP, as: HTTP

  test "opening and closing a connection" do
    {:ok, conn} = HTTP.Connection.open("localhost", 1978)
    :ok = HTTP.Connection.close(conn)
  end

  test "decorate request with Host header" do
    conn = %HTTP.Connection{host: "localhost", port: 1978}
    actual = HTTP.Connection.decorate_request(conn, HTTP.Request.get("/"))
    assert actual.headers |> Keyword.get(:host) == "localhost:1978"
  end

  test "GET request" do
    {:ok, conn} = HTTP.Connection.open("localhost", 1978)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(conn, HTTP.Request.get("/rpc/void"))
    :ok = HTTP.Connection.close(conn)
  end

  test "POST request" do
    {:ok, conn} = HTTP.Connection.open("localhost", 1978)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(conn, HTTP.Request.post("/rpc/void", "text/tab-separated-values", ""))
    :ok = HTTP.Connection.close(conn)
  end
end