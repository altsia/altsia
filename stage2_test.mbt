///|
test "Parsing stage 2 per component" {
  assert_eq(
    "(修我一颗凡心 (% 敛我半世癫狂之梦)) "
    |> Stage1::parse
    |> Stage2::pass,
    [App("修我一颗凡心", [Comment("敛我半世癫狂之梦")])],
  )
  assert_eq(
    "(痴情的人) (心跳如春雨也纷纷)" |> Stage1::parse |> Stage2::pass,
    [App("痴情的人", []), App("心跳如春雨也纷纷", [])],
  )
  assert_eq(
    "(_ Epitaph (% The child was born underground.) (... and the name of the goddess of a rainbow...iris.))"
    |> Stage1::parse
    |> Stage2::pass,
    [
      Splice([
        Text("Epitaph"),
        Comment("The child was born underground."),
        App("...", [Text("and the name of the goddess of a rainbow...iris.")]),
      ]),
    ],
  )
}

///|
test "Parsing stage 2" {
  assert_eq(
    (
      #|(p All of the answers you seek lie hidden in the sun (% 答えの潜む琥珀の太阳)
      #|   If I hadn't met you, (% 出会わなければ)
      #|   my life would've been in the darkness forever (% 不死なる瞬き持つ魂伤つかないで)
      #|   In my wings are the powers of immortality (% 仆の羽根)
      #|   But by meeting you my whole life has changed (% この持ち知るため生まれてきた)
      #|   You give light to me hope to me strength into my life
      #|)
    )
    |> Stage1::parse
    |> Stage2::pass,
    [
      App("p", [
        Text("All of the answers you seek lie hidden in the sun"),
        Comment("答えの潜む琥珀の太阳"),
        Text("If I hadn't met you,"),
        Comment("出会わなければ"),
        Text("my life would've been in the darkness forever"),
        Comment("不死なる瞬き持つ魂伤つかないで"),
        Text("In my wings are the powers of immortality"),
        Comment("仆の羽根"),
        Text("But by meeting you my whole life has changed"),
        Comment("この持ち知るため生まれてきた"),
        Text("You give light to me hope to me strength into my life"),
      ]),
    ],
  )
}
