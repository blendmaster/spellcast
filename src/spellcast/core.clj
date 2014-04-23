(ns spellcast.core
  (:use [clojush.pushgp.pushgp]
        [clojush.pushstate]
        [clojush.interpreter]
        [clojure.math.numeric-tower]
        [clojure.set])
  (:gen-class))

(defn network-from-points
  "[{:x :y}] -> BroadcastNetwork
  assumes points are connected"
  [points t-range i-range s-range]
  [])

(def test-network
  (network-from-points
    ;          o
    ;          o
    ;  x - o - o - o - o
    ;
    ;  optimal: 0 1 2 (3 5) (4 6)
    [[0 0] [0 1] [0 2] [1 2] [2 2] [0 3] [0 4]]
    1 1.1 1.2))

(define-registered
  neighbors-of
  (fn [state]
    ;; look at auxiliary stack, get out neighbors
    ))

;; also might define instructions to get number of type of neighbors
;; and functions to get current schedules
;;
;; depending on whether the entire algorithm can be GPd,
;; could also do `schedule` and `unschedule` instructions
;; that change some 'schedule' stack

(define-registered
  interferers-of
  (fn [state]
    ;; look at auxiliary stack, get out neighbors
    ))

(define-registered
  sensors-of
  (fn [state]
    ;; look at auxiliary stack, get out neighbors
    ))

(define-registered
  scheduled?
  (fn [state]
    ;; look at auxiliary stack return whether scheduled
    ))

(define-registered
  active?
  (fn [state]
    ;; look at auxiliary stack ...
    ))

(define-registered
  bfs-depth
  (fn [state]
    ;; depth of node from source, might be useful
    ))

(defn push-based-selector
  "wrap push-based program in clojure calling convention
   for the greedy scheduler"
  [program]
  (fn [network active scheduled queued]
    (let [stack (->> (make-push-state)
                     (push-item network :integer)
                     (push-item active :integer)
                     (push-item scheduled :integer)
                     (push-item queued :integer)
                     )
          state (run-push program stack)
          top-int (top-item :integer state)]
      (if (number? top-int)
        top-int
        ;; else, just choose the first active node, which
        ;; should punish programs that don't make a selection
        (active 0)))))

(defn error-function
  "evalulate program inside greedy algorithm, compared to lower bound."
  [program]
  (let [selector (push-based-selector program)]
    (map #(abs (- (lower-bound %)
                  (greedy-schedule-latency % selector)))
         test-networks)))

(defn -main [& args]
  (pushgp
    {:error-function error-function
     :atom-generators '(0
                        1
                        10
                        exec_dup
                        exec_eq
                        exec_if
                        exec_k
                        exec_noop
                        exec_pop
                        exec_rot
                        exec_s
                        exec_swap
                        exec_when
                        exec_y
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
                        )
     :population-size 1000
     :max-generations 500
     :max-points 500
     :max-points-in-initial-program 100
     :evalpush-limit 1000
     :use-lexicase-selection true
     :mutation-probability 0.35
     :crossover-probability 0.35
     :simplification-probability 0.1
     :ultra-probability 0.1
     :print-history false})
  (shutdown-agents))
