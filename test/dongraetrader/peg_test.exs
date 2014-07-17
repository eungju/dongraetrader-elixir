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

  test "chunk success" do
    assert {:ok, {["012"], "3"}} == PEG.chunk(3).({[], "0123"})
    assert {:ok, {["가"], "나다"}} == PEG.chunk(3).({[], "가나다"})
  end

  test "chunk failure, due to unexpected end of input" do
    assert {:error, :unexpected_end_of_input} == PEG.chunk(5).({[], "0123"})
  end

  test "action should be executed if the result is a success" do
    assert {:ok, {[:keep], "."}} == PEG.regex(~r/OK/, &PEG.ignore/2).({[:keep], "OK."})
  end

  test "action should not be executed if the result is a failure" do
    assert {:error, :unexpected_input} == PEG.regex(~r/OK/, &PEG.ignore/2).({[:keep], "ERROR."})
  end
end