defmodule DongraeTrader.HTTP.ResponseTest do
  use ExUnit.Case
  alias DongraeTrader.HTTP, as: HTTP

  test "decode regex pattern" do
    assert {:ok, ["200"], " OK\r\n"} == HTTP.Response.decode_pattern({:ok, [], "200 OK\r\n"}, ~r/^\d+/)
  end

  test "decode regex pattern, but failed due to unexpected end of input" do
    assert {:error, :unexpected_end_of_input} == HTTP.Response.decode_pattern({:ok, [], ""}, ~r/^\d+/)
  end

  test "decode regex pattern, but failed due to unexpected input" do
    assert {:error, :unexpected_input} == HTTP.Response.decode_pattern({:ok, [], "OK"}, ~r/^\d+/)
  end

  test "decode status line" do
    {:ok, [actual], <<>>} = HTTP.Response.decode_status_line({:ok, [], "HTTP/1.1 200 OK\r\n"})
    assert {:http_1_1, 200, "OK"} == actual
  end

  test "decode header" do
    assert {:ok, [{:content_length, "42"}], <<>>} == HTTP.Response.decode_header({:ok, [], "Content-Length: 42\r\n"})
  end

  test "decode headers" do
    assert {:ok, [[{:content_length, "42"}, {:content_type, "text/html"}]], <<>>} == HTTP.Response.decode_headers({:ok, [], "Content-Length: 42\r\nContent-Type: text/html\r\n"})
  end

  test "decode response" do
    assert {:ok, %HTTP.Response{version: :http_1_1, code: 200, reason: "OK", headers: [content_length: "5"], body: "HELLO"}, <<>>} == HTTP.Response.decode("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHELLO")
  end

  test "decode incomplete response" do
    assert {:error, :unexpected_end_of_input} == HTTP.Response.decode("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHELL")
  end
end