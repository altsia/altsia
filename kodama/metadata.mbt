///|
pub(all) struct DocMetadata {
  named : Array[@core.NamedAppArg]
} derive(Eq, Show, Debug)

///|
pub fn extract_doc_metadata_from_terms(
  terms : Array[@core.Term],
) -> DocMetadata {
  let named : Array[@core.NamedAppArg] = []
  for term in terms {
    match term {
      @core.Term::App("metadata", args, _) => {
        let split = @core.Stage2Chisel::split_app_args(args)
        named.append(split.named)
      }
      _ => ()
    }
  }
  DocMetadata::{ named }
}

///|
fn normalize_metadata_key(key : String) -> String {
  if key.has_prefix(":") {
    key
  } else {
    ":\{key}"
  }
}

///|
pub fn DocMetadata::get(
  metadata : DocMetadata,
  key : String,
) -> @core.NamedAppArg? {
  let lookup = normalize_metadata_key(key)
  for entry in metadata.named {
    if entry.name == lookup {
      return Some(entry)
    }
  }
  None
}
