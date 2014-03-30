# various algorithms whose existing implementations never seem to satify, and
# are easy enough to rewrite over and over again

# Model
# while not generally efficient to store actual coordinates of nodes, we're
# displaying them anyway so might as well.
# We use d3 quadtree for efficient unit disk graph generation.
gensym = 0
class BNode then (@x, @y) ->
  @id = gensym++

# wrapper for nodes, so we don't pollute the namespace when running
# multiple algorithms or
class GNode then (@node) ->
  @id = gensym++
  @children = []

bfs = (start, neighbors-of) ->
  root = new GNode start

  seen = {}
  links = []

  queue = [root]
  depth = 0
  while (tnode = queue.shift!)?
    links[tnode.node] = []
    for neighbor in neighbors-of tnode.node
      unless seen[neighbor.id]?
        tneighbor = new GNode neighbor
        queue.push tneighbor
        tnode.children.push tneighbor
        links.push do
          source: tnode.node
          target: neighbor
          depth: depth
        seen[neighbor.id] = true
    depth++

  return [root, seen, links, depth]

dist2 = (a, b) ->
  Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2)

coloring = ->
  # TODO
  # Smallest-last ordering and clustering and graph coloring algorithms.

unit-disk-graph = (unit, nodes) ->
  unit2 = unit * unit
  # construct quad-tree for detection TODO
  # root = d3.geom.quadtree!x (.x) .y (.y) <| nodes
  # root.visit (node, x1, y1, x2, y2) ->
  #   if ((y2 - y1) <? (x2 - x1)) <= unit
  #     stuff
  neighbors = {[n.id, []] for n in nodes}
  for n, i in nodes
    for j from i til nodes.length
      m = nodes[j]
      if dist2(n, m) < unit2
        neighbors[n.id]push m
        neighbors[m.id]push n

  return neighbors

