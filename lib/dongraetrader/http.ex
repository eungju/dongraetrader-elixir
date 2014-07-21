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
      %__MODULE__{method: :get, uri: uri, version: :http_1_1}
    end

    def post(uri, content_type, body) do
      headers = [content_type: content_type,
                 content_length: IO.iodata_length(body)]
      %__MODULE__{method: :post, uri: uri, version: :http_1_1,
                  headers: headers, body: body}
    end

    defmodule Encoder do
      def encode(request) do
        [encode_request_line(request.method, request.uri, request.version),
         encode_headers(request.headers),
         "\r\n",
         request.body]
      end

      def encode_request_line(method, uri, version) do
        [Method.to_string(method), " ", uri, " ", Version.to_string(version),
         "\r\n"]
      end

      def encode_headers(headers) do
        Enum.map(headers, fn header -> encode_header(header) end)
      end

      def encode_header({name, value}) do
        [Header.Name.to_string(name), ": ", to_string(value), "\r\n"]
      end
    end
  end

  defmodule Response do
    defstruct version: nil, code: nil, reason: nil, headers: nil, body: nil

    defmodule Decoder do
      import DongraeTrader.PEG

      def decode(input) do
        response({[], input})
      end

      def response({acc, input}) do
        action = fn [body, headers, {version, code, reason}], [] ->
                   %Response{version: version, code: code, reason: reason,
                             headers: headers, body: body}
        end
        sequence([&status_line/1,
                  &headers/1,
                  regex(~r/\r\n/, &ignore/2),
                  &body/1], action).({acc, input})
      end

      def status_line({acc, input}) do
        action = transform_and_cons(fn [reason, code, version] ->
                                      {version, code, reason}
                                    end)
        sequence([http_version,
                  regex(~r/ /, &ignore/2),
                  status_code,
                  regex(~r/ /, &ignore/2),
                  reason_phrase,
                  regex(~r/\r\n/, &ignore/2)], action).({acc, input})
      end

      defp http_version() do
        regex(~r/HTTP\/\d+\.\d+/, transform_and_cons(&Version.from_string/1))
      end

      defp status_code() do
        regex(~r/\d+/, transform_and_cons(&String.to_integer/1))
      end

      defp reason_phrase() do
        regex(~r/[^\r\n]+/)
      end

      def headers({acc, input}) do
        action = transform_and_cons(&Enum.reverse/1)
        zero_or_more(&header/1, action).({acc, input})
      end

      def header({acc, input}) do
        action = transform_and_cons(fn [value, name] ->
                                      {name |> Header.Name.from_string, value}
                                    end)
        sequence([regex(~r/[^:]+/),
                  regex(~r/:\s+/, &ignore/2),
                  regex(~r/[^\r]+/),
                  regex(~r/\r\n/, &ignore/2)], action).({acc, input})
      end

      def body({[headers, _status_line]=acc, input}) do
        length = Keyword.get(headers, :content_length, "0") |> String.to_integer
        bytes(length).({acc, input})
      end
    end
  end

  defmodule Connection do
    use GenServer

    defstruct host: nil, port: nil, socket: nil

    def start_link(host, port, opts \\ []) do
      GenServer.start_link(__MODULE__, {:ok, %__MODULE__{host: host, port: port}}, opts)
    end

    def call(server, request) do
      GenServer.call(server, {:call, request})
    end

    def stop(server) do
      GenServer.call(server, {:stop})
    end

    ## Callbacks

    def init({:ok, conn}) do
      options = [:binary, active: false]
      case :gen_tcp.connect(to_char_list(conn.host), conn.port, options) do
        {:ok, socket} -> {:ok, %{conn | socket: socket}}
        {:error, reason} -> {:stop, reason}
      end
    end

    def terminate(_reason, conn) do
      :gen_tcp.close(conn.socket)
    end

    def handle_call({:call, request}, _from, conn) do
      case _send_request(conn, request) do
        :ok ->
          case _recv_response(conn, <<>>) do
            {:ok, response} ->
              case Keyword.get(response.headers, :connection, "keep-alive") do
                "close" -> {:stop, :normal, {:ok, response}, conn}
                _ -> {:reply, {:ok, response}, conn}
              end
            {:error, reason} -> {:stop, reason, :error, conn}
          end
        {:error, reason} -> {:stop, reason, :error, conn}
      end
    end

    def handle_call({:stop}, _from, conn) do
      {:stop, :normal, :ok, conn}
    end

    def _send_request(conn, request) do
      send_buf = Request.Encoder.encode(decorate_request(conn, request))
      :gen_tcp.send(conn.socket, send_buf)
    end

    def _recv_response(conn, recv_buf) do
      case :gen_tcp.recv(conn.socket, 0) do
        {:ok, packet} ->
          recv_buf = recv_buf <> packet
          case Response.Decoder.decode(recv_buf) do
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