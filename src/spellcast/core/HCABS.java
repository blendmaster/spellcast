package spellcast.core;

import java.util.*;

public class HCABS {

public static int run(
  int n,
  Graph g,
  Selector selector
) {
  BitSet informed = new BitSet(n); informed.set(0);
  BitSet active   = new BitSet(n); active  .set(0);
  int time        = 0;

  BitSet able = new BitSet(n);
  BitSet noninf_n = new BitSet(n);
  BitSet noninf_v = new BitSet(n);

  while (informed.cardinality() < n) {
    able.clear(); able.or(active);

    while (able.cardinality() > 0) {
      int u = selector.select(informed, active, able, g, time);

      able  .clear(u);
      active.clear(u);

      BitSet n_u = g.transmission[u];
      noninf_n.clear(); noninf_n.or(n_u); noninf_n.andNot(informed);

      if (noninf_v.cardinality() > 0) {
        BitSet n_i = g.interference[u];

        // remove conflicts

        // ables whose neighbors would get interference from u
        for (int v = able.nextSetBit(0); v >= 0; v = able.nextSetBit(v+1)) {
          BitSet ws = g.interference[v];
          noninf_v.clear(); noninf_v.or(ws); noninf_n.andNot(informed);
          if (noninf_v.intersects(n_i)) {
            able.clear(v);
          }
        }

        // ables whose transmission would interfere with u's neighbors
        for (int w = able.nextSetBit(0); w >= 0; w = able.nextSetBit(w+1)) {
          if (g.interference[w].intersects(noninf_n)) {
            able.clear(w);
          }
        }

        // ables that would detect u's carrier
        able.andNot(g.sensing[u]);

        // mark neighbors as informed and active
        informed.or(noninf_n);
        active.or(noninf_n);
      }
    }
    time++;
  }

  return time;
}

}
