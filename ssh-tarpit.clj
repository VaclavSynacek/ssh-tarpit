#!/usr/bin/env bb

(import (java.net ServerSocket))
(require '[clojure.string :as string]
         '[clojure.java.io :as io]
         '[babashka.process :refer [shell process exec]])

; state for logging purposes
(def active-clients (atom #{}))

(defn socket-fingerprint [client-socket]
  {;:local-addr (.toString (.getLocalAddress client-socket))
   ;:local-port (.getLocalPort client-socket)
   :remote-addr (.toString (.getInetAddress client-socket))
   :remote-port (.getPort client-socket)
   :connection-start (java.time.LocalDateTime/now)})

(defn to-seconds [javatime]
   (.toEpochSecond javatime (java.time.ZoneOffset/ofHours 0)))

(defn fingerprint-duration [now f]
  (assoc f :duration (- 
                       (to-seconds now)
                       (to-seconds (:connection-start f)))))
 

(defn process-one-client [client-socket fingerprint]
  "processes ssh connection with one client;
   TODO modify to experiment with possibly more sophisticated logic"
  (with-open [client-socket client-socket]
    (try
      (let [out (io/writer (.getOutputStream client-socket))
            in (io/reader (.getInputStream client-socket))]
           (.write out "SSH2.0-OpenSSH_15.4p5 tarpit pity\n")
           (.flush out)
           (loop [c 0]
             (Thread/sleep 2000)
             (.write out (str "infinite comment nr: " c "\n"))
             (.flush out)
             (recur (inc c))))
      (catch Exception e
        (println (str "client disconnected: "
                      (fingerprint-duration
                        (java.time.LocalDateTime/now)
                        fingerprint)))
        (swap! active-clients disj fingerprint)))))

    
(defn start-server [port]
  (with-open [server-socket (new ServerSocket port)]
    (println "SSH-Tarpit server starting on port " port)
    (loop []
      (try
        (let
          [client-socket (.accept server-socket) ;this will block until client comes
           fingerprint (socket-fingerprint client-socket)]
          (println "new client connected: " (socket-fingerprint client-socket))
          (swap! active-clients conj fingerprint)
          ; after socket connetion is accepted, move processing to separate thead
          (future (process-one-client client-socket fingerprint)))
        (catch Exception e
          (println (str "some global failure: " e))))
      (recur))))

(defn report-metrics [metric-name value]
  "wrapper around CloudWatch metric reporting by aws-cli;
   TODO could be refactored to aws api, but hey, this is babashka prototype :)"
  (println "reporting metric " metric-name "=" value)
  (shell
    {:out :string :err :out :continue true}
    (str
      "aws cloudwatch put-metric-data --metric-name "
      metric-name
      " --namespace Tarpit --unit Count --value "
      value)))

; the metric reporting runs on another thead in never-to-be-realized future
(future
  (while true
    (report-metrics
      "ActiveConnections"
      (count @active-clients))
    (report-metrics
      "AverageDuration"
      (let
        [now (java.time.LocalDateTime/now)
         durations (->> @active-clients
                       (map #(fingerprint-duration now %))
                       (map :duration))]
        (if (pos? (count durations))
          (* 1.0 (/ (reduce + durations) (count durations)))
          0)))
    (Thread/sleep (* 1000 60 1)))) ;every 1min

; the server listener to be started on main thread now
; assuming we are already on a dedicated instance and port 22 is free
(start-server 22)

(comment
  ; in REPL, comment the above start-server line and
  ; run the server listener in another thread so that you can poke around
  ; the state in REPL interactively
  ; also probably a good idea to use a high port number and do not run as root

  (future (start-server 2222))

  @active-clients

  (count @active-clients)
  
  nil) 
