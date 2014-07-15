defmodule DongraeTrader.HTTP.RequestTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP, as: HTTP

  test "encode request line" do
    actual = HTTP.Request.encode_request_line(:get, "/hello-world", :http_1_1)
    assert IO.iodata_to_binary(actual) == "GET /hello-world HTTP/1.1\r\n"
  end

  test "encode header" do
    actual = HTTP.Request.encode_header({:content_length, 1})
    assert IO.iodata_to_binary(actual) == "Content-Length: 1\r\n"
  end

  test "encode headers" do
    actual = HTTP.Request.encode_headers([{:content_length, 1},
                                          {:content_type, "text/html"}])
    assert IO.iodata_to_binary(actual) == "Content-Length: 1\r\nContent-Type: text/html\r\n"
  end

  test "encode GET request" do
    actual = HTTP.Request.encode(HTTP.Request.get("/hello-world"))
    assert IO.iodata_to_binary(actual) == "GET /hello-world HTTP/1.1\r\n\r\n"
  end

  test "encode POST request" do
    actual = HTTP.Request.encode(HTTP.Request.post("/hello-world", "application/x-www-form-urlencoded", "name=EP"))
    assert IO.iodata_to_binary(actual) == "POST /hello-world HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 7\r\n\r\nname=EP"
  end
end