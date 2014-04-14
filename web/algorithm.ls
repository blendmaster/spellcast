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

dist = (a, b) ->
  Math.sqrt Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2)

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

tracer =
  * 'Level'
  * 'Independent Set'
  * 'Cover'
  * 'Cover → Set Color'
  * 'Cover → Set Schedule'
  * 'Uninformed'
  * 'Set → Uninformed Color'
  * 'Set → Uninformed Schedule'

cabs = (graph, gcr, gct, btree, set) ->
  informed = {}
  level = [btree]
  schedule = []
  trace = [[] <<< name: thing for thing in tracer]
  i = 0
  while level.length > 0
    trace.0.push i
    i++
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
    trace.1.push ui
    # turn uci from map to list
    uci = Object.keys uci .map (uci.)
    trace.2.push uci
    # uci now covers ui from upper (informed) levels
    {subs, subtrace} = subs1 = sub-cabs graph, ui, true, uci, gcr
    subs.=filter (.length > 0)
    trace.3.push subtrace
    trace.4.push subs
    schedule.push ...subs if subs.length > 0
    # all uninformed neighbors of ui
    wi = []
    for node in ui
      for n in graph[node.id]
        if not informed[n.id]
          wi.push n
    trace.5.push wi

    {subs, subtrace} = subs2 = sub-cabs graph, ui, false, wi, gct
    subs.=filter (.length > 0)
    trace.6.push subtrace
    trace.7.push subs
    schedule.push ...subs if subs.length > 0

    for node in wi ++ ui
      informed[node.id] = true
    level = [].concat.apply [], level.map (.children)

  {trace, schedule}

function filter-graph graph, vertices
  v = index vertices, (.id)
  filtered = {}
  for n, nei of graph
    if v[n]
      filtered[n] = nei.filter -> v[it.id]?
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
    nei-col = {}
    for nn in nei
      if col[nn.id]?
        nei-col[that] = true
    i = 0
    while nei-col[i]
      i++
    col[n] = i
    max = max >? i

  return [col, max + 1]

function sub-cabs graph, p, is-receive, q, gc
  subtrace = {}
  qi = index q, (.id)
  fgraph = filter-graph gc, p
  subtrace.p = p
  subtrace.fgraph = fgraph
  subtrace.links = graph-links fgraph, p
  [col, colors] = coloring fgraph
  subtrace.col = col
  s = [{} for i til colors]
  return {subs: [], subtrace} if q.length is 0 and not is-receive
  for u in p
    if is-receive
      # add neighbor of u in q
      for n in graph[u.id]
        if qi[n.id]
          s[col[u.id]][n.id] = n
          break
    else
      s[col[u.id]][u.id] = u

  subs = s.map (set) -> Object.keys set .map (set.) # back to arrays
  return {subs, subtrace}

function to-set list
  s = {}
  for list
    s[..id] = ..
  s

function to-list set
  Object.keys(set)map (set.)

function set-minus a, b
  s = {}
  for k, v of a
    unless b[k]?
      s[k] = v
  s

function set-size
  s = 0
  for k of it
    s++
  s

function by-fn fn
  (a, b) ->
    fna = fn a
    fnb = fn b
    if fna > fnb
      1
    else if fna < fnb
      -1
    else
      0

h-tracer =
  * 'Active'
  * 'Order'
  * 'Schedule'

function hcabs graph, r, alpha, beta, s, nodes
  inf = {(s.id): s}
  inflen = 1
  active = {(s.id): s}
  time = 0
  schedule = []
  trace = [[] <<< name: thing for thing in h-tracer]
  while inflen < nodes.length
    q = []
    for k, n of active
      q.push n

    trace.0.push to-list active

    ss = {}

    #console.log 'outer' q, active

    t = []
    while q.length > 0
      u = q
        .sort by-fn ->
          set-size set-minus (to-set graph[it.id]), inf
        .shift!
      delete active[u.id]

      n-inf = set-minus (to-set graph[u.id]), inf
      #console.log 'neighbors' u, n-inf, {...inf}, (to-set graph[u.id])
      if set-size(n-inf) > 0
        t.push n-inf: to-list(n-inf), u: u
        #console.log 'culling q' q.length, q
        nu-q = []
        # remove all nodes whose transmissions would conflict with
        # u's transmission
        :adder for v in q
          v-inf = set-minus (to-set graph[v.id]), inf
          for k, w of v-inf
            unless dist(u, w) <= alpha * r
              nu-q.push v
              continue adder

        q = nu-q
        #console.log 'culling q' q.length, q
        nu-q = []
        in-q = {}
        for k, v of n-inf
          for w in q
            unless in-q[w.id] or dist(w, v) <= alpha * r
              in-q[w.id] = true
              nu-q.push w

        q = nu-q
        #console.log 'culling q' q.length, q
        nu-q = []
        for v in q
          unless dist(u, v) <= beta * r
            nu-q.push v
        q = nu-q
        #console.log 'culling q' q.length, q

        ss[u.id] = u

        #console.log 'n-/inf' n-inf
        for k, w of n-inf
          inf[w.id] = w
          inflen++
          active[w.id] = w
        #console.log 'active' active
        #console.log 'inf' inf
      #console.log 'nu-q len' q.length

    trace.1.push t
    trace.2.push to-list ss
    schedule[time] = Object.keys(ss)map (ss.)
    time++

  return [trace, schedule]
