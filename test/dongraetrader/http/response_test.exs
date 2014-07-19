defmodule DongraeTrader.HTTP.ResponseTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP.Response, as: DUT

  test "status_line = version SP code SP reason CRLF" do
    {:ok, {[actual], <<>>}} = DUT.Decoder.status_line({[], "HTTP/1.1 200 OK\r\n"})
    assert {:http_1_1, 200, "OK"} == actual
  end

  test "header = header_name : SP* header_value CRLF" do
    assert {:ok, {[{:content_length, "42"}], <<>>}} == DUT.Decoder.header({[], "Content-Length: 42\r\n"})
  end

  test "headers = header*" do
    assert {:ok, {[[{:content_length, "42"}, {:content_type, "text/html"}]], <<>>}} == DUT.Decoder.headers({[], "Content-Length: 42\r\nContent-Type: text/html\r\n"})
  end

  test "response = status_line headers CRLF body" do
    assert {:ok, {%DUT{version: :http_1_1, code: 200, reason: "OK", headers: [content_length: "5"], body: "HELLO"}, <<>>}} == DUT.Decoder.response({[], "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHELLO"})
  end

  test "decode fails if the input is incomplete" do
    assert {:error, :unexpected_end_of_input} == DUT.Decoder.decode("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHELL")
  end
end