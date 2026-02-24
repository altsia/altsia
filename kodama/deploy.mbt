// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
/// Deployment options for turning local `ref` targets into deployed hrefs.
/// `base_url` is a deployment prefix (for example `/docs`).
/// `pretty_url` controls whether `.alt` links keep a `.html` suffix:
/// - `false`: `a.alt` -> `a.html`
/// - `true`:  `a.alt` -> `a`
pub(all) struct ForesterDeployOptions {
  base_url : String
  pretty_url : Bool
} derive(Eq, Show, Debug)

///|
/// Prepared href values for one `ref` target.
/// `authored_href` and `local_href` are the original value in authoring preview.
/// `deploy_href` is the deployment-time href transformed by `ForesterDeployOptions`.
pub(all) struct RefHrefPlan {
  authored_href : String
  local_href : String
  deploy_href : String
} derive(Eq, Show, Debug)

///|
fn split_href_path_and_suffix(href : String) -> (String, String) {
  let mut split_index = href.length()
  for i in 0..<href.length() {
    let ch = href.get_char(i).unwrap()
    if ch == '?' || ch == '#' {
      split_index = i
      break
    }
  }
  if split_index == href.length() {
    (href, "")
  } else {
    (
      href.unsafe_substring(start=0, end=split_index),
      href.unsafe_substring(start=split_index, end=href.length()),
    )
  }
}

///|
fn trim_trailing_slashes(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    if s.get_char(end - 1).unwrap() != '/' {
      break
    }
    end -= 1
  }
  if end == s.length() {
    s
  } else {
    s.unsafe_substring(start=0, end~)
  }
}

///|
fn trim_leading_slashes(s : String) -> String {
  let mut start = 0
  while start < s.length() {
    if s.get_char(start).unwrap() != '/' {
      break
    }
    start += 1
  }
  if start == 0 {
    s
  } else {
    s.unsafe_substring(start~, end=s.length())
  }
}

///|
fn apply_pretty_url(path : String, pretty_url : Bool) -> String {
  let (head, tail) = split_href_path_and_suffix(path)
  if !head.has_suffix(".alt") {
    return path
  }
  let stem = head.unsafe_substring(start=0, end=head.length() - 4)
  if pretty_url {
    stem + tail
  } else {
    stem + ".html" + tail
  }
}

///|
fn prefix_base_url(base_url : String, path : String) -> String {
  if base_url.is_empty() {
    return path
  }
  let normalized_base = trim_trailing_slashes(base_url)
  let normalized_path = trim_leading_slashes(path)
  if normalized_base.is_empty() {
    if normalized_path.is_empty() {
      "/"
    } else {
      "/" + normalized_path
    }
  } else if normalized_path.is_empty() {
    normalized_base
  } else {
    normalized_base + "/" + normalized_path
  }
}

///|
pub fn ForesterDeployOptions::to_deploy_href(
  options : ForesterDeployOptions,
  authored_href : String,
) -> String {
  let with_suffix = apply_pretty_url(authored_href, options.pretty_url)
  prefix_base_url(options.base_url, with_suffix)
}

///|
pub fn ForesterDeployOptions::plan_ref_href(
  options : ForesterDeployOptions,
  authored_href : String,
) -> RefHrefPlan {
  let deploy_href = options.to_deploy_href(authored_href)
  RefHrefPlan::{ authored_href, local_href: authored_href, deploy_href }
}
