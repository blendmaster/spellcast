(defproject spellcast "0.1.0-SNAPSHOT"
  :description "GP-based heuristics for min-latency wireless broadcast"
  :url "https://github.com/blendmaster/spellcast"
  :license {:name "Unlicense"
            :url "http://unlicense.org/"}
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [clojush "1.3.58"]
                 [org.clojars.pallix/analemma "1.0.0"]
                 ]
  :main ^:skip-aot spellcast.core
  :jvm-opts ["-ea"]
  ;:warn-on-reflection true
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}}
  :java-source-paths ["src"])
