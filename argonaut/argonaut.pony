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
