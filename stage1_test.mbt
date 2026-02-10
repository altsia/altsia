///|
test "Parsing stage 1 per component" {
  assert_eq("(canta per me ne addio)" |> Stage1::parse, [
    App(@list.from_array([Text("canta"), Text("per me ne addio")])),
  ])
  assert_eq(
    (
      #|()
      #|```
      #|羽を休めることを
      #|雲雀は知らないの
      #|```
    )
    |> Stage1::parse,
    [
      App(
        @list.from_array([
          Block("羽を休めることを\n雲雀は知らないの\n"),
        ]),
      ),
    ],
  )
  assert_eq(
    (
      #|(★ étoile et toi \(et toi et moi\))
      #|
      #|```
      #|le monde est vous
      #|(vous êtes le monde)
      #|```
    )
    |> Stage1::parse,
    [
      App(
        @list.from_array([
          Text("★"),
          Text("étoile et toi (et toi et moi)"),
          Block("le monde est vous\n(vous êtes le monde)\n"),
        ]),
      ),
    ],
  )
}

///|
test "Parsing stage 1" {
  assert_eq(
    (
      #|(∎ Everytime you kissed me
      #|   I trembled like a child
      #|   (∎ Gathering the roses
      #|      We sang for the hope))
      #|
      #|```
      #|Your very voice is in my heartbeat
      #|Sweeter than my dream
      #|We were there, in everlasting bloom
      #|```
      #|
      #|```
      #|Roses die
      #|The secret is inside the pain
      #|Winds are high up on the hill
      #|I cannot hear you
      #|```
      #|
      #|(- Come and hold me close)
      #|(- I'm shivering cold in the heart of rain)
      #|(- Darkness falls, I'm calling for the dawn (Ω))
    )
    |> Stage1::parse,
    [
      App(
        @list.from_array([
          Text("∎"),
          Text("Everytime you kissed me\n   I trembled like a child"),
          App(
            @list.from_array([
              Text("∎"),
              Text("Gathering the roses\n      We sang for the hope"),
            ]),
          ),
          Block(
            "Your very voice is in my heartbeat\nSweeter than my dream\nWe were there, in everlasting bloom\n",
          ),
          Block(
            "Roses die\nThe secret is inside the pain\nWinds are high up on the hill\nI cannot hear you\n",
          ),
        ]),
      ),
      App(@list.from_array([Text("-"), Text("Come and hold me close")])),
      App(
        @list.from_array([
          Text("-"),
          Text("I'm shivering cold in the heart of rain"),
        ]),
      ),
      App(
        @list.from_array([
          Text("-"),
          Text("Darkness falls, I'm calling for the dawn"),
          App(@list.from_array([Text("Ω")])),
        ]),
      ),
    ],
  )
}

///|
test "Reconstructing stage 1 per component" {
  let source =
    #|(p When the wind, the fire, and all is gone
    #|   Caress me with your sweet lullaby...)
  assert_eq(source |> Stage1::parse |> to_source, source)
  let source =
    #|(p 魅惑の扉 将来の展望だって
    #|   揺らぎそうになる 青春時代で
    #|   人生が変わる? 恋したいのに 臆病になる
    #|   問題 山積みなんだ
    #|
    #|   答えを導く為には \(this feeling\)
    #|   切り捨てられない \(all my love\)
    #|
    #|   ユメじゃないやいやいやいやい
    #|   手が届きそうな gloria
    #|   たまに見えなくなって
    #|   Cry やいやいやいやい
    #|   近道を探しても同じね
    #|   また迷ってしまうでしょ?)
  assert_eq(source |> Stage1::parse |> to_source, source)
}

///|
test "Reconstructing stage 1" {
  let source =
    #|(Rise 空には太陽が)
    #|
    #|(Force あなたには強さが 似合う (Days 涙は夢をみて) (Stage 未来を描いては 掴む))
    #|```
    #|世界中 風さえ在るのなら
    #|// どこまでも ぼくらは飛ベると誓い合う
    #|(絆が見えた)
    #|```
    #|
    #|(_ ダイアモンドから 夢を放つ ペルセウス)
    #|
    #|(まだ見ぬチカラを その瞳 \(め\) に秘めて)
    #|```
    #|光の翼が 虹をかけてゆく Field of dreams
    #|```
    #|
    #|(輝く あなたを信じてる)
  let nodes = Stage1::parse(source)
  let reconstructed = to_source(nodes)
  assert_eq(reconstructed, source)
}
