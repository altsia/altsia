///|
test {
  let source =
    #|
    #|---
    #|title: 格点三元组计数
    #|date: May 17, 2020
    #|taxon: proposition
    #|author: [kokic](/trees/kokic.md)
    #|tag: [](/trees/pearls.md)
    #|---
    #|
    #|$\gdef\spaces#1{~ #1 ~}$
    #|
    #|设 $n$ 是非负整数. $\mathcal{A}_n$ 是满足 $a+b,a+c,b+c \le n+1$ 的正整数三元组 $(a, b, c)$. 则 
    #|
    #|$$ |\mathcal{A}_n| \spaces= \frac{n}{8}(2n^2 + 3n + 2) + \frac{\delta_n}{8} $$
    #|
    #|此处 $n$ 为偶数时 $\delta = 0$, $n$ 为奇数时 $\delta = 1$. 
    #|

  let source = @markdown.KoMarkdown::to_altsia(source)

  let context = @kodama.ContextApi::{
    doc_workspace_path: "notes/a.alt",
    docs: [],
  }
  let html = kodama_to_html(
    source,
    context,
    s => s,
    extern_api=@core.test_extern_api(),
  )
  println(html)
}
