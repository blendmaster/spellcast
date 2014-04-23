(ns spellcast.core
  (:use [clojush.pushgp.pushgp]
        [clojush.pushstate]
        [clojush.util]
        [clojush.interpreter]
        [clojush.instructions.common]
        [clojush.instructions.return]
        [clojure.math.numeric-tower]
        [clojure.set])
  (:import [spellcast.core Graph Graph$P HCABS Selector]
           [java.util BitSet])
  (:gen-class))

;;;;;;;;;;;;
;; To make the integer stack less overloaded, define some similar
;; stacks for ids of specific nodes, which can then be operated
;; on at a higher level.

;; Redefine push-types to include our stacks
;; and then redefine the push state structure.
(in-ns 'clojush.globals)
(def push-types '(:exec :integer :float :code :boolean :auxiliary :tag :return
                        :node   ;; generic stack for nodes
                        :bitset ;; sets of nodes so programs
                                ;; can xor/and/and-not parts of the graph easily
                        ))

(in-ns 'clojush.pushstate)
(define-push-state-record-type)

;;;;;;;;;;;;
;; Return to the spellcast namespace
(in-ns 'spellcast.core)

(define-registered node_pop (popper :node))
(define-registered node_dup (duper :node))
(define-registered node_swap (swapper :node))
(define-registered node_rot (rotter :node))
(define-registered node_flush (flusher :node))
(define-registered node_eq (eqer :node))
(define-registered node_stackdepth (stackdepther :node))
(define-registered node_yank (yanker :node))
(define-registered node_yankdup (yankduper :node))
(define-registered node_shove (shover :node))
(define-registered return_fromnode (returner :node))

(define-registered bitset_pop (popper :bitset))
(define-registered bitset_dup (duper :bitset))
(define-registered bitset_swap (swapper :bitset))
(define-registered bitset_rot (rotter :bitset))
(define-registered bitset_flush (flusher :bitset))
(define-registered bitset_eq (eqer :bitset))
(define-registered bitset_stackdepth (stackdepther :bitset))
(define-registered bitset_yank (yanker :bitset))
(define-registered bitset_yankdup (yankduper :bitset))
(define-registered bitset_shove (shover :bitset))

(defn push-items
  "multi push-item, basically. `values` is reversed to keep
   the top at the head of the seq."
  [values stack state]
  (assoc state stack (concat (reverse values) (stack state))))

(defn binary-reducer-by-int
  "Reduces the integer and node stack in parallel by the values
   in the integer stack, which presumably correspond to the two
   top nodes, e.g. their uninformed neighbor count.

   This allows the program to implement the original paper's heuristic
   by pushing the able nodes and reducing by max uninformed neighbor count."
  [reducer]
  (fn [state]
    (if-not (or
              (empty? (rest (:node    state)))
              (empty? (rest (:integer state))))
      (let [fst (stack-ref :integer 0 state)
            snd (stack-ref :integer 1 state)
            result (reducer fst snd)

            fst-node (stack-ref :node 0 state)
            snd-node (stack-ref :node 1 state)

            result-node (if (= result fst)
                          fst-node
                          snd-node)]
        (->> state
             (pop-item :integer)
             (pop-item :integer)
             (push-item result :integer)
             (pop-item :node)
             (pop-item :node)
             (push-item result-node :node)))
      state)))

(define-registered reduce-max (binary-reducer-by-int max))
(define-registered reduce-min (binary-reducer-by-int min))

(defn unary-op
  "An operation that pops a value from an input stack and pushes the result
   of `op` applied to the value onto the output stack."
  [input output op]
  (fn [state]
    (if-not (empty? (input state))
      (let [in (stack-ref input 0 state)]
        (->> state
             (pop-item input)
             (push-item (op state in) output)))
      state)))

(defn unary-multi-op
  "push-items version of `unary-op`, in case push-items's concat
   laziness is an issue."
  [input output op]
  (fn [state]
    (if-not (empty? (input state))
      (let [in (stack-ref input 0 state)]
        (->> state
             (pop-item input)
             (push-items (op state in) output)))
      state)))

(defn fn-with-aux
  "A state-operating function that needs access to greedy alg state,
   e.g. the graph itself.

  aux indices:

  0. the Graph
  1. BitSet of informed nodes
  2. BitSet of active nodes
  3. BitSet of nodes able to transmit
  4. Current time slice in algorithm
  "
  [aux-index fun]
  (fn [state & args]
    (apply fun
           (stack-ref :auxiliary aux-index state)
           args)))

(define-registered get-time
  (fn [state] (push-item (stack-ref :auxiliary 4 state) :integer state)))

(define-registered get-depth
  (fn [state] (push-item (.depth (stack-ref :auxiliary 0 state)) :integer state)))

(define-registered nodes-of
  ;;"Pushes all nodes from the top set of the bitset stack into the node stack."
  (unary-multi-op :bitset :node (fn [state bitset] (HCABS/ones bitset))))

(define-registered neighbors-of
  ;;"Pushes transmission neighbor set of the top node."
  (unary-op :node :bitset
            (fn-with-aux 0 (fn [graph node] (aget (.transmission graph) node)))))

(define-registered interferers-of
  ;;"Pushes interference neighbors set of the top node."
  (unary-op :node :bitset
            (fn-with-aux 0 (fn [graph node] (aget (.interference graph) node)))))

(define-registered sensors-of
  ;;"Pushes sensing neighbors set of the top node."
  (unary-op :node :bitset
            (fn-with-aux 0 (fn [graph node] (aget (.sensing graph) node)))))

(define-registered bfs-children
  ;;"Pushes BFS children set of the top node."
  (unary-op :node :bitset
            (fn-with-aux 0 (fn [graph node] (aget (.bfsChildren graph) node)))))

;; bitset operations
(define-registered set-cardinality
  (unary-op :bitset :integer (fn [state bitset] (.cardinality bitset))))

(define-registered is-empty
  (unary-op :bitset :boolean (fn [state bitset] (.isEmpty bitset))))

(define-registered new-set
  (fn [state]
    (let [graph (stack-ref :auxiliary 0 state)]
      (push-item (BitSet. (.n graph)) :bitset state))))

(define-registered get-informed
  (fn [state] (push-item (stack-ref :auxiliary 1 state) :bitset state)))

(define-registered get-active
  (fn [state] (push-item (stack-ref :auxiliary 2 state) :bitset state)))

(define-registered get-able
  (fn [state] (push-item (stack-ref :auxiliary 3 state) :bitset state)))

(defn binary-set-op
  "Applies the set operation to the top two bitsets, taking
   care not to mutate existing sets."
  [op]
  (fn [state]
    (if-not (empty? (rest (:bitset state)))
      (let [fst (stack-ref :bitset 0 state)
            snd (stack-ref :bitset 1 state)
            temp (.clone fst)
            _ (op temp snd)]
        (->> state
             (pop-item :bitset)
             (pop-item :bitset)
             (push-item temp :bitset)))
      state)))

(define-registered set-and (binary-set-op #(.and %1 %2)))
(define-registered set-or (binary-set-op #(.or %1 %2)))
(define-registered set-xor (binary-set-op #(.xor %1 %2)))

(define-registered set-intersects
  (fn [state]
    (if-not (empty? (rest (:bitset state)))
      (let [fst (stack-ref :bitset 0 state)
            snd (stack-ref :bitset 1 state)]
        (->> state
             (pop-item :bitset)
             (pop-item :bitset)
             (push-item (.intersects fst snd) :boolean)))
      state)))

(defn mutate-set-op
  "Applies the operation to the top bitset, e.g. flip/set, using
   the top of the node stack as input."
  [op]
  (fn [state]
    (if-not (or
              (empty? (:node state))
              (empty? (:bitset state)))
      (let [node (stack-ref :node 0 state)
            bitset (.clone (stack-ref :bitset 0 state))
            _ (op bitset node)]
        (->> state
             (pop-item :bitset)
             (pop-item :node)
             (push-item bitset :bitset)))
      state)))

(define-registered set-get (mutate-set-op #(.get %1 %2)))
(define-registered set-flip (mutate-set-op #(.flip %1 %2)))
(define-registered set-set (mutate-set-op #(.set %1 %2)))
(define-registered set-clear (mutate-set-op #(.clear %1 %2)))

;; best working heuristic from paper can then be implemented
;; with (cardinality (bitset-and neighbors informed))),
;; followed by the reduction-by-int operations.

(define-registered in-set
  (fn [state]
    (if-not (or
              (empty? (:node state))
              (empty? (:bitset state)))
      (let [node (stack-ref :node 0 state)
            bitset (stack-ref :bitset 0 state)]
        (->> state
             (pop-item :bitset)
             (pop-item :node)
             (push-item (.get bitset node) :boolean)))
      state)))

(define-registered bfs-depth
  (unary-op :node :integer
            (fn-with-aux 0 (fn [graph node]
                             (aget (.bfsDepth graph) node)))))

(define-registered bfs-decendents
  (unary-op :node :integer
            (fn-with-aux 0 (fn [graph node]
                             (aget (.bfsDecendents graph) node)))))

(define-registered bfs-child-count
  (unary-op :node :integer
            (fn-with-aux 0 (fn [graph node]
                             (aget (.bfsChildCount graph) node)))))

(define-registered bfs-parent
  (unary-op :node :node
            (fn-with-aux 0 (fn [graph node] (aget (.bfsParent graph) node)))))

(defn push-based-selector
  "wrap push-based program in interface
  for the greedy scheduler"
  [program]
  (reify spellcast.core.Selector
    (select [_ informed active able graph time]
      (let [stack (->> (make-push-state)
                       (push-item time :auxiliary)
                       (push-item able :auxiliary)
                       (push-item active :auxiliary)
                       (push-item informed :auxiliary)
                       (push-item graph :auxiliary)
                       )
            state (run-push program stack)
            top-return (top-item :return state)
            top-node (top-item :node state)
            selection (cond
                        ;; if program specifically returns a node
                        (number? top-return) top-return
                        ;; else use top of the node stack
                        (number? top-node) top-node
                        ;; else use first able node, which should
                        ;; punish programs that don't make a selection
                        :else (.nextSetBit able 0))]
        ;; if a valid selection
        (if (.get able selection)
          selection
          ;; else pick first node again
          (.nextSetBit able 0))))))

(defn mk-graph
  "[[x y]] -> Graph
  assumes points are connected"
  [points]
  (Graph. 1.0 1.1 1.2 ;; "standard" t-range, i-range, s-range
          (vec (map (fn [[x y]] (Graph$P. x y)) points))))

(def test-graphs
  [(mk-graph
    ;          4
    ;          3
    ;  x - 1 - 2 - 5 - 6
    ;
    ;  optimal: 0 1 2 3 5
    [[0 0] [0 1] [0 2] [1 2] [2 2] [0 3] [0 4]])])

(defn error-function
  "evalulate program inside greedy algorithm, compared to lower bound (bfs-depth).
  For most graphs, bfs-depth is too low, so programs can't be perfect (0 vector).
  But otherwise, it's a decent function with forgiving slope."
  [program]
  (let [selector (push-based-selector program)]
    (vec (for [graph test-graphs]
             (abs (- (HCABS/run graph selector)
                     (.depth graph)))))))

(comment (defn -main [& args]
  (println
    "test run:"
    (HCABS/run (test-graphs 0) Selector/NUM_UNINFORMED))))

(defn -main [& args]
  (pushgp
    {:error-function error-function
     :atom-generators '(
                        exec_y
                        exec_pop
                        exec_eq
                        exec_stackdepth
                        exec_rot
                        exec_when
                        exec_do*times
                        exec_do*count
                        exec_s
                        exec_do*range
                        exec_if
                        exec_k
                        exec_yank
                        exec_yankdup
                        exec_swap
                        exec_dup
                        exec_shove

                        boolean_pop
                        boolean_dup
                        boolean_swap
                        boolean_rot
                        boolean_flush
                        boolean_eq
                        boolean_stackdepth
                        boolean_yank
                        boolean_yankdup
                        boolean_shove
                        boolean_and
                        boolean_or
                        boolean_not
                        boolean_xor
                        boolean_invert_first_then_and
                        boolean_invert_second_then_and
                        boolean_frominteger

                        integer_flush
                        integer_stackdepth
                        integer_yank
                        integer_yankdup
                        integer_shove
                        integer_add
                        integer_div
                        integer_dup
                        integer_eq
                        integer_gt
                        integer_lt
                        integer_mod
                        integer_mult
                        integer_pop
                        integer_rot
                        integer_sub
                        integer_swap
                        integer_fromboolean
                        integer_min
                        integer_max

                        node_pop
                        node_dup
                        node_swap
                        node_rot
                        node_flush
                        node_eq
                        node_stackdepth
                        node_yank
                        node_yankdup
                        node_shove
                        return_fromnode

                        bitset_pop
                        bitset_dup
                        bitset_swap
                        bitset_rot
                        bitset_flush
                        bitset_eq
                        bitset_stackdepth
                        bitset_yank
                        bitset_yankdup
                        bitset_shove

                        reduce-max
                        reduce-min

                        get-time
                        get-depth
                        nodes-of
                        neighbors-of
                        interferers-of
                        sensors-of
                        bfs-children

                        set-cardinality
                        is-empty
                        get-informed
                        get-active
                        get-able

                        set-and
                        set-or
                        set-xor
                        set-intersects
                        set-get
                        set-flip
                        set-set
                        set-clear
                        in-set

                        bfs-depth
                        bfs-decendents
                        bfs-child-count
                        bfs-parent
                        )
     ; :use-single-thread true
     :population-size 1000
     :max-generations 50
     :max-points 500
     :max-points-in-initial-program 200
     :evalpush-limit 1000
     :use-lexicase-selection true
     :mutation-probability 0.45
     :crossover-probability 0.45
     :simplification-probability 0.0
     :ultra-probability 0.0
     :print-history false})
  (shutdown-agents))
