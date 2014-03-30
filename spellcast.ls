const
  WIDTH = 500
  HEIGHT = 500
  TRANSMISSION_RANGE    = 50
  INTERFERENCE_RANGE    = 70
  CARRIER_SENSING_RANGE = 90

# field state

# random walk, deflecting from boundary
nodes = let
  cx = 0.5 * WIDTH
  cy = 0.5 * HEIGHT

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
        break gen if nodes.length > 50

    gen = nexgen if nexgen.length > 0
    if Math.random! < restarts
      restarts *= 0.5
      gen.push nodes.0

  nodes

graph = unit-disk-graph TRANSMISSION_RANGE, nodes
source = nodes.0

# remove disconnected from source
[btree, seen, links, max-depth] = bfs source, -> graph[it.id] ? []

# algorithm state (for step-through)
steps = []
step-idx = 0

levels = []
q = [btree]
while q.length > 0
  q = [].concat.apply [], q.map (.children)
  levels.push ((levels[*-1]) or []) ++ q

levels.reverse!

hull = d3.geom.hull!
  .x (.node.x) .y (.node.y)

# max independent set, in order of bfs
set = {}
q = [btree]
while q.length > 0
  children = []
  for n in q
    # unless already covered, add to independent set
    unless graph[n.node.id].some (-> set[it.id]?)
      set[n.node.id] = n.node
    children.push ...n.children

  q = children

# bind stuff
d3.select \#field
  ..select \#ranges .select-all \.range .data nodes
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
    ..attr \transform ({x, y}) -> "translate(#x, #y)"
  ..select \#levels .select-all \.level .data levels
    ..exit!remove!
    ..enter!append \path
      ..attr \class \level
      ..attr \d -> "M #{hull it .map (({{x, y}: node}) -> "#x #y") .join \L} Z"
  ..select \#handles .select-all \.handle .data nodes
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

