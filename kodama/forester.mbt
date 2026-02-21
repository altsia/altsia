///|
// pub type Metadata = @hashmap.HashMap[String, @core.Term]

///|
pub fn forester_app_rewriter(
  name : @core.Name,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  match name {
    "today" => [@core.Term::Text(@date.today(), loc)]
    "ref" => {
      let _split = @core.Stage2Chisel::split_app_args(args)
      // TODO: local link - read target altsia file info (metadata) 
      [@core.Term::App(name, args, loc)]
    }
    _ => [@core.Term::App(name, args, loc)]
  }
}

///|
pub fn forester_pass(source : String) -> String raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
  |> @core.Stage2Extern::rewrite_apps(forester_app_rewriter)
  // |> @core.Stage2Extern::rewrite_apps(extern_api.to_rewriter())
  |> @core.Stage3::pass
  |> @core.Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> @core.MarkdownAbbrev::desugar
  // |> @core.Html::visit_text(text_rewriter)
  |> @core.Html::to_string
}
