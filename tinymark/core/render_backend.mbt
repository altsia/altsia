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
  compile_inline : (Array[Node]) -> Result[BackendOutput[Out, Head], Diagnostic]
  compile_block : (Array[Node]) -> Result[BackendOutput[Out, Head], Diagnostic]
  compile_block_at : (Array[Node], Int) -> Result[
    BackendOutput[Out, Head],
    Diagnostic,
  ]
  compile_mixed : (Array[Node]) -> Result[BackendOutput[Out, Head], Diagnostic]
  compile_text_only : (Array[Node]) -> Result[String, Diagnostic]
}

///|
pub(all) struct BackendCallContext[Out, Head] {
  call : BackendElementCall
  context : BackendCompileContext[Out, Head]
}

///|
pub type BackendElementResolver[Out, Head] = (BackendCallContext[Out, Head]) -> Result[
  BackendOutput[Out, Head]?,
  Diagnostic,
]

///|
pub(all) struct RenderBackend[Out, Head] {
  text : (String) -> Out
  interpolate_text : (Interpolation, CompileEnv, SourceSpan) -> Result[
    String,
    Diagnostic,
  ]
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
) -> Result[Array[Out], Diagnostic] {
  compile_backend_nodes_output(
    nodes, env, current_heading_level, wrap_inline_content, backend, extensions,
  ).map(output => output.body)
}

///|
pub fn[Out, Head] compile_backend_nodes_output(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> Result[BackendOutput[Out, Head], Diagnostic] {
  compile_backend_nodes_full(
    nodes,
    env,
    current_heading_level,
    wrap_inline_content,
    backend,
    extensions,
    doc_attr_mode=BindDocAttrs,
  ).map(compiled => {
    body: compiled.body,
    head: compiled.head,
    inline_body: compiled.inline_body,
  })
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
) -> Result[RenderedNodeSequence[Out, Head], Diagnostic] {
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
  let local_env = match
    visit_scoped_nodes(nodes, env, on_doc_attr, (node, local_env) => {
      match
        compile_backend_node(
          node, local_env, current_heading_level, backend, extensions,
        ) {
        Err(error) => return Err(error)
        Ok(compiled) => {
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
        }
      }
      Ok(())
    }) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  (backend.flush_inline_run)(inline_run, out)
  Ok({ body: out, head, doc_attrs, env: local_env, inline_body })
}

///|
fn[Out, Head] compile_backend_inline_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> Result[BackendOutput[Out, Head], Diagnostic] {
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
) -> Result[BackendOutput[Out, Head], Diagnostic] {
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
) -> Result[BackendOutput[Out, Head], Diagnostic] {
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
) -> Result[BackendOutput[Out, Head], Diagnostic] {
  match node {
    Text(text, _) => Ok(BackendOutput::body([(backend.text)(text)]))
    TextInterp(template, span) =>
      (backend.interpolate_text)(template, env, span).map(value => {
        BackendOutput::body([(backend.text)(value)])
      })
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
      match bool_binding(env, name, span) {
        Ok(true) =>
          compile_backend_inline_children(
            children, env, current_heading_level, backend, extensions,
          )
        Ok(false) => Ok(BackendOutput::empty())
        Err(error) => Err(error)
      }
    Unless(name, children, span) =>
      match bool_binding(env, name, span) {
        Ok(true) => Ok(BackendOutput::empty())
        Ok(false) =>
          compile_backend_inline_children(
            children, env, current_heading_level, backend, extensions,
          )
        Err(error) => Err(error)
      }
    Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => Ok(BackendOutput::empty())
  }
}

///|
fn[Out, Head] compile_backend_element(
  call : BackendElementCall,
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> Result[BackendOutput[Out, Head], Diagnostic] {
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
    let result = resolver(compiler)
    if result is Ok(Some(output)) {
      return Ok(output)
    }
    if result is Err(error) {
      return Err(error)
    }
  }
  match (backend.resolve_element)(compiler) {
    Ok(Some(output)) => Ok(output)
    Ok(None) =>
      Err(
        call.span.diagnostic(ContentModel, "unsupported element: " + call.tag),
      )
    Err(error) => Err(error)
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
) -> Result[BackendOutput[Out, Head], Diagnostic] {
  bind_template_call_env(template, attrs, children, call_env, call_span).bind(template_env => {
    compile_backend_inline_children(
      template.body,
      template_env,
      current_heading_level,
      backend,
      extensions,
    )
  })
}

///|
fn[Out, Head] compile_backend_text_only_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> Result[String, Diagnostic] {
  let parts : Array[String] = []
  match
    visit_scoped_nodes(children, env, _ => (), (child, local_env) => {
      let nodes = match
        compile_backend_node(
          child, local_env, current_heading_level, backend, extensions,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if !nodes.head.is_empty() {
        return Err(
          child.span().diagnostic(ContentModel, "expected plain text content"),
        )
      }
      for node in nodes.body {
        match (backend.output_text)(node) {
          Some(text) => parts.push(text)
          None =>
            return Err(
              child
              .span()
              .diagnostic(ContentModel, "expected plain text content"),
            )
        }
      }
      Ok(())
    }) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  Ok(parts.join(""))
}

///|
pub fn[Out, Head] compile_backend_value(
  value : Value,
  env : CompileEnv,
  current_heading_level : Int,
  backend : RenderBackend[Out, Head],
  extensions : Array[BackendElementResolver[Out, Head]],
) -> Result[BackendOutput[Out, Head], Diagnostic] {
  match value {
    Scalar(scalar, _) =>
      Ok(BackendOutput::body([(backend.text)(scalar.to_string())]))
    Interp(template, span) =>
      (backend.interpolate_text)(template, env, span).map(text => {
        BackendOutput::body([(backend.text)(text)])
      })
    Fragment(nodes, _) =>
      compile_backend_inline_children(
        nodes, env, current_heading_level, backend, extensions,
      )
  }
}
