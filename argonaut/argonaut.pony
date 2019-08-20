use "collections"
use "json"

primitive Extract
  fun apply(obj: JsonType, path: Iterator[(String | USize)]): JsonType ? =>
    let key_or_idx = try
      path.next()?
    else
      return obj
    end

    let new_obj = match (obj, key_or_idx)
    | (let a: JsonArray, let idx: USize) =>
      (a.data)(idx)?
    | (let o: JsonObject, let key: String) =>
      (o.data)(key)?
    else
      error
    end

    apply(new_obj, path)?

class val Extractor
  let _json: JsonType val

  new val create(json: JsonType val) =>
    _json = json

  fun val apply(idx_or_key: (String | USize)): Extractor val ? =>
    match (_json, idx_or_key)
    | (let a: JsonArray val, let idx: USize) =>
      Extractor((a.data)(idx)?)
    | (let o: JsonObject val, let key: String) =>
      Extractor((o.data)(key)?)
    else
      error
    end

  fun val size(): USize ? =>
    match _json
    | let a: JsonArray val =>
      a.data.size()
    | let o: JsonObject val =>
      o.data.size()
    else
      error
    end

  fun val values(): Iterator[JsonType val] ? =>
    match _json
    | let a: JsonArray val =>
      a.data.values()
    else
      error
    end

  fun val pairs(): Iterator[(String, JsonType val)] ? =>
    match _json
    | let o: JsonObject val =>
      o.data.pairs()
    else
      error
    end

  fun val as_array(): Array[JsonType] val ? =>
    match _json
    | let a: JsonArray val =>
      a.data
    else
      error
    end

  fun val as_object(): Map[String, JsonType] val ? =>
    match _json
    | let o: JsonObject val =>
      o.data
    else
      error
    end

  fun val as_string(): String ? =>
    _json as String

  fun val as_none(): None ? =>
    _json as None

  fun val as_f64(): F64 ? =>
    _json as F64

  fun val as_i64(): I64 ? =>
    _json as I64

  fun val as_bool(): Bool ? =>
    _json as Bool
