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
    import DongraeTrader.PEG

    def decode(input) do
      action = fn [body, headers, {version, code, reason}], [] ->
                 %Response{version: version, code: code, reason: reason,
                           headers: headers, body: body}
      end
      sequence([&decode_status_line/1,
                &decode_headers/1,
                regex(~r/\r\n/, &ignore/2),
                &decode_body/1], action).({[], input})
    end

    def decode_status_line({acc, input}) do
      action = transform_and_cons(fn [r, c, v] -> {Version.from_string(v), String.to_integer(c), r} end)
      sequence([regex(~r/HTTP\/\d+\.\d+/),
                regex(~r/ /, &ignore/2),
                regex(~r/\d+/),
                regex(~r/ /, &ignore/2),
                regex(~r/[^\r]+/),
                regex(~r/\r\n/, &ignore/2)], action).({acc, input})
    end

    def decode_headers({acc, input}) do
      action = transform_and_cons(&Enum.reverse/1)
      zero_or_more(&decode_header/1, action).({acc, input})
    end

    def decode_header({acc, input}) do
      action = transform_and_cons(fn [value, name] ->
                                    {name |> Header.Name.from_string, value}
                                  end)
      sequence([regex(~r/[^:]+/),
                regex(~r/:\s+/, &ignore/2),
                regex(~r/[^\r]+/),
                regex(~r/\r\n/, &ignore/2)], action).({acc, input})
    end

    def decode_body({[headers, _status_line]=acc, input}) do
      length = Keyword.get(headers, :content_length, "0") |> String.to_integer
      chunk(length).({acc, input})
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
            {:ok, {response, <<>>}} -> {:ok, response}
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