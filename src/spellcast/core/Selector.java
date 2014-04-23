package spellcast.core;

import java.util.*;

public interface Selector {

public int select(
  BitSet informed, BitSet active, BitSet able,
  Graph g,
  int time
);

public static final Selector NUM_UNINFORMED = new Selector() {

  public int select(
    BitSet informed, BitSet active, BitSet able,
    Graph g,
    int time
  ) {
    // max by number of uninformed neighbors
    int max = -1, maxCount = -1;
    BitSet uninNei = new BitSet(g.n);
    for (int v = able.nextSetBit(0); v >= 0; v = able.nextSetBit(v+1)) {
      uninNei.clear(); uninNei.or(g.transmission[v]);
      uninNei.andNot(informed);

      int c = uninNei.cardinality();
      // System.out.println(">>>node " + v + " : " + uninNei + " , nei "
      //     + g.transmission[v]);
      if (c > maxCount) {
        maxCount = c;
        max = v;
      }
    }

    // System.out.println(">>>apparent max " + max);
    return max;
  }
};

}

