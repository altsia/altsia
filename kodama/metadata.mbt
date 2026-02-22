///|
pub(all) struct DocMetadata {
  named_args : Array[@core.NamedAppArg]
} derive(Eq, Show, Debug)

///|
pub fn extract_doc_metadata_from_terms(
  terms : Array[@core.Term],
) -> DocMetadata {
  let named_args : Array[@core.NamedAppArg] = []
  for term in terms {
    match term {
      @core.Term::App("metadata", args, _) => {
        let split = @core.Stage2Chisel::split_app_args(args)
        for entry in split.named.to_array() {
          named_args.push(entry.1)
        }
      }
      _ => ()
    }
  }
  DocMetadata::{ named_args, }
}

///|
pub fn DocMetadata::get(
  metadata : DocMetadata,
  key : String,
) -> @core.NamedAppArg? {
  let lookup = normalize_named_arg_key(key)
  for entry in metadata.named_args {
    if entry.name == lookup {
      return Some(entry)
    }
  }
  None
}

///|
pub fn DocMetadata::get_plain_text(
  metadata : DocMetadata,
  key : String,
) -> String? {
  metadata
  .get(key)
  .bind(named => {
    let text = terms_plain_text(named.values)
    ite_eager(text.is_empty(), None, Some(text))
  })
}
