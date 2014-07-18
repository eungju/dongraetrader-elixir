defmodule DongraeTrader.PEGTest do
  use ExUnit.Case
  alias DongraeTrader.PEG, as: PEG

  test "binary success" do
    assert {:ok, {["AB"], "C"}} == PEG.binary("AB").({[], "ABC"})
    assert {:ok, {["가나"], "다"}} == PEG.binary("가나").({[], "가나다"})
    assert {:ok, {[<<1, 2>>], <<3>>}} == PEG.binary(<<1,2>>).({[], <<1,2,3>>})
  end

  test "binary failure" do
    assert {:error, :unexpected_end_of_input} == PEG.binary("A").({[], ""})
    assert {:error, :unexpected_input} == PEG.binary("A").({[], "B"})
  end

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

  test "empty success" do
    assert {:ok, {[""], ""}} == PEG.empty().({[], ""})
    assert {:ok, {[""], "ABC"}} == PEG.empty().({[], "ABC"})
  end

  test "bytes success" do
    assert {:ok, {["12"], "3"}} == PEG.bytes(2).({[], "123"})
    assert {:ok, {["가"], "나다"}} == PEG.bytes(3).({[], "가나다"})
  end

  test "bytes failure, due to unexpected end of input" do
    assert {:error, :unexpected_end_of_input} == PEG.bytes(4).({[], "123"})
  end

  test "action should be executed if the result is a success" do
    assert {:ok, {[:keep], "."}} == PEG.string("OK", &PEG.ignore/2).({[:keep], "OK."})
  end

  test "action should not be executed if the result is a failure" do
    assert {:error, :unexpected_input} == PEG.string("OK", &PEG.ignore/2).({[:keep], "ERROR."})
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

  test "choice success" do
    a = PEG.string("A")
    b = PEG.string("B")
    assert {:ok, {["A"], "B"}} == PEG.choice([a, b]).({[], "AB"})
    assert {:ok, {["B"], "A"}} == PEG.choice([a, b]).({[], "BA"})
  end

  test "zero_or_more success" do
    a = PEG.regex(~r/A/)
    assert {:ok, {[[]], ""}} == PEG.zero_or_more(a).({[], ""})
    assert {:ok, {[[]], "B"}} == PEG.zero_or_more(a).({[], "B"})
    assert {:ok, {[["A"]], "B"}} == PEG.zero_or_more(a).({[], "AB"})
    assert {:ok, {[["A", "A"]], "B"}} == PEG.zero_or_more(a).({[], "AAB"})
  end

  test "one_or_more success" do
    a = PEG.string("A")
    assert {:ok, {[["A"]], ""}} == PEG.one_or_more(a).({[], "A"})
    assert {:ok, {[["A"]], "B"}} == PEG.one_or_more(a).({[], "AB"})
    assert {:ok, {[["A", "A"]], "B"}} == PEG.one_or_more(a).({[], "AAB"})
  end

  test "one_or_more failure" do
    a = PEG.string("A")
    assert {:error, :unexpected_end_of_input} == PEG.one_or_more(a).({[], ""})
    assert {:error, :unexpected_input} == PEG.one_or_more(a).({[], "B"})
  end

  test "optional success" do
    a = PEG.string("A")
    assert {:ok, {[], ""}} == PEG.optional(a).({[], ""})
    assert {:ok, {[], "B"}} == PEG.optional(a).({[], "B"})
    assert {:ok, {["A"], "B"}} == PEG.optional(a).({[], "AB"})
  end

  test "The and-predicate expression &e invokes the sub-expression e, and then succeeds if e succeeds and fails if e fails, but in either case never consumes any input." do
    a = PEG.string("A")
    assert {:ok, {[], "ABC"}} == PEG.andp(a).({[], "ABC"})
    assert {:error, :unexpected_input} == PEG.andp(a).({[], "BC"})
  end

  test "The not-predicate expression !e succeeds if e fails and fails if e succeeds, again consuming no input in either case." do
    a = PEG.string("A")
    assert {:error, :unexpected_input} == PEG.notp(a).({[], "ABC"})
    assert {:ok, {[], "BC"}} == PEG.notp(a).({[], "BC"})
  end
end