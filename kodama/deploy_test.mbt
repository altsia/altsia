// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
test "ForesterDeployOptions keeps authored href for local preview" {
  let options = ForesterDeployOptions::{ base_url: "/docs", pretty_url: false }
  let plan = options.plan_ref_href("notes/a.alt")
  assert_eq(plan.authored_href, "notes/a.alt")
  assert_eq(plan.local_href, "notes/a.alt")
}

///|
test "ForesterDeployOptions adds base_url and html suffix when pretty_url is false" {
  let options = ForesterDeployOptions::{ base_url: "/docs", pretty_url: false }
  let plan = options.plan_ref_href("notes/a.alt")
  assert_eq(plan.deploy_href, "/docs/notes/a.html")
}

///|
test "ForesterDeployOptions omits html suffix when pretty_url is true" {
  let options = ForesterDeployOptions::{ base_url: "/docs", pretty_url: true }
  let plan = options.plan_ref_href("notes/a.alt#head")
  assert_eq(plan.deploy_href, "/docs/notes/a#head")
}

///|
test "ForesterDeployOptions keeps non-alt links unchanged except base_url prefix" {
  let options = ForesterDeployOptions::{ base_url: "/docs", pretty_url: false }
  let plan = options.plan_ref_href("notes/a")
  assert_eq(plan.deploy_href, "/docs/notes/a")
}
