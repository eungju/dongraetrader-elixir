defmodule DongraeTrader.HTTPTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP, as: HTTP

  test "decorate request with Host header" do
    conn = %HTTP.Connection{host: "localhost", port: 1978}
    actual = HTTP.Connection.decorate_request(conn, HTTP.Request.get("/"))
    assert actual.headers |> Keyword.get(:host) == "localhost:1978"
  end

  test "opening and closing a connection" do
    {:ok, pid} = HTTP.Connection.start_link("localhost", 1978)
    :ok = HTTP.Connection.stop(pid)
  end

  test "GET request" do
    {:ok, pid} = HTTP.Connection.start_link("localhost", 1978)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(pid, HTTP.Request.get("/rpc/void"))
    :ok = HTTP.Connection.stop(pid)
  end

  test "POST request" do
    {:ok, pid} = HTTP.Connection.start_link("localhost", 1978)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(pid, HTTP.Request.post("/rpc/void", "text/tab-separated-values", ""))
    :ok = HTTP.Connection.stop(pid)
  end

  test "keep connection if the call is successful" do
    void_req = HTTP.Request.get("/rpc/void")
    {:ok, pid} = HTTP.Connection.start_link("localhost", 1978)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(pid, void_req)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(pid, void_req)
    :ok = HTTP.Connection.stop(pid)
  end

  test "close connection if the response indicates connection close" do
    void_req = HTTP.Request.get("/rpc/void")
    void_req = %{void_req | headers: [{:connection, :close}|void_req.headers]}
    {:ok, pid} = HTTP.Connection.start_link("localhost", 1978)
    {:ok, %HTTP.Response{code: 200}} = HTTP.Connection.call(pid, void_req)
    assert not Process.alive?(pid)
  end
end