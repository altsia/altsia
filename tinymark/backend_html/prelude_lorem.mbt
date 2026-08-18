///|
fn CallContext::compile_lorem(
  self : CallContext,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let lorem = @lorem.compile_lorem_text(
    call.attrs,
    call.children,
    context.env,
    call.span,
  )
  let html = HtmlNode::Element("span", @sexp.Attrs(Map([])), [
    @sexp.Text(lorem),
  ])
  ElementOutput::body([html])
}
