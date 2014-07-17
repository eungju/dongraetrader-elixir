defmodule DongraeTrader.PEG do
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

  def cons(terminal, acc) do
    [terminal|acc]
  end

  def ignore(_terminal, acc) do
    acc
  end

  def sequence(exprs) do
    fn state -> sequence_loop(exprs, state) end
  end

  defp sequence_loop(exprs, state) do
    case exprs do
      [] -> {:ok, state}
      [expr|expr_rest] ->
        case expr.(state) do
          {:ok, result_state} -> sequence_loop(expr_rest, result_state)
          {:error, _} = error -> error
        end
    end
  end

  def zero_or_more(expr) do
    fn state -> zero_or_more_loop(expr, state) end
  end

  defp zero_or_more_loop(expr, state) do
    case expr.(state) do
      {:ok, result_state} -> zero_or_more_loop(expr, result_state)
      {:error, _} -> {:ok, state}
    end
  end
end
