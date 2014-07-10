defmodule DongraeTrader.HTTP do
  defmodule Request do
    defstruct method: nil, uri: nil, version: nil, headers: [], body: <<>>

    def get(uri) do
      %Request{method: :get, uri: uri, version: :http_1_1}
    end

    def post(uri, content_type, body) do
      body_length = IO.iodata_length(body)
      %Request{method: :post, uri: uri, version: :http_1_1,
               headers: [{:content_type, content_type}, {:content_length, to_string(body_length)}], body: body}
    end

    def encode(request) do
      [encode_request_line(request.method, request.uri, request.version),
       encode_headers(request.headers),
       "\r\n",
       request.body]
    end

    def encode_request_line(method, uri, version) do
      [case method do
         :options -> "OPTIONS"
         :get -> "GET"
         :head -> "HEAD"
         :post -> "POST"
         :put -> "PUT"
         :delete -> "DELETE"
       end,
       " ", uri,
       case version do
         :http_1_0 -> " HTTP/1.0"
         :http_1_1 -> " HTTP/1.1"
       end,
       "\r\n"]
    end

    def encode_headers(headers) do
      Enum.map(headers, fn header -> encode_header(header) end)
    end

    def encode_header({name, value}) do
      [to_string(name) |> String.split("_") |> Enum.map_join("-", &String.capitalize/1), ": ", value, "\r\n"]
    end
  end

  defmodule Response do
    defstruct version: nil, code: nil, reason: nil, headers: nil, body: nil

    def decode(input) do
      {:ok, [body, _, headers, status_line], rest} = {:ok, [], input}
                                                  |> decode_status_line
                                                  |> decode_headers
                                                  |> decode_pattern(~r/^\r\n/)
                                                  |> decode_body
      {version, code, reason} = status_line
      {:ok, %Response{version: version, code: code, reason: reason,
                      headers: headers, body: body}, rest}
    end

    def decode_status_line(state) do
      case state do
        {:ok, acc, input} ->
          next_state = {:ok, [], input}
                       |> decode_pattern(~r/^HTTP\/\d+\.\d+/)
                       |> decode_pattern(~r/^ /)
                       |> decode_pattern(~r/^\d+/)
                       |> decode_pattern(~r/^ /)
                       |> decode_pattern(~r/^[^\r]+/)
                       |> decode_pattern(~r/^\r\n/)
          case next_state do
            {:ok, [_, r, _, c, _, v], rest} ->
              {:ok, [{v |> string_to_version, String.to_integer(c), r}|acc], rest}
            :error -> :error
           end
        :error -> :error
      end
    end

    defp string_to_version(s) do
      s |> String.downcase |> String.replace(~r/\/|\./, "_") |> String.to_atom
    end

    def decode_headers(state) do
      case state do
        {:ok, acc, input} ->
          decode_headers(state, [])
        :error -> :error
      end
    end

    def decode_headers({:ok, acc, input}, headers) do
      case decode_header({:ok, [], input}) do
        {:ok, [header], rest} -> decode_headers({:ok, acc, rest}, [header|headers])
        :error -> {:ok, [Enum.reverse(headers)|acc], input}
      end
    end

    def decode_header(state) do
      case state do
        {:ok, acc, input} ->
          next_state = {:ok, [], input}
                       |> decode_pattern(~r/^[^:]+/)
                       |> decode_pattern(~r/^:\s+/)
                       |> decode_pattern(~r/^[^\r]+/)
                       |> decode_pattern(~r/^\r\n/)
          case next_state do
            {:ok, [_, value, _, name], rest} ->
              {:ok, [{name |> string_to_header_name, value}|acc], rest}
            :error -> :error
           end
        :error -> :error
      end
    end

    defp string_to_header_name(s) do
      s |> String.downcase |> String.replace("-", "_") |> String.to_atom
    end

    def decode_body(state) do
      case state do
        {:ok, [_crlf, headers, _status_line]=acc, input} ->
          body_length = Keyword.get(headers, :content_length, "0")
                        |> String.to_integer
          input_length = byte_size(input)
          if body_length > input_length  do
            :error
          else
            {body, rest} = String.split_at(input, body_length)
            {:ok, [body|acc], rest}
          end
        :error -> :error
      end
    end

    def decode_pattern(state, regex) do
      case state do
        {:ok, acc, input} ->
          case Regex.run(regex, input, return: :index) do
            [{s, l}] ->
              token = binary_part(input, s, l)
              rest = binary_part(input, s + l, byte_size(input) - (s + l))
              {:ok, [token|acc], rest}
            nil ->
              :error
          end
        :error ->
          :error
      end
    end
  end

  defmodule Connection do
    defstruct host: nil, port: nil, socket: nil

    def open(host, port) do
      {:ok, socket} = :gen_tcp.connect(to_char_list(host), port,
                                       [:binary, active: false])
      {:ok, %Connection{host: host, port: port, socket: socket}}
    end

    def close(conn) do
      :ok = :gen_tcp.close(conn.socket)
    end

    def call(conn, request) do
      :ok = :gen_tcp.send(conn.socket, Request.encode(request))
      {:ok, packet} = :gen_tcp.recv(conn.socket, 0)
      {:ok, response, <<>>} = Response.decode(packet)
      {:ok, response}
    end
  end
end