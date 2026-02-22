///|
pub type SmartPunctuation

///|
fn smart_punctuation_text(value : String) -> String {
  value
  .replace_all(old="---", new="—")
  .replace_all(old="--", new="–")
  .replace_all(old="...", new="…")
}

///|
fn smart_punctuation_is_protected_name(name : String) -> Bool {
  is_extern(name) ||
  name == "code" ||
  name == "pre" ||
  name == "k" ||
  name == "kd" ||
  name == "script" ||
  name == "style"
}

///|
fn smart_punctuation_inline(
  node : InlineNode,
  in_protected_scope : Bool,
) -> InlineNode {
  match node {
    Text(text) =>
      Text(if in_protected_scope { text } else { smart_punctuation_text(text) })
    Span({ name, attrs, children }) => {
      let next_scope = in_protected_scope ||
        smart_punctuation_is_protected_name(name)
      Span({
        name,
        attrs,
        children: children.map(child => {
          smart_punctuation_inline(child, next_scope)
        }),
      })
    }
  }
}

///|
fn smart_punctuation_block(node : BlockNode) -> BlockNode {
  match node {
    Paragraph(inlines) =>
      Paragraph(inlines.map(inline => smart_punctuation_inline(inline, false)))
    Container({ name, attrs, children }) => {
      let protected_scope = smart_punctuation_is_protected_name(name)
      Container({
        name,
        attrs,
        children: children.map(child => {
          smart_punctuation_inline(child, protected_scope)
        }),
      })
    }
  }
}

///|
pub fn SmartPunctuation::pass(doc : Doc) -> Doc {
  doc.map(piece => {
    match piece {
      Inline(inline) => Inline(smart_punctuation_inline(inline, false))
      Block(block) => Block(smart_punctuation_block(block))
      Comment(_) => piece
    }
  })
}
