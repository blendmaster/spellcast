const
  WIDTH = 500
  HEIGHT = 500
  TRANSMISSION_RANGE    = 50
  INTERFERENCE_RANGE    = 100
  CARRIER_SENSING_RANGE = 120

# field state
nodes = for i til 100
  new BNode do
    Math.random! * WIDTH
    Math.random! * HEIGHT

graph = unit-disk-graph TRANSMISSION_RANGE, nodes
# remove disconnected
for n, nei of graph
  if nei.length is 0
    nodes = nodes.filter (.id is not n)
    delete graph[n]

# TODO select largest connected component
source = nodes.0

# remove disconnected from source
[btree, seen, links, max-depth] = bfs source, -> graph[it.id] ? []
nodes = nodes.filter -> seen[it.id]
for n, nei of graph
  if not seen[n]
    delete graph[n]
  else
    graph[n] = nei.filter -> seen[it.id]

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

