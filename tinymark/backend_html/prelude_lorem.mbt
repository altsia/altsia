///|
fn CallContext::compile_lorem(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  @lorem.compile_lorem_text(call.attrs, call.children, context.env, call.span).map(lorem => {
      let html = HtmlNode::Element("span", @sexp.HtmlAttrs({}), [
        @sexp.Text(lorem),
      ])
      ElementOutput::body([html])
    },
  )
}
