defmodule DongraeTrader.PEGTest do
  use ExUnit.Case
  alias DongraeTrader.PEG, as: PEG

  test "regex success" do
    assert {:ok, {["200"], " OK\r\n"}} == PEG.regex(~r/\d+/).({[], "200 OK\r\n"})
    assert {:ok, {["가"], "나다"}} == PEG.regex(~r/가/).({[], "가나다"})
    assert {:ok, {["가"], "나다"}} == PEG.regex(~r/\w/u).({[], "가나다"})
  end

  test "regex failure, due to unexpected end of input" do
    assert {:error, :unexpected_end_of_input} == PEG.regex(~r/\d+/).({[], ""})
  end

  test "regex failure, due to unexpected input" do
    assert {:error, :unexpected_input} == PEG.regex(~r/\d+/).({[], "OK"})
  end

  test "bytes success" do
    assert {:ok, {["012"], "3"}} == PEG.bytes(3).({[], "0123"})
    assert {:ok, {["가"], "나다"}} == PEG.bytes(3).({[], "가나다"})
  end

  test "bytes failure, due to unexpected end of input" do
    assert {:error, :unexpected_end_of_input} == PEG.bytes(5).({[], "0123"})
  end

  test "action should be executed if the result is a success" do
    assert {:ok, {[:keep], "."}} == PEG.regex(~r/OK/, &PEG.ignore/2).({[:keep], "OK."})
  end

  test "action should not be executed if the result is a failure" do
    assert {:error, :unexpected_input} == PEG.regex(~r/OK/, &PEG.ignore/2).({[:keep], "ERROR."})
  end

  test "sequence success" do
    a = PEG.regex(~r/A/)
    b = PEG.regex(~r/B/)
    assert {:ok, {[["B", "A"]], "C"}} == PEG.sequence([a, b]).({[], "ABC"})
  end

  test "sequence failure" do
    a = PEG.regex(~r/A/)
    b = PEG.regex(~r/B/)
    assert {:error, :unexpected_end_of_input} == PEG.sequence([a, b]).({[], "A"})
    assert {:error, :unexpected_input} == PEG.sequence([a, b]).({[], "AC"})
  end

  test "zero_or_more success" do
    a = PEG.regex(~r/A/)
    assert {:ok, {[[]], ""}} == PEG.zero_or_more(a).({[], ""})
    assert {:ok, {[[]], "B"}} == PEG.zero_or_more(a).({[], "B"})
    assert {:ok, {[["A"]], "B"}} == PEG.zero_or_more(a).({[], "AB"})
    assert {:ok, {[["A", "A"]], "B"}} == PEG.zero_or_more(a).({[], "AAB"})
  end
end