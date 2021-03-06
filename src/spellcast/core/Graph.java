package spellcast.core;

import java.util.*;

public class Graph {

public final int n;
public final BitSet[] transmission, interference, sensing;

public final int depth; // max depth
public final int[] bfsDepth; // id -> depth of node

public final BitSet[] bfsChildren; // int -> [child bitset]
public final int[] bfsChildCount; // int -> number of child nodes
public final int[] bfsDecendents; // int -> number of nodes "under" it
public final int[] bfsParent; // int -> parent id, (root goes to root)

// for visualization
public final List<P> ps;

public Graph(double tRange, double iRange, double sRange, List<P> ps) {
  assert tRange > 0 && tRange <= iRange && iRange <= sRange;
  assert !ps.isEmpty();

  this.ps = ps;

  //System.out.println(ps);

  n = ps.size();
  transmission = new BitSet[n];
  interference = new BitSet[n];
  sensing = new BitSet[n];
  bfsChildren = new BitSet[n];
  for (int i = 0; i < n; ++i) {
    bfsChildren[i] = new BitSet(n);
    transmission[i] = new BitSet(n);
    interference[i] = new BitSet(n);
    sensing[i] = new BitSet(n);
  }

  //System.out.println("range " + tRange + ", " + iRange + ", " + sRange);
  for (int i = 0; i < n; ++i) {
    for (int j = i + 1; j < n; ++j) {
      double dist = ps.get(i).dist(ps.get(j));
      //System.out.println("dist " + i + ", " + j + " : " + dist);
      if (dist <= sRange) {
        //System.out.println("s nei");
        sensing[i].set(j);
        sensing[j].set(i);

        if (dist <= iRange) {
          //System.out.println("i nei");
          interference[i].set(j);
          interference[j].set(i);

          if (dist <= tRange) {
            //System.out.println("t nei");
            transmission[i].set(j);
            transmission[j].set(i);
          }
        }
      }
    }
  }

  bfsDepth = new int[n];
  bfsParent = new int[n];
  bfsChildCount = new int[n];
  bfsDecendents = new int[n];

  Queue<Integer> q = new LinkedList<>();
  BitSet seen = new BitSet(n);

  q.add(0);
  seen.set(0);
  bfsDepth[0] = 0;
  while (!q.isEmpty()) {
    // System.out.println("q" + q);
    int t = q.remove();

    BitSet nei = transmission[t];
    for (int i = nei.nextSetBit(0); i >= 0; i = nei.nextSetBit(i+1)) {
      if (!seen.get(i)) {
        bfsDepth[i] = bfsDepth[t] + 1;
        seen.set(i);
        q.add(i);
        bfsChildren[t].set(i);
        bfsChildCount[t]++;
        bfsParent[i] = t;
      }
    }
  }

  assert seen.cardinality() == n;

  int d = 0;
  for (int t = 0; t < n; ++t) {
    if (bfsDepth[t] > d) { d = bfsDepth[t]; }
    // collect all decendents.
    BitSet decendents = new BitSet(n);
    q.clear();

    BitSet children = bfsChildren[t];
    for (int i = children.nextSetBit(0); i >= 0; i = children.nextSetBit(i+1)) {
      decendents.set(i);
      q.add(i);
    }

    while (!q.isEmpty()) {
      int s = q.remove();
      BitSet ch = bfsChildren[s];
      for (int j = ch.nextSetBit(0); j >= 0; j = ch.nextSetBit(j+1)) {
        decendents.set(j);
        q.add(j);
      }
    }

    bfsDecendents[t] = decendents.cardinality();
  }

  depth = d;

  // for (int i = 0; i < n; ++i) {
  //   System.out.println("node " + i);
  //   System.out.println("bfs children " + bfsChildren[i]);
  //   System.out.println("bfs depth " + bfsDepth[i]);
  //   System.out.println("transmission " + transmission[i]);
  //   System.out.println("interference " + interference[i]);
  //   System.out.println("sensing      " + sensing[i]);
  // }
}

public static class P {
  public final double x, y;
  public P(double x, double y) {
    this.x = x;
    this.y = y;
  }

  public String toString() {
    return "[" + x + "," + y + "]";

  }

  public double dist(P p) {
    return Math.sqrt((p.x - x) * (p.x - x) + (p.y - y) * (p.y - y));
  }
}

}
