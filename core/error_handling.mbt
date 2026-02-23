///|
pub(all) struct RenderError {
  code : String
  phase : String
  message : String
  loc : SourceLoc?
  source_excerpt : String?
} derive(Eq, Show, Debug)

///|
let supported_languages : Array[String] = [
  "en", "en-US", "zh-CN", "zh-TW", "ja", "ko", "fr", "de", "es", "es-419", "it",
  "pt-PT", "pt-BR", "ru", "uk", "pl", "cs", "hu", "ro", "tr", "nl", "sv", "da", "nb",
  "fi", "el", "ar", "he", "hi", "th", "vi", "id", "ms",
]

///|
pub fn render_error_supported_languages() -> Array[String] {
  supported_languages
}

///|
fn localized(
  language : String,
  en : String,
  zh_cn : String,
  zh_tw : String,
  ja : String,
  ko? : String = "",
  fr? : String = "",
  de? : String = "",
  es? : String = "",
  pt? : String = "",
  ru? : String = "",
) -> String {
  let ko_msg = if ko == "" { en } else { ko }
  let fr_msg = if fr == "" { en } else { fr }
  let de_msg = if de == "" { en } else { de }
  let es_msg = if es == "" { en } else { es }
  let pt_msg = if pt == "" { en } else { pt }
  let ru_msg = if ru == "" { en } else { ru }
  let language = if supported_languages.contains(language) {
    language
  } else {
    "en"
  }
  match language {
    "zh-CN" => zh_cn
    "zh-TW" => zh_tw
    "ja" => ja
    "ko" => ko_msg
    "fr" => fr_msg
    "de" => de_msg
    "es" | "es-419" => es_msg
    "pt-PT" | "pt-BR" => pt_msg
    "ru" => ru_msg
    _ => en
  }
}

///|
fn source_excerpt_for(source : String, loc : SourceLoc?) -> String? {
  match loc {
    None => None
    Some(loc) => {
      let radius = 20
      let len = source.length()
      let start = if loc.start_offset - radius < 0 {
        0
      } else {
        loc.start_offset - radius
      }
      let end = if loc.end_offset + radius > len {
        len
      } else {
        loc.end_offset + radius
      }
      if start >= end {
        None
      } else {
        Some(source.unsafe_substring(start~, end~))
      }
    }
  }
}

///|
fn make_render_error(
  code : String,
  phase : String,
  message : String,
  loc : SourceLoc?,
  source : String,
) -> RenderError {
  { code, phase, message, loc, source_excerpt: source_excerpt_for(source, loc) }
}

///|
pub fn render_error(
  err : Error,
  source : String,
  language : String,
) -> RenderError {
  match err {
    Stage1Error::InvalidQuoteBlockStart(loc~) =>
      make_render_error(
        "stage1.invalid-quote-block-start",
        "stage1.parse",
        localized(
          language, "quote block must start with ```", "引用块必须以 ``` 开始",
          "引用區塊必須以 ``` 開始", "引用ブロックは ``` で始まる必要があります",
        ),
        Some(loc),
        source,
      )
    Stage1Error::InvalidApplicationStart(loc~) =>
      make_render_error(
        "stage1.invalid-application-start",
        "stage1.parse",
        localized(
          language, "application must start with (", "应用必须以 ( 开始",
          "應用必須以 ( 開始", "アプリケーションは ( で始まる必要があります",
        ),
        Some(loc),
        source,
      )
    Stage1Error::UnexpectedEof(context~, loc~) =>
      make_render_error(
        "stage1.unexpected-eof",
        "stage1.parse",
        localized(
          language,
          "unexpected EOF while parsing \{context}",
          "解析 \{context} 时遇到意外 EOF",
          "解析 \{context} 時遇到意外 EOF",
          "\{context} の解析中に予期しない EOF が発生しました",
        ),
        Some(loc),
        source,
      )
    Stage1Error::EmptyApplicationHead(loc~) =>
      make_render_error(
        "stage1.empty-application-head",
        "stage1.parse",
        localized(
          language, "application head cannot be empty", "应用头不能为空",
          "應用頭不能為空", "アプリケーションのヘッドは空にできません",
        ),
        Some(loc),
        source,
      )
    Stage1Error::UnclosedApplication(loc~) =>
      make_render_error(
        "stage1.unclosed-application",
        "stage1.parse",
        localized(
          language,
          "application is missing closing )",
          "应用缺少结束的 )",
          "應用缺少結束的 )",
          "アプリケーションの閉じ ) が不足しています",
          ko="애플리케이션에 닫는 ) 가 없습니다",
          fr="il manque ) pour fermer l'application",
          de="der schließende ) der Anwendung fehlt",
          es="falta ) de cierre en la aplicación",
          pt="falta ) de fechamento na aplicação",
          ru="в приложении отсутствует закрывающая )",
        ),
        Some(loc),
        source,
      )
    Stage1Error::UnclosedQuoteBlock(loc~) =>
      make_render_error(
        "stage1.unclosed-quote-block",
        "stage1.parse",
        localized(
          language, "quote block is missing closing ```", "引用块缺少结束的 ```",
          "引用區塊缺少結束的 ```", "引用ブロックの閉じ ``` が不足しています",
        ),
        Some(loc),
        source,
      )
    Stage1Error::UnclosedQuoteInline(loc~) =>
      make_render_error(
        "stage1.unclosed-quote-inline",
        "stage1.parse",
        localized(
          language, "inline quote is missing closing `", "行内引用缺少结束的 `",
          "行內引用缺少結束的 `", "インライン引用の閉じ ` が不足しています",
        ),
        Some(loc),
        source,
      )
    Stage1Error::QuoteBlockRequiresPrecedingApp(loc~) =>
      make_render_error(
        "stage1.quote-block-requires-preceding-app",
        "stage1.parse",
        localized(
          language, "quote block must follow a preceding application", "引用块必须跟在前一个应用之后",
          "引用區塊必須跟在前一個應用之後", "引用ブロックは直前のアプリケーションに続く必要があります",
        ),
        Some(loc),
        source,
      )
    Stage1Error::QuoteBlockMustFollowApp(loc~) =>
      make_render_error(
        "stage1.quote-block-must-follow-app",
        "stage1.parse",
        localized(
          language, "quote block can only be appended to an application", "引用块只能附加到应用节点",
          "引用區塊只能附加到應用節點", "引用ブロックはアプリケーションにのみ追加できます",
        ),
        Some(loc),
        source,
      )
    Stage1Error::UnexpectedTopLevelToken(token~, loc~) =>
      make_render_error(
        "stage1.unexpected-top-level-token",
        "stage1.parse",
        localized(
          language,
          "unexpected top-level token: \{token}",
          "顶层出现意外 token: \{token}",
          "頂層出現意外 token: \{token}",
          "トップレベルで予期しないトークン: \{token}",
          ko="최상위에서 예상치 못한 토큰: \{token}",
          fr="jeton de niveau supérieur inattendu : \{token}",
          de="unerwartetes Token auf oberster Ebene: \{token}",
          es="token inesperado en el nivel superior: \{token}",
          pt="token inesperado no nível superior: \{token}",
          ru="неожиданный токен верхнего уровня: \{token}",
        ),
        Some(loc),
        source,
      )
    Stage1NormalizeError::InvalidRange(
      start_offset~,
      end_offset~,
      source_length~,
      loc~
    ) =>
      make_render_error(
        "stage1.normalize.invalid-range",
        "stage1.normalize",
        localized(
          language,
          "invalid normalize range: start=\{start_offset}, end=\{end_offset}, source_length=\{source_length}",
          "invalid normalize range: start=\{start_offset}, end=\{end_offset}, source_length=\{source_length}",
          "invalid normalize range: start=\{start_offset}, end=\{end_offset}, source_length=\{source_length}",
          "invalid normalize range: start=\{start_offset}, end=\{end_offset}, source_length=\{source_length}",
        ),
        Some(loc),
        source,
      )
    Stage2Error::FunctionNameMustBePlainText(found~, loc~) =>
      make_render_error(
        "stage2.function-name-not-text",
        "stage2.elaborate",
        localized(
          language,
          "function name must be plain text: \{found}",
          "函数名必须是纯文本: \{found}",
          "函數名必須是純文本: \{found}",
          "関数名はプレーンテキストである必要があります: \{found}",
        ),
        loc,
        source,
      )
    Stage2Error::TemplateRequiresNameAndParamList(items~, loc~) =>
      make_render_error(
        "stage2.template-missing-header",
        "stage2.elaborate",
        localized(
          language,
          "template requires name and param list: \{items}",
          "模板需要名称和参数列表: \{items}",
          "模板需要名稱和參數列表: \{items}",
          "テンプレートには名前と引数リストが必要です: \{items}",
        ),
        loc,
        source,
      )
    Stage2Error::TemplateParamsMustBeList(found~, loc~) =>
      make_render_error(
        "stage2.template-params-not-list",
        "stage2.elaborate",
        localized(
          language,
          "template params must be a list: \{found}",
          "模板参数必须是列表: \{found}",
          "模板參數必須是列表: \{found}",
          "テンプレート引数はリストである必要があります: \{found}",
        ),
        loc,
        source,
      )
    Stage2Error::TemplateParamApplicationMissingHead(found~, loc~) =>
      make_render_error(
        "stage2.template-param-application-missing-head",
        "stage2.elaborate",
        localized(
          language,
          "template param application must have a head: \{found}",
          "template param application must have a head: \{found}",
          "template param application must have a head: \{found}",
          "template param application must have a head: \{found}",
        ),
        loc,
        source,
      )
    Stage2Error::InternalInvariantViolation(context~, loc~) =>
      make_render_error(
        "stage2.internal-invariant-violation",
        "stage2.elaborate",
        localized(
          language,
          "internal invariant violation: \{context}",
          "内部不变量被破坏: \{context}",
          "內部不變量被破壞: \{context}",
          "内部不変条件違反: \{context}",
        ),
        loc,
        source,
      )
    Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected~,
      got~,
      args~,
      loc~
    ) =>
      make_render_error(
        "stage2-etale.template-arity-mismatch",
        "stage2-etale.expand",
        localized(
          language,
          "template arity mismatch: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          "模板参数个数不匹配: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          "模板參數個數不匹配: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          "テンプレート引数個数不一致: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          ko="템플릿 인자 개수 불일치: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          fr="incohérence d'arité du template : template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          de="Template-Arity stimmt nicht: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          es="desajuste de aridad de plantilla: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          pt="incompatibilidade de aridade do template: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
          ru="несовпадение арности шаблона: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
        ),
        loc,
        source,
      )
    Stage2EtaleError::MissingNamedArgument(template_name~, param_name~, loc~) =>
      make_render_error(
        "stage2-etale.missing-named-argument",
        "stage2-etale.expand",
        localized(
          language,
          "missing named argument: template=\{template_name}, param=\{param_name}",
          "缺少具名参数: template=\{template_name}, param=\{param_name}",
          "缺少具名參數: template=\{template_name}, param=\{param_name}",
          "名前付き引数が不足しています: template=\{template_name}, param=\{param_name}",
        ),
        loc,
        source,
      )
    Stage2EtaleError::DuplicateNamedArgument(template_name~, param_name~, loc~) =>
      make_render_error(
        "stage2-etale.duplicate-named-argument",
        "stage2-etale.expand",
        localized(
          language,
          "duplicate named argument: template=\{template_name}, param=\{param_name}",
          "重复的具名参数: template=\{template_name}, param=\{param_name}",
          "重複的具名參數: template=\{template_name}, param=\{param_name}",
          "名前付き引数が重複しています: template=\{template_name}, param=\{param_name}",
        ),
        loc,
        source,
      )
    Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~, loc~) =>
      make_render_error(
        "stage2-etale.nested-template-definition",
        "stage2-etale.expand",
        localized(
          language,
          "nested template definition is not allowed in substitution: \{term}",
          "替换阶段不允许嵌套模板定义: \{term}",
          "替換階段不允許巢狀模板定義: \{term}",
          "置換中のネストしたテンプレート定義は許可されません: \{term}",
        ),
        loc,
        source,
      )
    Stage2EtaleError::UnexpectedTemplateDefinitionInExpand(term~, loc~) =>
      make_render_error(
        "stage2-etale.unexpected-template-definition",
        "stage2-etale.expand",
        localized(
          language,
          "unexpected template definition during expansion: \{term}",
          "展开阶段出现意外模板定义: \{term}",
          "展開階段出現意外模板定義: \{term}",
          "展開中に予期しないテンプレート定義が見つかりました: \{term}",
        ),
        loc,
        source,
      )
    Stage3Error::AttributeExpectsAtMostOneValue(values~, loc~) =>
      make_render_error(
        "stage3.attribute-too-many-values",
        "stage3.lower",
        localized(
          language,
          "attribute expects at most one value: \{values}",
          "属性最多只能有一个值: \{values}",
          "屬性最多只能有一個值: \{values}",
          "属性は最大 1 つの値のみ許可されます: \{values}",
          ko="속성은 최대 하나의 값만 허용합니다: \{values}",
          fr="un attribut attend au plus une valeur : \{values}",
          de="ein Attribut erwartet höchstens einen Wert: \{values}",
          es="un atributo acepta como máximo un valor: \{values}",
          pt="um atributo aceita no máximo um valor: \{values}",
          ru="атрибут допускает не более одного значения: \{values}",
        ),
        loc,
        source,
      )
    Stage3Error::UnexpectedTemplateDefinition(term~, loc~) =>
      make_render_error(
        "stage3.unexpected-template-definition",
        "stage3.lower",
        localized(
          language,
          "unexpected template definition during lowering: \{term}",
          "降级阶段出现意外模板定义: \{term}",
          "降級階段出現意外模板定義: \{term}",
          "lowering 中に予期しないテンプレート定義が見つかりました: \{term}",
        ),
        loc,
        source,
      )
    Failure::Failure(message) =>
      make_render_error("failure", "runtime", message, None, source)
    _ =>
      make_render_error(
        "unknown",
        "runtime",
        localized(
          language,
          "unknown error: \{err}",
          "未知错误: \{err}",
          "未知錯誤: \{err}",
          "不明なエラー: \{err}",
        ),
        None,
        source,
      )
  }
}

///|
pub fn render_error_to_string(err : RenderError) -> String {
  match err.loc {
    Some(loc) => "[\{err.phase}] \{loc.line}:\{loc.column}: \{err.message}"
    None => "[\{err.phase}] \{err.message}"
  }
}
