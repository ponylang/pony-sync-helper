class Interpolate
  let _template: String

  new create(template: String) =>
    _template = template

  fun apply(args: Iterator[Stringable]): String iso^ =>
    let output: String iso = _template.clone()

    for arg in args do
      output.replace("{}", arg.string(), 1)
    end

    consume output
