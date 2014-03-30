range =
  transmission: 100
  interference: 130
  sensing: 160

dist = (a, b) ->
  Math.sqrt Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2)

nodes =
  * t1 = c: \t₁ id: \t1 x: 100, y: 200
  * r1 = c: \r₁ id: \r1 x: 100, y: 300
  * t2 = c: \t₂ id: \t2 x: 400, y: 200
  * r2 = c: \r₂ id: \r2 x: 400, y: 300

t = [t1, t2]

links =
  * source: t1, target: r1
  * source: t2, target: r2

avoid-t = document.get-element-by-id \avoid-t
avoid-r = document.get-element-by-id \avoid-r
t-constraint = d3.select \#t-constraint
r-constraint = d3.select \#r-constraint
t-line = d3.select \#t-line
r-line = d3.select \#r-line
t-text = d3.select \#t-text
r-text = d3.select \#r-text

constrain = (dragged) !->
  # constrain transmitter to receiver
  if dist(t1, r1) > range.transmission
    if r1 is dragged
      i = r1; d = t1
    else
      i = t1; d = r1

    t = Math.atan2 d.y - i.y, d.x - i.x
    d <<<
      x: i.x + range.transmission * Math.cos t
      y: i.y + range.transmission * Math.sin t
  if dist(t2, r2) > range.transmission
    if r2 is dragged
      i = r2; d = t2
    else
      i = t2; d = r2

    t = Math.atan2 d.y - i.y, d.x - i.x
    d <<<
      x: i.x + range.transmission * Math.cos t
      y: i.y + range.transmission * Math.sin t

  if avoid-t.checked
    # apply sufficient conditions
    a = 1
  if avoid-r.checked
    # apply sufficient conditions
    a = 1
drag = d3.behavior.drag!
  .origin -> it
  .on \drag !->
    it <<< d3.event{x, y}
    constrain it
    draw!

detect-conflicts = !->
  r1.conflicted =
    dist(t2, r1) < range.interference
  r2.conflicted =
    dist(t1, r2) < range.interference

  t1.conflicted = t2.conflicted =
    dist(t1, t2) < range.sensing

draw = !->
  detect-conflicts!

  d3.select \#field
    ..select \#ranges .select-all \.range .data t
      ..enter!append \g
        ..attr \class -> "range #{it.id}"
        ..append \circle
          ..attr \class \transmission
          ..attr \r range.transmission
        ..append \circle
          ..attr \class \interference
          ..attr \r range.interference
        ..append \circle
          ..attr \class \sensing
          ..attr \r range.sensing
      ..attr \transform ({x, y}) -> "translate(#x, #y)"
    ..select \#pulses .select-all \.pulse .data t
      ..enter!append \circle
        ..attr do
          class: \pulse
          r: 50
        ..append \animate .attr do
          attributeName: \r
          from: 0
          to: range.sensing
          begin: 0s
          dur: 3s
          repeatCount: \indefinite
        ..append \animate .attr do
          attributeName: \opacity
          from: 1
          to: 0
          begin: 0s
          dur: 3s
          repeatCount: \indefinite
      ..classed \conflicted (.conflicted)
      ..attr do
        cx: (.x)
        cy: (.y)
    ..select \#links .select-all \.link .data links
      ..enter!append \line
        ..attr \class \link
      ..attr do
        x1: (.source.x)
        x2: (.target.x)
        y1: (.source.y)
        y2: (.target.y)
    ..select \#handles .select-all \.handle .data nodes
      ..enter!append \g
        ..attr \class -> "handle #{it.id}"
        ..append \circle
          ..attr do
            r: 5
        ..append \text
          ..attr x: 5 y: -5
          ..text (.c)
        ..call drag
      ..attr \transform ({x, y}) -> "translate(#x, #y)"
      ..classed \conflicted (.conflicted)

  tdist = dist t1, t2
  trot = (180 / Math.PI) * Math.atan2 t2.y - t1.y, t2.x - t1.x
  rdist = dist r1, r2
  rrot = (180 / Math.PI) * Math.atan2 r2.y - r1.y, r2.x - r1.x

  t-line.attr \x2 tdist
  r-line.attr \x2 rdist
  t-text.attr \x tdist / 2
  r-text.attr \x rdist / 2
  t-constraint.attr \transform,
    "translate(#{t1.x}, #{t1.y}) rotate(#trot)"
  r-constraint.attr \transform,
    "translate(#{r1.x}, #{r1.y}) rotate(#rrot)"

draw!

