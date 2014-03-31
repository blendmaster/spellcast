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

  seen = {(start.id): true}
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

unit-disk-graph = (unit, nodes) ->
  unit2 = unit * unit
  # construct quad-tree for detection TODO
  # root = d3.geom.quadtree!x (.x) .y (.y) <| nodes
  # root.visit (node, x1, y1, x2, y2) ->
  #   if ((y2 - y1) <? (x2 - x1)) <= unit
  #     stuff
  neighbors = {[n.id, []] for n in nodes}
  for n, i in nodes
    for j from i+1 til nodes.length
      m = nodes[j]
      if dist2(n, m) < unit2
        neighbors[n.id]push m
        neighbors[m.id]push n

  return neighbors

graph-links = (graph, nodes) ->
  seen = {}
  links = []
  for n, i in nodes
    for m in graph[n.id]
      unless seen["#{m.id}#{n.id}"]
        seen["#{m.id}#{n.id}"] = true
        links.push do
          source: n
          target: m
  links

index = (list, fn) ->
  i = {}
  for it in list
    i[fn it] = it
  i

intersect = (a, b) ->
  i = []
  for k of a
    if b[k]
      i.push k
  i

cabs = (graph, gcr, gct, btree, set) ->
  informed = {}
  level = [btree]
  schedule = []
  i = 0
  while level.length > 0
    #console.log "level" i
    #console.log \informed informed
    i++
    #console.log "nodes" level.map (.node)
    uci = {}
    ui = level.map (.node) .filter -> set[it.id]
    for node in ui
      inter = intersect uci, index graph[node.id], (.id)
      if inter.length is 0
        for n in graph[node.id] # neighbors
          if informed[n.id]
            # add at most one informed neighbor
            uci[n.id] = n
            break
    #console.log "ui" ui
    # turn uci from map to list
    uci = Object.keys uci .map (uci.)
    #console.log "uci" uci
    # uci now covers ui from upper (informed) levels
    subs = subs1 = sub-cabs graph, ui, true, uci, gcr
    #console.log 'subs uci to ui' subs
    subs.=filter (.length > 0)
    schedule.push ...subs if subs.length > 0
    # all uninformed neighbors of ui
    wi = []
    for node in ui
      for n in graph[node.id]
        if not informed[n.id]
          wi.push n

    #console.log 'wi' wi
    subs = subs2 = sub-cabs graph, ui, false, wi, gct
    #console.log 'subs ui to wi' subs
    subs.=filter (.length > 0)
    schedule.push ...subs if subs.length > 0

    for node in wi
      informed[node.id] = true
    for {node} in level
      # all nodes are now informed
      informed[node.id] = true
    level = [].concat.apply [], level.map (.children)
  schedule

function filter-graph graph, vertices
  v = index vertices, (.id)
  filtered = {}
  for n, nei of graph
    if v[n]
      filtered[n] = nei.filter -> v[it.id]?
  #console.log 'xxxxxxxfiltered' filtered
  filtered

function order-least-degree graph
  order = []
  for n, nei of graph
    order.push [n, nei]
  order
    .sort (a, b) -> a.1.length - b.1.length

function coloring graph
  max = 0
  col = {}
  for [n, nei] in order-least-degree graph
    #console.log 'xxxx' n, nei
    nei-col = {}
    for nn in nei
      #console.log 'xxxx nn' nn, col[nn.id]
      if col[nn.id]?
        nei-col[that] = true
    #console.log 'xxxx nei-col' nei-col
    i = 0
    while nei-col[i]
      i++
    col[n] = i
    #console.log 'xxxx post col' Object.keys(col)map -> it + col[it]
    max = max >? i

  return [col, max + 1]

function sub-cabs graph, p, is-receive, q, gc
  return [] if q.length is 0 and not is-receive
  #console.log '-------'
  qi = index q, (.id)
  #console.log '---qi'  qi
  [col, colors] = coloring filter-graph gc, p
  #console.log '---colors' col
  s = [{} for i til colors]
  for u in p
    #console.log '---' u.id
    if is-receive
      #console.log \---is-receive
      # add neighbor of u in q
      for n in graph[u.id]
        #console.log '---considering' n
        if qi[n.id]
          #console.log '---adding' n
          s[col[u.id]][n.id] = n
          break
    else
      s[col[u.id]][u.id] = u

  #console.log '--- final s' s

  return s.map (set) -> Object.keys set .map (set.) # back to arrays

