use "collections"
use http = "http"
use "net"
use "ssl/net"

primitive AuthFailed
primitive ConnectionClosed
primitive ConnectFailed

type FailureReason is (AuthFailed | ConnectionClosed | ConnectFailed)

class val Response
  let status: U16
  let headers: Map[String, String] val
  let body: ByteSeq

  new val create(status': U16, headers': Map[String, String] val,
    body': ByteSeq)
  =>
    status = status'
    headers = headers'
    body = body'

primitive Asking
  fun apply(auth: AmbientAuth,
    url: String,
    success: {(Response)} val,
    method: String = "GET",
    agent: String = "Pony httpget",
    body: (None | ByteSeq) = None,
    headers: Array[(String, String)] val = recover Array[(String, String)] end,
    failure: {(FailureReason)} val = {(reason: FailureReason) => None})?
  =>
    let sslctx = try
    recover val
      SSLContext
        .>set_client_verify(true)
        .>set_authority(None)?
      end
    end

    let url' = http.URL.valid(url)?

    let req = http.Payload.request(method, url')

    req("User-Agent") = agent

    for h in headers.values() do
      req(h._1) = h._2
    end

    match body
    | let bs: ByteSeq =>
      req.add_chunk(bs)
    end

    let sentreq =
      http.HTTPClient(TCPConnectAuth(auth), AskingNotifyFactory(success, failure), sslctx)(consume req)?

class AskingNotifyFactory is http.HandlerFactory
  let _success: {(Response)} val
  let _failure: {(FailureReason)} val

  new val create(success: {(Response)} val, failure: {(FailureReason)} val) =>
    _success = success
    _failure = failure

  fun apply(session: http.HTTPSession): http.HTTPHandler ref^ =>
    AskingNotify(session, _success, _failure)

class AskingNotify is http.HTTPHandler
  let _session: http.HTTPSession
  let _success: {(Response)} val
  let _failure: {(FailureReason)} val
  var _status: U16 = 0
  var _headers: Map[String, String] iso = recover Map[String, String] end
  var _body: Array[U8] iso = recover Array[U8] end

  new create(session: http.HTTPSession,
    success: {(Response)} val,
    failure: {(FailureReason)} val)
  =>
    _session = session
    _success = success
    _failure = failure

  fun ref apply(response: http.Payload val) =>
    _status = response.status
    _headers = recover Map[String, String] .> concat(response.headers().pairs()) end

    try
      for bs in response.body()?.values() do
        _body.append(bs)
      end
    end

    if response.transfer_mode is http.OneshotTransfer then
      _succeed()
    end

  fun ref chunk(data: ByteSeq) =>
    _body.append(data)

  fun ref finished() =>
    _succeed()

  fun failed(reason: http.HTTPFailureReason) =>
    let reason' = match reason
    | http.AuthFailed => AuthFailed
    | http.ConnectionClosed => ConnectionClosed
    | http.ConnectFailed => ConnectFailed
    end

    _failure(reason')

  fun ref _succeed() =>
    _success(Response(_status, _headers = recover Map[String, String] end, _body = recover Array[U8] end))
