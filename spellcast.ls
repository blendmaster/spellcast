const
  WIDTH = 500
  HEIGHT = 500
  TRANSMISSION_RANGE    = 50
  INTERFERENCE_RANGE    = 100
  CARRIER_SENSING_RANGE = 120

# field state

# random walk, deflecting from boundary
nodes = let
  x = Math.random! * WIDTH
  y = Math.random! * HEIGHT

  nodes = []
  for i til 100
    if Math.random! > 0.95 and nodes.length > 1
      # restart random walk from random node instead of last
      {x, y} = nodes[Math.floor Math.random! * nodes.length]

    t = Math.random! * 2 * Math.PI
    # bias towards outer edge of transmission range
    r = Math.random! ^ 0.25 * TRANSMISSION_RANGE
    dx = r * Math.cos t ; nx = x + dx
    dy = r * Math.sin t ; ny = y + dy
    nodes.push new BNode do
      x = if nx < 0 or nx > WIDTH then x - dx else nx
      y = if ny < 0 or ny > HEIGHT then y - dy else ny

  nodes

graph = unit-disk-graph TRANSMISSION_RANGE, nodes
source = nodes.0

# remove disconnected from source
[btree, seen, links, max-depth] = bfs source, -> graph[it.id] ? []

# algorithm state (for step-through)
steps = []
step-idx = 0

# bind stuff
d3.select \#field
  ..select-all \.node .data nodes
    ..exit!remove!
    ..enter!append \g
      ..attr \id (.id)
      ..attr \class \node
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
        ..attr \class \handle
        ..attr \r 3
    ..attr \transform ({x, y}) -> "translate(#x, #y)"
  ..select-all \.link .data links
    ..exit!remove!
    ..enter!append \line
      ..attr \class \link
      ..attr do
        x1: (.source.x)
        x2: (.target.x)
        y1: (.source.y)
        y2: (.target.y)
      ..style \stroke-width ->
        5 * (max-depth - it.depth) / max-depth
document.get-element-by-id source.id
  ..class-list.add \source
  ..query-selector \.handle .set-attribute \r 10

