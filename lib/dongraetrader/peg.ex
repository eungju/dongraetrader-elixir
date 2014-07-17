defmodule DongraeTrader.PEG do
  #Actions

  def cons(e, acc) do
    [e|acc]
  end

  def transform_and_cons(f) do
    fn e, acc -> [f.(e)|acc] end
  end

  def ignore(_, acc) do
    acc
  end

  #Terminals

  def chunk(length, action \\ &cons/2) do
    fn {acc, input} ->
      input_length = byte_size(input)
      if length > input_length  do
        {:error, :unexpected_end_of_input}
      else
        {chunk, rest} = String.split_at(input, length)
        {:ok, {action.(chunk, acc), rest}}
      end
    end
  end

  def regex(regex, action \\ &cons/2) do
    fn {acc, input} ->
      case Regex.run(regex, input, return: :index) do
        [{s, l}] ->
          terminal = binary_part(input, s, l)
          rest = binary_part(input, s + l, byte_size(input) - (s + l))
          {:ok, {action.(terminal, acc), rest}}
        nil ->
          reason = case input do
                     "" -> :unexpected_end_of_input
                     _ -> :unexpected_input
                   end
          {:error, reason}
      end
    end
  end

  #Operators

  def sequence(exprs, action \\ &cons/2) do
    fn {acc, input} -> sequence_loop(exprs, action, {[], input}, acc) end
  end

  defp sequence_loop(exprs, action, {lacc, input}=state, acc) do
    case exprs do
      [] ->
        {:ok, {action.(lacc, acc), input}}
      [expr|expr_rest] ->
        case expr.(state) do
          {:ok, result_state} -> sequence_loop(expr_rest, action, result_state, acc)
          {:error, _} = error -> error
        end
    end
  end

  def zero_or_more(expr, action \\ &cons/2) do
    fn {acc, input} -> zero_or_more_loop(expr, action, {[], input}, acc) end
  end

  defp zero_or_more_loop(expr, action, {lacc, input}=state, acc) do
    case expr.(state) do
      {:ok, result_state} -> zero_or_more_loop(expr, action, result_state, acc)
      {:error, _} -> {:ok, {action.(lacc, acc), input}}
    end
  end
end
