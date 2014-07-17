defmodule DongraeTrader.HTTP do
  defmodule Version do
    def to_string(version) do
      version |> Atom.to_string |> String.upcase
      |> String.replace("_", "/", global: false)
      |> String.replace("_", ".", global: false)
    end

    def from_string(s) do
      s |> String.downcase |> String.replace(~r/\/|\./, "_") |> String.to_atom
    end
  end

  defmodule Method do
    def to_string(method) do
      method |> Atom.to_string |> String.upcase
    end
  end

  defmodule Header do
    defmodule Name do
      def to_string(name) do
        name |> Atom.to_string
        |> String.split("_") |> Enum.map_join("-", &String.capitalize/1)
      end

      def from_string(s) do
        s |> String.downcase |> String.replace("-", "_") |> String.to_atom
      end
    end
  end

  defmodule Request do
    defstruct method: nil, uri: nil, version: nil, headers: [], body: <<>>

    def get(uri) do
      %Request{method: :get, uri: uri, version: :http_1_1}
    end

    def post(uri, content_type, body) do
      headers = [content_type: content_type,
                 content_length: IO.iodata_length(body)]
      %Request{method: :post, uri: uri, version: :http_1_1,
               headers: headers, body: body}
    end

    def encode(request) do
      [encode_request_line(request.method, request.uri, request.version),
       encode_headers(request.headers),
       "\r\n",
       request.body]
    end

    def encode_request_line(method, uri, version) do
      [Method.to_string(method),
       " ", uri,
       " ", Version.to_string(version), "\r\n"]
    end

    def encode_headers(headers) do
      Enum.map(headers, fn header -> encode_header(header) end)
    end

    def encode_header({name, value}) do
      [Header.Name.to_string(name), ": ", to_string(value), "\r\n"]
    end
  end

  defmodule Response do
    defstruct version: nil, code: nil, reason: nil, headers: nil, body: nil

    def decode(input) do
      result = sequence([&decode_status_line/1,
                         &decode_headers/1,
                         regex(~r/^\r\n/),
                         &decode_body/1]).({:ok, [], input})
      case result do
        {:ok, ast, rest} ->
          [body, _, headers, status_line] = ast
          {version, code, reason} = status_line
          {:ok, %Response{version: version, code: code, reason: reason,
                          headers: headers, body: body}, rest}
        {:error, _} = error -> error
      end
    end

    def decode_status_line({:ok, acc, input}) do
      next_state = sequence([regex(~r/^HTTP\/\d+\.\d+/),
                             regex(~r/^ /),
                             regex(~r/^\d+/),
                             regex(~r/^ /),
                             regex(~r/^[^\r]+/),
                             regex(~r/^\r\n/)]).({:ok, [], input})
      case next_state do
        {:ok, [_, r, _, c, _, v], rest} ->
          status_line = {Version.from_string(v), String.to_integer(c), r}
          {:ok, [status_line|acc], rest}
        {:error, _} = error -> error
      end
    end

    def decode_headers({:ok, acc, input}) do
      case zero_or_more(&decode_header/1).({:ok, [], input}) do
        {:ok, headers, rest} -> {:ok, [Enum.reverse(headers)|acc], rest}
      end
    end

    def decode_header({:ok, acc, input}) do
      next_state = sequence([regex(~r/^[^:]+/),
                             regex(~r/^:\s+/),
                             regex(~r/^[^\r]+/),
                             regex(~r/^\r\n/)]).({:ok, [], input})
      case next_state do
        {:ok, [_, value, _, name], rest} ->
          {:ok, [{name |> Header.Name.from_string, value}|acc], rest}
        {:error, _} = error -> error
      end
    end

    def decode_body({:ok, [_crlf, headers, _status_line]=acc, input}) do
      body_length = Keyword.get(headers, :content_length, "0")
                    |> String.to_integer
      input_length = byte_size(input)
      if body_length > input_length  do
        {:error, :unexpected_end_of_input}
      else
        {body, rest} = String.split_at(input, body_length)
        {:ok, [body|acc], rest}
      end
    end

    def regex(regex) do
      fn {:ok, acc, input} ->
        case Regex.run(regex, input, return: :index) do
          [{s, l}] ->
            token = binary_part(input, s, l)
            rest = binary_part(input, s + l, byte_size(input) - (s + l))
            {:ok, [token|acc], rest}
          nil ->
            reason = case input do
                       "" -> :unexpected_end_of_input
                       _ -> :unexpected_input
                     end
            {:error, reason}
        end
      end
    end

    def sequence(exprs) do
      fn state -> sequence_loop(exprs, state) end
    end

    defp sequence_loop(exprs, state) do
      case exprs do
        [] -> state
        [expr|expr_rest] ->
          case expr.(state) do
            {:ok, _, _} = result -> sequence_loop(expr_rest, result)
            {:error, _} = error -> error
          end
      end
    end

    def zero_or_more(expr) do
      fn state -> zero_or_more_loop(expr, state) end
    end

    defp zero_or_more_loop(expr, state) do
      case expr.(state) do
        {:ok, _, _} = result -> zero_or_more_loop(expr, result)
        {:error, _} -> state
      end
    end
  end

  defmodule Connection do
    defstruct host: nil, port: nil, socket: nil

    def open(host, port) do
      options = [:binary, active: false]
      case :gen_tcp.connect(to_char_list(host), port, options) do
        {:ok, socket} ->
          {:ok, %Connection{host: host, port: port, socket: socket}}
        {:error, _} = error -> error
      end
    end

    def close(conn) do
      :gen_tcp.close(conn.socket)
    end

    def call(conn, request) do
      case _send_request(conn, request) do
        :ok -> _recv_response(conn, <<>>)
        {:error, _} = error -> error
      end
    end

    def _send_request(conn, request) do
      send_buf = Request.encode(decorate_request(conn, request))
      :gen_tcp.send(conn.socket, send_buf)
    end

    def _recv_response(conn, recv_buf) do
      case :gen_tcp.recv(conn.socket, 0) do
        {:ok, packet} ->
          recv_buf = recv_buf <> packet
          case Response.decode(recv_buf) do
            {:ok, response, <<>>} -> {:ok, response}
            {:error, :unexpected_end_of_input} -> _recv_response(conn, recv_buf)
            {:error, _} = error -> error
            _ -> {:error, :unknown}
          end
        {:error, _} = error -> error
      end
    end

    def decorate_request(conn, request) do
      host_value = conn.host <> ":" <> to_string(conn.port)
      %{request | headers: Keyword.put_new(request.headers, :host, host_value)}
    end
  end
end