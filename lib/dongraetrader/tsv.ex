defmodule DongraeTrader.TSV do
  defmodule URLEncoding do
    def encode(b), do: URI.encode(b)
    def decode(s), do: URI.decode(s)
  end

  defmodule Base64Encoding do
    def encode(b), do: Base.encode64(b)
    def decode(s), do: Base.decode64!(s)
  end

  def encode(rows, encoding \\ URLEncoding) do
    Enum.map(rows, fn row -> encode_row(row, encoding) end)
  end

  def encode_row(row, encoding \\ URLEncoding) do
    Enum.intersperse(Enum.map(row, &encoding.encode/1), "\t") ++ ["\r\n"]
  end

  def decode(s, encoding \\ URLEncoding) do
    s |> String.strip |> String.split("\r\n") |> Enum.map(fn line -> decode_row(line, encoding) end)
  end

  def decode_row(s, encoding \\ URLEncoding) do
    s |> String.strip |> String.split("\t") |> Enum.map(&encoding.decode/1)
  end
end
