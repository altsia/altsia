///|
/// `\math<family>{...}` for the atom family, and recognition of the
/// `\overset`/`\underset`/`\stackrel` shapes (`MClass` wrapping a `SupSub`
/// over an operator body) so those constructs round-trip as themselves.
fn render_mclass(
  mclass : @katex.AtomFamily,
  body : Array[@katex.ParseNode],
) -> String {
  match body {
    [
      @katex.ParseNode::SupSub(
        base=Some(
          @katex.ParseNode::Op(
            content=@katex.OperatorContent::BodyOperator(operator),
            ..
          )
        ),
        sup~,
        sub~,
        ..
      ),
    ] => render_stackrel(mclass, operator, sup, sub)
    // `\boldsymbol` wraps its `\math..` class and `Font("boldsymbol")`; a
    // `\mathord{...}` re-emission would nest on re-parse since `\boldsymbol`
    // rebuilds its own class wrapper.
    [@katex.ParseNode::Font(font="boldsymbol", body=inner, ..)] =>
      "\\boldsymbol{\{render_arg(inner)}}"
    _ => "\{mclass_command(mclass)}{\{render_nodes(body)}}"
  }
}

///|
/// The `\math<family>` command for an atom family. The family name from the
/// shared table carries a leading `m` (`mord`, `mrel`, ...), which is not part
/// of the KaTeX command.
fn mclass_command(mclass : @katex.AtomFamily) -> String {
  match mclass {
    @katex.AtomFamily::Mord => "\\mathord"
    @katex.AtomFamily::Mop => "\\mathop"
    @katex.AtomFamily::Mbin => "\\mathbin"
    @katex.AtomFamily::Mrel => "\\mathrel"
    @katex.AtomFamily::Mopen => "\\mathopen"
    @katex.AtomFamily::Mclose => "\\mathclose"
    @katex.AtomFamily::Mpunct => "\\mathpunct"
    @katex.AtomFamily::Minner => "\\mathinner"
  }
}

///|
fn render_stackrel(
  mclass : @katex.AtomFamily,
  operator : Array[@katex.ParseNode],
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
) -> String {
  let base = render_nodes(operator)
  match (sup, sub) {
    (Some(sup), None) =>
      "\{if mclass == @katex.AtomFamily::Mrel { "\\stackrel" } else { "\\overset" }}{\{render_arg(sup)}}{\{base}}"
    (None, Some(sub)) => "\\underset{\{render_arg(sub)}}{\{base}}"
    _ => "\\mathop{\{base}}"
  }
}

///|
fn render_op(content : @katex.OperatorContent, limits : Bool) -> String {
  let _ = limits
  match content {
    SymbolOperator(text) | NamedOperator(text) => text
    BodyOperator(body) => "\\mathop{\{render_nodes(body)}}"
  }
}

///|

///|
/// `\operatorname*` (the limits variant) is recorded in `always_handle_sup_sub`
/// rather than `limits`.
fn render_operator_name(
  body : Array[@katex.ParseNode],
  with_limits : Bool,
) -> String {
  let star = if with_limits { "*" } else { "" }
  "\\operatorname\{star}{\{join_tight(body.map(render_node))}}"
}
