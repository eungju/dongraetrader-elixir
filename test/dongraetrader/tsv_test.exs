defmodule DongraeTrader.TSVTest do
  use ExUnit.Case
  alias DongraeTrader.TSV, as: DUT

  test "encode row" do
    assert "name\tvalue\r\n" == IO.iodata_to_binary(DUT.encode_row(["name", "value"]))
  end

  test "encode rows" do
    assert "A1\tB1\r\nA2\tB2\r\n" == IO.iodata_to_binary(DUT.encode([["A1", "B1"], ["A2", "B2"]]))
  end

  test "encode binary values with URL encoding" do
    assert "%01\t%02\r\n" == IO.iodata_to_binary(DUT.encode([[<<1>>, <<2>>]], DUT.URLEncoding))
  end

  test "decode row" do
    assert ["name", "value"] == DUT.decode_row("name\tvalue\r\n")
  end

  test "decode rows" do
    assert [["A1", "B1"], ["A2", "B2"]] == DUT.decode("A1\tB1\r\nA2\tB2\r\n")
  end

  test "decode values as binary with URL encoding" do
    assert [[<<1>>, <<2>>]] == DUT.decode("%01\t%02\r\n", DUT.URLEncoding)
  end

  test "URL encoding" do
    assert "%EA%B0%80" == DUT.URLEncoding.encode("가")
    assert "가" == DUT.URLEncoding.decode("%EA%B0%80")
  end

  test "Base64 encoding" do
    assert "6rCA" == DUT.Base64Encoding.encode("가")
    assert "가" == DUT.Base64Encoding.decode("6rCA")
  end
end