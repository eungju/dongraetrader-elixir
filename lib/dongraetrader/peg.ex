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

  def empty() do
    fn {acc, input} -> {:ok, {[""|acc], input}} end
  end

  def binary(s, action \\ &cons/2) do
    fn {acc, input} ->
      length = byte_size(s)
      available = byte_size(input)
      if length > available  do
        {:error, :unexpected_end_of_input}
      else
        terminal = binary_part(input, 0, length)
        if s === terminal do
          rest = binary_part(input, length, available - length)
          {:ok, {action.(terminal, acc), rest}}
        else
          {:error, :unexpected_input}
        end
      end
    end
  end

  def string(s, action \\ &cons/2) do
    binary(s, action)
  end

  def regex(regex, action \\ &cons/2) do
    fn {acc, input} ->
      case Regex.run(regex, input, return: :index) do
        [{0, l}] ->
          terminal = binary_part(input, 0, l)
          rest = binary_part(input, l, byte_size(input) - l)
          {:ok, {action.(terminal, acc), rest}}
        _ ->
          reason = if input === "" do
                     :unexpected_end_of_input
                   else
                     :unexpected_input
                   end
          {:error, reason}
      end
    end
  end

  def bytes(length, action \\ &cons/2) do
    fn {acc, input} ->
      available = byte_size(input)
      if length > available  do
        {:error, :unexpected_end_of_input}
      else
        terminal = binary_part(input, 0, length)
        rest = binary_part(input, length, available - length)
        {:ok, {action.(terminal, acc), rest}}
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

  def choice(exprs, action \\ &cons/2) do
    fn state -> choice_loop(exprs, action, state) end
  end

  defp choice_loop(exprs, action, state) do
    case exprs do
      [] ->
        {:error, :unsatisfied_choice}
      [expr|expr_rest] ->
        case expr.(state) do
          {:ok, result_state} -> {:ok, result_state}
          {:error, _} -> choice_loop(expr_rest, action, state)
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

  def one_or_more(expr, action \\ &cons/2) do
    fn {acc, input} -> one_or_more_mandatory(expr, action, {[], input}, acc) end
  end

  defp one_or_more_mandatory(expr, action, state, acc) do
    case expr.(state) do
      {:ok, result_state} ->
        one_or_more_optional(expr, action, result_state, acc)
      {:error, _} = error -> error
    end
  end

  defp one_or_more_optional(expr, action, {lacc, input}=state, acc) do
    case expr.(state) do
      {:ok, result_state} ->
        one_or_more_optional(expr, action, result_state, acc)
      {:error, _} -> {:ok, {action.(lacc, acc), input}}
    end
  end

  def optional(expr) do
    fn state ->
      case expr.(state) do
        {:ok, result_state} -> {:ok, result_state}
        {:error, _} -> {:ok, state}
      end
    end
  end

  def andp(expr) do
    fn state ->
      case expr.(state) do
        {:ok, _} -> {:ok, state}
        {:error, _} -> {:error, :unsatisfied_and_predicate}
      end
    end
  end

  def notp(expr) do
    fn state ->
      case expr.(state) do
        {:ok, _} -> {:error, :unsatisfied_not_predicate}
        {:error, _} -> {:ok, state}
      end
    end
  end
end
