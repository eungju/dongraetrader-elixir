defmodule DongraeTrader.PEGTest do
  use ExUnit.Case
  alias DongraeTrader.PEG, as: PEG

  test "regex success" do
    assert {:ok, {["200"], " OK\r\n"}} == PEG.regex(~r/^\d+/).({[], "200 OK\r\n"})
  end

  test "regex failure, due to unexpected end of input" do
    assert {:error, :unexpected_end_of_input} == PEG.regex(~r/^\d+/).({[], ""})
  end

  test "regex failure, due to unexpected input" do
    assert {:error, :unexpected_input} == PEG.regex(~r/^\d+/).({[], "OK"})
  end

  test "ignore the effect" do
    assert {:ok, {[:keep], "."}} == PEG.regex(~r/OK/, &PEG.ignore/2).({[:keep], "OK."})
  end

  test "ignore do nothing if the result is an error" do
    assert {:error, :unexpected_input} == PEG.regex(~r/OK/, &PEG.ignore/2).({[:keep], "ERROR."})
  end
end