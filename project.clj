(defproject spellcast "0.1.0-SNAPSHOT"
  :description "GP-based heuristics for min-latency wireless broadcast"
  :url "https://github.com/blendmaster/spellcast"
  :license {:name "Unlicense"
            :url "http://unlicense.org/"}
  :dependencies [[org.clojure/clojure "1.6.0"]]
  :main ^:skip-aot spellcast.core
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}})
