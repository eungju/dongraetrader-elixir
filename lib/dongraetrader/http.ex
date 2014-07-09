defmodule DongraeTrader.HTTP do
  defmodule Request do
    defstruct method: nil, uri: nil, version: nil, headers: [], body: <<>>

    def get(uri) do
      %Request{method: :get, uri: uri, version: :http_1_1}
    end

    def post(uri, content_type, body) do
      body_length = IO.iodata_length(body)
      %Request{method: :post, uri: uri, version: :http_1_1,
               headers: [{:content_type, content_type}, {:content_length, body_length}], body: body}
    end

    def encode(request) do
      [encode_request_line(request.method, request.uri, request.version),
       encode_headers(request.headers),
       "\n",
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
       "\n"]
    end

    def encode_headers(headers) do
      Enum.map(headers, fn header -> encode_header(header) end)
    end

    def encode_header({name, value}) do
      [to_string(name) |> String.split("_") |> Enum.map_join("-", &String.capitalize/1), ": ", to_string(value), "\n"]
    end
  end

  defmodule Response do
    defstruct version: nil, code: nil, reason: nil, headers: nil, body: nil

    def decode(buffer) do
      {:ok, %Response{}}
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

    def send_and_receive(conn, request) do
      :ok = :gen_tcp.send(conn.socket, Request.encode(request))
      {:ok, packet} = :gen_tcp.recv(conn.socket, 0)
      Response.decode(packet)
    end
  end
end