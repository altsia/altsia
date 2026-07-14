///|
pub(all) enum BackendElementSource {
  RefElement
  ExplicitElement
}

///|
pub(all) struct BackendElementCall {
  tag : String
  attrs : Array[Attr]
  children : Array[Node]
  span : SourceSpan
  source : BackendElementSource
}

///|
pub(all) struct BackendOutput[Out, Head] {
  body : Array[Out]
  head : Array[Head]
  inline_body : Bool
}

///|
pub(all) struct BackendCompileContext[Out, Head] {
  env : CompileEnv
  current_heading_level : Int
  compile_inline : (Array[Node]) -> BackendOutput[Out, Head] raise Diagnostic
  compile_block : (Array[Node]) -> BackendOutput[Out, Head] raise Diagnostic
  compile_block_at : (Array[Node], Int) -> BackendOutput[Out, Head] raise Diagnostic
  compile_mixed : (Array[Node]) -> BackendOutput[Out, Head] raise Diagnostic
  compile_text_only : (Array[Node]) -> String raise Diagnostic
}

///|
pub(all) struct BackendCallContext[Out, Head] {
  call : BackendElementCall
  context : BackendCompileContext[Out, Head]
}

///|
pub type BackendElementResolver[Out, Head] = (BackendCallContext[Out, Head]) -> BackendOutput[
  Out,
  Head,
]? raise Diagnostic

///|
pub(all) struct RenderBackend[Out, Head] {
  text : (String) -> Out
  interpolate_text : (Interpolation, CompileEnv, SourceSpan) -> String raise Diagnostic
  append_inline_node : (Array[Out], Array[Out], Out) -> Unit
  flush_inline_run : (Array[Out], Array[Out]) -> Unit
  output_text : (Out) -> String?
  resolve_element : BackendElementResolver[Out, Head]
}

///|
pub(all) struct RenderedNodeSequence[Out, Head] {
  body : Array[Out]
  head : Array[Head]
  doc_attrs : Array[Attr]
  env : CompileEnv
  inline_body : Bool
}

///|
pub(all) enum DocAttrMode {
  BindDocAttrs
  CollectDocAttrs
}

///|
pub fn[Out, Head] BackendOutput::empty() -> BackendOutput[Out, Head] {
  { body: [], head: [], inline_body: true }
}

///|
pub fn[Out, Head] BackendOutput::body(
  nodes : Array[Out],
) -> BackendOutput[Out, Head] {
  { body: nodes, head: [], inline_body: true }
}

///|
pub fn[Out, Head] BackendOutput::flow(
  nodes : Array[Out],
) -> BackendOutput[Out, Head] {
  { body: nodes, head: [], inline_body: false }
}

///|
pub fn[Out, Head] BackendOutput::head(
  nodes : Array[Head],
) -> BackendOutput[Out, Head] {
  { body: [], head: nodes, inline_body: true }
}

///|
pub fn[Out, Head] compile_backend_nodes(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> Array[Out] raise Diagnostic {
  compile_backend_nodes_output(
    nodes, env, current_heading_level, wrap_inline_content, backend, extensions,
  ).body
}

///|
pub fn[Out, Head] compile_backend_nodes_output(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  let compiled = compile_backend_nodes_full(
    nodes,
    env,
    current_heading_level,
    wrap_inline_content,
    backend,
    extensions,
    doc_attr_mode=BindDocAttrs,
  )
  {
    body: compiled.body,
    head: compiled.head,
    inline_body: compiled.inline_body,
  }
}

///|
pub fn[Out, Head] compile_backend_nodes_full(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
  doc_attr_mode~ : DocAttrMode,
) -> RenderedNodeSequence[Out, Head] raise Diagnostic {
  let out : Array[Out] = []
  let head : Array[Head] = []
  let doc_attrs : Array[Attr] = []
  let inline_run : Array[Out] = []
  let mut inline_body = true
  let on_doc_attr = attr => {
    if doc_attr_mode is CollectDocAttrs {
      doc_attrs.push(attr)
    }
  }
  let local_env = visit_scoped_nodes(nodes, env, on_doc_attr, (node, local_env) => {
    let compiled = compile_backend_node(
      node, local_env, current_heading_level, backend, extensions,
    )
    head.append(compiled.head)
    if compiled.inline_body {
      guard wrap_inline_content else { out.append(compiled.body) }
      for node in compiled.body {
        (backend.append_inline_node)(inline_run, out, node)
      }
    } else {
      inline_body = false
      (backend.flush_inline_run)(inline_run, out)
      out.append(compiled.body)
    }
  })
  (backend.flush_inline_run)(inline_run, out)
  { body: out, head, doc_attrs, env: local_env, inline_body }
}

///|
fn[Out, Head] compile_backend_inline_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  compile_backend_nodes_output(
    children, env, current_heading_level, false, backend, extensions,
  )
}

///|
fn[Out, Head] compile_backend_block_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  compile_backend_nodes_output(
    children, env, current_heading_level, false, backend, extensions,
  )
}

///|
fn[Out, Head] compile_backend_mixed_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  compile_backend_nodes_output(
    children, env, current_heading_level, false, backend, extensions,
  )
}

///|
fn[Out, Head] compile_backend_node(
  node : Node,
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  match node {
    Text(text, _) => BackendOutput::body([(backend.text)(text)])
    TextInterp(template, span) => {
      let value = (backend.interpolate_text)(template, env, span)
      BackendOutput::body([(backend.text)(value)])
    }
    Ref(name, span) => {
      if env.lookup_value(name) is Some(value) {
        return compile_backend_value(
          value, env, current_heading_level, backend, extensions,
        )
      }
      if env.lookup_template(name) is Some(template) {
        return expand_backend_template(
          template,
          [],
          [],
          env,
          current_heading_level,
          span,
          backend,
          extensions,
        )
      }
      compile_backend_element(
        { tag: name, attrs: [], children: [], span, source: RefElement },
        env,
        current_heading_level,
        backend,
        extensions,
      )
    }
    Element(tag, attrs, children, span) => {
      if env.lookup_template(tag) is Some(template) {
        return expand_backend_template(
          template, attrs, children, env, current_heading_level, span, backend, extensions,
        )
      }
      compile_backend_element(
        { tag, attrs, children, span, source: ExplicitElement },
        env,
        current_heading_level,
        backend,
        extensions,
      )
    }
    When(name, children, span) =>
      if bool_binding(env, name, span) {
        compile_backend_inline_children(
          children, env, current_heading_level, backend, extensions,
        )
      } else {
        BackendOutput::empty()
      }
    Unless(name, children, span) =>
      if bool_binding(env, name, span) {
        BackendOutput::empty()
      } else {
        compile_backend_inline_children(
          children, env, current_heading_level, backend, extensions,
        )
      }
    Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => BackendOutput::empty()
  }
}

///|
fn[Out, Head] compile_backend_element(
  call : BackendElementCall,
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  let context : BackendCompileContext[Out, Head] = {
    env,
    current_heading_level,
    compile_inline: children => {
      compile_backend_inline_children(
        children, env, current_heading_level, backend, extensions,
      )
    },
    compile_block: children => {
      compile_backend_block_children(
        children, env, current_heading_level, backend, extensions,
      )
    },
    compile_block_at: (children, heading_level) => {
      compile_backend_block_children(
        children, env, heading_level, backend, extensions,
      )
    },
    compile_mixed: children => {
      compile_backend_mixed_children(
        children, env, current_heading_level, backend, extensions,
      )
    },
    compile_text_only: children => {
      compile_backend_text_only_children(
        children, env, current_heading_level, backend, extensions,
      )
    },
  }
  let compiler = BackendCallContext::{ call, context }
  for resolver in extensions {
    if resolver(compiler) is Some(output) {
      return output
    }
  }
  match (backend.resolve_element)(compiler) {
    Some(output) => output
    None =>
      raise call.span.diagnostic(
        ContentModel,
        "unsupported element: " + call.tag,
      )
  }
}

///|
fn[Out, Head] expand_backend_template(
  template : Template,
  attrs : Array[Attr],
  children : Array[Node],
  call_env : CompileEnv,
  current_heading_level : Int,
  call_span : SourceSpan,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  let template_env = bind_template_call_env(
    template, attrs, children, call_env, call_span,
  )
  compile_backend_inline_children(
    template.body,
    template_env,
    current_heading_level,
    backend,
    extensions,
  )
}

///|
fn[Out, Head] compile_backend_text_only_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> String raise Diagnostic {
  let parts : Array[String] = []
  ignore(
    visit_scoped_nodes(children, env, _ => (), (child, local_env) => {
      let nodes = compile_backend_node(
        child, local_env, current_heading_level, backend, extensions,
      )
      if !nodes.head.is_empty() {
        raise child
          .span()
          .diagnostic(ContentModel, "expected plain text content")
      }
      for node in nodes.body {
        match (backend.output_text)(node) {
          Some(text) => parts.push(text)
          None =>
            raise child
              .span()
              .diagnostic(ContentModel, "expected plain text content")
        }
      }
    }),
  )
  parts.join("")
}

///|
pub fn[Out, Head] compile_backend_value(
  value : Value,
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> BackendOutput[Out, Head] raise Diagnostic {
  match value {
    Scalar(scalar, _) =>
      BackendOutput::body([(backend.text)(scalar.to_string())])
    Interp(template, span) => {
      let text = (backend.interpolate_text)(template, env, span)
      BackendOutput::body([(backend.text)(text)])
    }
    Fragment(nodes, _) =>
      compile_backend_inline_children(
        nodes, env, current_heading_level, backend, extensions,
      )
  }
}
