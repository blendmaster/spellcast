const
  WIDTH = document.document-element.client-width - 50
  HEIGHT = 400
  TRANSMISSION_RANGE    = 50
  INTERFERENCE_RANGE    = 70
  CARRIER_SENSING_RANGE = 90
  alpha = INTERFERENCE_RANGE / TRANSMISSION_RANGE
  beta = CARRIER_SENSING_RANGE / TRANSMISSION_RANGE

# field state

cx = 0.5 * WIDTH; cy = 0.5 * HEIGHT
# random walk, deflecting from boundary
rand-nodes = (num) ->
  nodes = [new BNode cx, cy]
  gen = [nodes.0]

  restarts = 0.1

  :gen loop
    nexgen = []
    for {x, y}: node in gen
      ct = Math.atan2 y - cy, x - cx

      for i til Math.floor Math.random! * 2 # fanout
        t = Math.random! * 2 * Math.PI
        if not init and Math.abs(t - ct) < Math.PI
          t += Math.PI
        init = true
        # bias towards outer edge of transmission range
        r = Math.random! ^ 0.25 * TRANSMISSION_RANGE
        dx = r * Math.cos t ; nx = x + dx
        dy = r * Math.sin t ; ny = y + dy

        n = new BNode do
          if nx < 0 or nx > WIDTH then x - dx else nx
          if ny < 0 or ny > HEIGHT then y - dy else ny

        nexgen.push n
        nodes.push n
        break gen if nodes.length > num

    gen = nexgen if nexgen.length > 0
    if Math.random! < restarts
      restarts *= 0.5
      gen.push nodes.0

  nodes

init-nodes =
  * new BNode cx, cy
  * new BNode cx + TRANSMISSION_RANGE - 1, cy
  * new BNode cx + TRANSMISSION_RANGE - 1, cy + TRANSMISSION_RANGE - 1
  * new BNode cx + TRANSMISSION_RANGE - 1, cy + 2 * TRANSMISSION_RANGE - 2
  * new BNode cx + TRANSMISSION_RANGE - 1, cy + 3 * TRANSMISSION_RANGE - 3
  * new BNode cx + 2 * TRANSMISSION_RANGE - 2, cy
  * new BNode cx + 3 * TRANSMISSION_RANGE - 3, cy
  * new BNode cx + 4 * TRANSMISSION_RANGE - 4, cy

nodes = rand-nodes 100

recalc-everything = !->
  d3.select-all \.status .remove!
  d3.select-all \.pulse .transition!remove!
  unclassify \hover
  recalc-graph!
  calc-more-state!
  calc-schedule!
  draw-schedule!
  draw-trace!
  draw!

document.get-element-by-id \rand .add-event-listener \click !->
  num = document.get-element-by-id \num-rand
  num = parseInt num.value, 10
  nodes := rand-nodes num
  recalc-everything!

document.get-element-by-id \cabs .add-event-listener \click recalc-everything
document.get-element-by-id \hcabs .add-event-listener \click recalc-everything

var graph, udg-links, gct, gcr, source

recalc-graph = !->
  graph := unit-disk-graph TRANSMISSION_RANGE, nodes
  udg-links := graph-links graph, nodes
  gct := unit-disk-graph Math.max(alpha + 1, beta) * TRANSMISSION_RANGE, nodes
  gcr := unit-disk-graph (2 + Math.max(alpha, beta)) * TRANSMISSION_RANGE, nodes
  source := nodes.0

recalc-graph!

hull = d3.geom.hull!
  .x (.node.x) .y (.node.y)

var btree, seen, links, max-depth, steps, step-idx, levels, set

var actual-levels, trace, schedule, timing, recv-schedule, hcabs-schedule

calc-more-state = !->
  [btree, seen, links, max-depth] := bfs source, -> graph[it.id]

  # algorithm state (for step-through)
  steps := []
  step-idx := 0

  levels := []
  actual-levels := []
  q = [btree]
  while q.length > 0
    actual-levels.push q
    q = [].concat.apply [], q.map (.children)
    levels.push ((levels[*-1]) or []) ++ q

  levels.reverse!
  # max independent set, in order of bfs
  set := {}
  q = [btree]
  while q.length > 0
    children = []
    for n in q
      # unless already covered, add to independent set
      unless graph[n.node.id].some (-> set[it.id]?)
        set[n.node.id] = n.node
      children.push ...n.children

    q = children

do-cabs = !->
  {trace, schedule} := cabs graph, gcr, gct, btree, set

do-hcabs = !->
  [trace, schedule] :=
    hcabs graph, TRANSMISSION_RANGE, alpha, beta, source, nodes

calc-schedule = !->
  if document.get-element-by-id \cabs .checked
    do-cabs!
  else
    do-hcabs!
  [timing, recv-schedule] := timing-of nodes, graph, schedule

function timing-of nodes, graph, schedule
  timing = {[node.id, {send: [], recv: void}] for node in nodes}
  timing[source.id]recv = 0
  recv-schedule = []
  for slice, i in schedule
    recv = []
    for transmit in slice
      timing[transmit.id]send.push i
      for nei in graph[transmit.id]
        timing[nei.id]recv =
          if timing[nei.id]recv?
            that <? i
          else
            i
        if timing[nei.id]recv is i
          recv.push nei.id
    recv-schedule.push recv

  return [timing, recv-schedule]

calc-more-state!
calc-schedule!

draw-schedule = !->
  d3.select \#schedule .select-all \td .data d3.range(0, schedule.length)
    ..exit!remove!
    ..enter!append \td .text -> it
    ..on \mouseover !->
      for n in schedule[it]
        d3.select-all ".n#{n.id}"
          ..classed \hover true
          ..classed \sending true
      for n in recv-schedule[it]
        d3.select-all ".n#{n}" .classed \receiving true
      for i til it
        for n in recv-schedule[i]
          d3.select-all ".n#{n}" .classed \received true

    ..on \mouseout !->
      for n in schedule[it]
        d3.select-all ".n#{n.id}"
          ..classed \hover false
          ..classed \sending false
      d3.select-all \.receiving .classed \receiving false
      d3.select-all \.received .classed \received false

draw-schedule!

classify = (id, c) !->
  d3.select-all ".n#{id}" .classed c, true
unclassify = (c) !->
  d3.select-all ".#c" .classed c, false

colors = d3.scale.category20!

draw-trace = !->
  # XXX yes I feel bad about this code, sorry
  d3.select \#trace .select-all \tr .data trace, (.name)
    ..exit!remove!
    ..enter!append \tr
      ..append \th .text (.name)
    ..select-all \td .data (-> it)
      ..exit!remove!
      ..on \mouseout (, i) !->
          unclassify \highlight
      ..enter!append \td
        ..text (it, i, j) ->
          if document.get-element-by-id \cabs .checked
            if j is 0 then it else \●
          else
              \●
        ..on \mouseover (it, i, j) !->
          if document.get-element-by-id \cabs .checked
            # unhighlight rest
            d3.select \#handles .classed \unhighlight true
            # highlight level
            unless j is 3 or j is 4
              for {node} in actual-levels[i]
                classify node.id, \highlight

            switch j
            case 2 # cover
              # highlight cover
              for node in trace[2][i]
                classify node.id, \cover

              # show gcr circles
              d3.select-all \.range .data it, (.id)
                ..select \.transmission .classed \show true
            case 3, 4 # cover -> set color
              sub = trace.3[i]
              d3.select \#udg-links .classed \hide true
              d3.select \#links .classed \hide true

              d3.select \#gcr-links .select-all \.gcr-link .data sub.links
                ..exit!remove!
                ..enter!append \line
                  ..attr \class \gcr-link
                  ..attr do
                    x1: (.source.x)
                    x2: (.target.x)
                    y1: (.source.y)
                    y2: (.target.y)

              col = sub.col
              d3.select-all \.handle .data sub.p, (.id)
                ..classed \highlight true
                ..style \stroke -> colors col[it.id]

              # show gcr circles
              d3.select-all \.range .data sub.p, (.id)
                ..select \.gcr .classed \show true

              if j is 4 # show schedule
                sched = it
                d3.select-all \.handle .data trace[2][i], (.id)
                  ..classed \scheduled true
                  ..style \stroke ->
                    s = 0
                    for slot, i in sched
                      for n in slot
                        if n is it
                          s = i
                    colors s
                # show transmission circles
                d3.select-all \.range .data trace[2][i], (.id)
                  ..select \.transmission .classed \show true

            case 5, 6, 7
              uninformed = trace[5][i]
              unclassify \highlight
              unclassify \cover

              sub = trace.6[i]
              d3.select-all \.handle .data sub.p, (.id)
                ..classed \highlight true

              d3.select-all \.handle .data uninformed, (.id)
                ..classed \uninformed true

              if j is 6 or j is 7 # show color
                d3.select \#udg-links .classed \hide true
                d3.select \#links .classed \hide true
                d3.select \#gct-links .select-all \.gct-link .data sub.links
                  ..exit!remove!
                  ..enter!append \line
                    ..attr \class \gct-link
                    ..attr do
                      x1: (.source.x)
                      x2: (.target.x)
                      y1: (.source.y)
                      y2: (.target.y)
                col = sub.col
                d3.select-all \.handle .data sub.p, (.id)
                  ..style \stroke -> colors col[it.id]
                sched = it

                # show gcr circles
                d3.select-all \.range .data sub.p, (.id)
                  ..select \.gct .classed \show true

              if j is 7 # show schedule
                d3.select-all \.handle .data uninformed, (.id)
                  ..classed \scheduled true
                  ..style \stroke ->
                    s = 0
                    for slot, i in sched
                      for n in slot
                        for nei in graph[n.id]
                          if nei is it
                            s = i
                            break
                    colors s
                # show transmission circles
                d3.select-all \.range .data sub.p, (.id)
                  ..select \.transmission .classed \show true
          else
            d3.select \#handles .classed \unhighlight true
            # Active
            for node in trace[0][i]
              classify node.id, \h-highlight
            switch j
            case 1 # Order
              for {u} in it
                classify u.id, \order
            case 2 # Schedule
              for {u} in trace[1][i]
                classify u.id, \order
              d3.select-all \.range .data it, (.id)
                ..classed \hover true

        ..on \mouseout (, i) !->
          unclassify \highlight
          unclassify \h-highlight
          unclassify \cover
          unclassify \hover
          unclassify \order
          unclassify \hide
          unclassify \show
          unclassify \scheduled
          unclassify \uninformed
          d3.select \#handles .classed \unhighlight false
          d3.select \#gcr-links .select-all \.gcr-link .remove!
          d3.select \#gct-links .select-all \.gct-link .remove!
          d3.select-all \.handle
            ..style \stroke void
draw-trace!

DURATION = 1000ms

document.get-element-by-id \anim .add-event-listener \click !->
  d3.select \#pulses .select-all \.pulses .data nodes, (.id)
    ..exit!remove!
    ..enter!append \g
      ..attr \class \pulses
      ..attr \transform ({x, y}) -> "translate(#x, #y)"
    ..select-all \.pulse .data ((d) -> timing[d.id]send.map -> [it, d.id])
      ..exit!remove!
      ..enter!append \circle
        ..attr \class \pulse
      ..attr \r 0
      ..attr \opacity 1
      ..transition!duration DURATION .ease \linear
        ..delay -> DURATION * it.0
        ..attr \r CARRIER_SENSING_RANGE
        ..attr \opacity 0
        ..remove!
        ..each \start !->
          d3.select-all ".n#{it.1}" .classed \hover true
        ..each \end !->
          d3.select-all ".n#{it.1}" .classed \hover false

  d3.select \#stati .select-all \.status .data nodes, (.id)
    ..exit!remove!
    ..enter!append \circle
    ..attr \r 0
    ..attr \class \status
    ..attr \cx (.x)
    ..attr \cy (.y)
    ..transition!duration DURATION / 2 .ease \linear
      ..delay -> DURATION * (0 + timing[it.id]recv)
      ..attr \r 5
      ..attr \class "status received"

document.get-element-by-id \clear .add-event-listener \click !->
  d3.select-all \.status .remove!
  d3.select-all \.pulse .transition!remove!
  unclassify \hover

draw = !->
  # bind stuff
  d3.select \#field
    ..attr width: WIDTH, height: HEIGHT
    ..select \#ranges .select-all \.range .data nodes, (.id)
      ..exit!remove!
      ..enter!append \g
        ..attr \class -> "range n#{it.id}"
        ..append \circle
          ..attr \class \transmission
          ..attr \r TRANSMISSION_RANGE
        ..append \circle
          ..attr \class \interference
          ..attr \r INTERFERENCE_RANGE
        ..append \circle
          ..attr \class \sensing
          ..attr \r CARRIER_SENSING_RANGE
        ..append \circle
          ..attr \class \gct
          ..attr \r Math.max(alpha + 1, beta) * TRANSMISSION_RANGE
        ..append \circle
          ..attr \class \gcr
          ..attr \r (2 + Math.max(alpha, beta)) * TRANSMISSION_RANGE
      ..attr \transform ({x, y}) -> "translate(#x, #y)"
    ..select \#levels .select-all \.level .data levels
      ..exit!remove!
      ..enter!append \path
        ..attr \class \level
      ..attr \d -> "M #{hull it .map (({{x, y}: node}) -> "#x #y") .join \L} Z"
    ..select \#handles .select-all \.handle .data nodes, (.id)
      ..exit!remove!
      ..enter!append \circle
        ..attr \class -> "handle n#{it.id}"
        ..classed \independent -> set[it.id]?
        ..attr \r 3
        ..on \mouseover !->
          d3.select-all ".n#{it.id}" .classed \hover true
        ..on \mouseout !->
          d3.select-all ".n#{it.id}" .classed \hover false
      ..attr \cx (.x)
      ..attr \cy (.y)
    ..select \#udg-links .select-all \.udg-link .data udg-links
      ..exit!remove!
      ..enter!append \line
        ..attr \class \udg-link
      ..attr do
        x1: (.source.x)
        x2: (.target.x)
        y1: (.source.y)
        y2: (.target.y)
    ..select \#links .select-all \.link .data links
      ..exit!remove!
      ..enter!append \line
        ..attr \class \link
      ..attr do
        x1: (.source.x)
        x2: (.target.x)
        y1: (.source.y)
        y2: (.target.y)
        #..style \stroke-width -> 5 * (max-depth - it.depth) / max-depth

  document.query-selector ".handle.n#{source.id}"
    ..class-list.add \source

draw!

bind-visible = (checkbox, el) ->
  el = document.get-element-by-id el
  document.get-element-by-id checkbox
    ..add-event-listener \click !->
      if not @checked
        el.class-list.add \really-hide
      else
        el.class-list.remove \really-hide
    if ..checked
      el.class-list.remove \really-hide
    else
      el.class-list.add \really-hide

bind-visible \udg \udg-links
bind-visible \bfs \links
bind-visible \hull \levels


