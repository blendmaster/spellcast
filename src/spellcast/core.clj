(ns spellcast.core
  (:use [clojush.pushgp.pushgp]
        [clojush.pushstate]
        [clojush.interpreter]
        [clojure.math.numeric-tower])
  (:gen-class))

(defn error-function
  "objective function for programs."
  [program]
  (for [input (range 1 5)
        input2 (range 1 5)]
    (let [stack (->> (make-push-state)
                     (push-item input :integer)
                     (push-item input2 :integer))
          state (run-push program stack)
          top-int (top-item :integer state)]
      (if (number? top-int)
        (abs (- top-int (* input (+ 10 input2))))
        1000))))

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
