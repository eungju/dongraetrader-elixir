defmodule DongraeTrader.PEGTest do
  use ExUnit.Case
  alias DongraeTrader.PEG, as: PEG

  test "empty always succeeds" do
    assert {:ok, {[""], ""}} == PEG.empty().({[], ""})
    assert {:ok, {[""], "ABC"}} == PEG.empty().({[], "ABC"})
  end

  test "binary succeeds if it matches with the input" do
    assert {:ok, {["AB"], "C"}} == PEG.binary("AB").({[], "ABC"})
    assert {:ok, {["가나"], "다"}} == PEG.binary("가나").({[], "가나다"})
    assert {:ok, {[""], ""}} == PEG.binary("").({[], ""})
    assert {:ok, {[<<1, 2>>], <<3>>}} == PEG.binary(<<1,2>>).({[], <<1,2,3>>})
  end

  test "binary fails if there is unexpected input" do
    assert {:error, :unexpected_input} == PEG.binary("A").({[], "B"})
  end

  test "binary fails if there is no input" do
    assert {:error, :unexpected_end_of_input} == PEG.binary("A").({[], ""})
  end

  test "regex succeeds if it matches with the input" do
    assert {:ok, {["200"], " OK\r\n"}} == PEG.regex(~r/\d+/).({[], "200 OK\r\n"})
    assert {:ok, {["가"], "나다"}} == PEG.regex(~r/가/).({[], "가나다"})
    assert {:ok, {["가"], "나다"}} == PEG.regex(~r/\w/u).({[], "가나다"})
  end

  test "regex fails if there is unexpected input" do
    assert {:error, :unexpected_input} == PEG.regex(~r/\d+/).({[], "OK"})
  end

  test "regex fails if there is no input" do
    assert {:error, :unexpected_end_of_input} == PEG.regex(~r/\d+/).({[], ""})
  end

  test "bytes succeeds if there is enough input" do
    assert {:ok, {["12"], "3"}} == PEG.bytes(2).({[], "123"})
    assert {:ok, {["가"], "나다"}} == PEG.bytes(3).({[], "가나다"})
  end

  test "bytes fails if there is not enough input" do
    assert {:error, :unexpected_end_of_input} == PEG.bytes(4).({[], "123"})
  end

  test "sequence succeeds if all the sub-expressions succeed" do
    expr = PEG.sequence([PEG.string("A"), PEG.string("B")])
    assert {:ok, {[["B", "A"]], "C"}} == expr.({[], "ABC"})
  end

  test "sequence fails if any one of the sub-expressions fails" do
    expr = PEG.sequence([PEG.string("A"), PEG.string("B")])
    assert {:error, :unexpected_end_of_input} == expr.({[], "A"})
    assert {:error, :unexpected_input} == expr.({[], "AC"})
  end

  test "choice succeeds if any one of the sub-expressions succeeds" do
    expr = PEG.choice([PEG.string("A"), PEG.string("B")])
    assert {:ok, {["A"], "B"}} == expr.({[], "AB"})
    assert {:ok, {["B"], "A"}} == expr.({[], "BA"})
  end

  test "choice fails if all the sub-expressions fail" do
    expr = PEG.choice([PEG.string("A"), PEG.string("B")])
    assert {:error, :unsatisfied_choice} == expr.({[], "CBA"})
  end

  test "zero_or_more succeeds if the sub-expression succeeds zero or more times" do
    expr = PEG.zero_or_more(PEG.string("A"))
    assert {:ok, {[[]], ""}} == expr.({[], ""})
    assert {:ok, {[[]], "B"}} == expr.({[], "B"})
    assert {:ok, {[["A"]], ""}} == expr.({[], "A"})
    assert {:ok, {[["A"]], "B"}} == expr.({[], "AB"})
    assert {:ok, {[["A", "A"]], "B"}} == expr.({[], "AAB"})
  end

  test "one_or_more succeeds if the sub-expression succeeds one or more times" do
    expr = PEG.one_or_more(PEG.string("A"))
    assert {:ok, {[["A"]], ""}} == expr.({[], "A"})
    assert {:ok, {[["A"]], "B"}} == expr.({[], "AB"})
    assert {:ok, {[["A", "A"]], "B"}} == expr.({[], "AAB"})
  end

  test "one_or_more fails if the sub-expression doesn't succeed the first time" do
    expr = PEG.one_or_more(PEG.string("A"))
    assert {:error, :unexpected_end_of_input} == expr.({[], ""})
    assert {:error, :unexpected_input} == expr.({[], "B"})
  end

  test "optional succeeds if the sub-expression succeeds or not" do
    expr = PEG.optional(PEG.string("A"))
    assert {:ok, {[], ""}} == expr.({[], ""})
    assert {:ok, {[], "B"}} == expr.({[], "B"})
    assert {:ok, {["A"], "B"}} == expr.({[], "AB"})
    assert {:ok, {["A"], "AB"}} == expr.({[], "AAB"})
  end

  test "andp succeeds if the sub-expression succeeds, otherwise it fails, but in either case never consumes any input" do
    expr = PEG.andp(PEG.string("A"))
    assert {:ok, {[], "ABC"}} == expr.({[], "ABC"})
    assert {:error, :unsatisfied_and_predicate} == expr.({[], "BC"})
  end

  test "notp succeeds if the sub-expression fails, otherwise it fails, but in either case never consumes any input" do
    expr = PEG.notp(PEG.string("A"))
    assert {:ok, {[], "BC"}} == expr.({[], "BC"})
    assert {:error, :unsatisfied_not_predicate} == expr.({[], "ABC"})
  end

  test "action is executed if the result is a success" do
    assert {:ok, {[:keep], "."}} == PEG.string("OK", &PEG.ignore/2).({[:keep], "OK."})
  end

  test "action is executed if the result is a failure" do
    assert {:error, :unexpected_input} == PEG.string("OK", &PEG.ignore/2).({[:keep], "ERROR."})
  end
end