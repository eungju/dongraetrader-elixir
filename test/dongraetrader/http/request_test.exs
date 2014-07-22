defmodule DongraeTrader.HTTP.RequestTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP.Request, as: DUT

  test "encode request line" do
    actual = DUT.Encoder.encode_request_line(:get, "/hello-world", :http_1_1)
    assert IO.iodata_to_binary(actual) == "GET /hello-world HTTP/1.1\r\n"
  end

  test "encode header" do
    actual = DUT.Encoder.encode_header({:content_length, 1})
    assert IO.iodata_to_binary(actual) == "Content-Length: 1\r\n"
  end

  test "encode headers" do
    actual = DUT.Encoder.encode_headers([{:content_length, 1},
                                         {:content_type, "text/html"}])
    assert IO.iodata_to_binary(actual) == "Content-Length: 1\r\nContent-Type: text/html\r\n"
  end

  test "encode GET request" do
    actual = DUT.Encoder.encode(DUT.get("/hello-world"))
    assert IO.iodata_to_binary(actual) == "GET /hello-world HTTP/1.1\r\n\r\n"
  end

  test "encode POST request" do
    actual = DUT.Encoder.encode(DUT.post("/hello-world", "application/x-www-form-urlencoded", "name=EP"))
    assert IO.iodata_to_binary(actual) == "POST /hello-world HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\nname=EP"
  end
end