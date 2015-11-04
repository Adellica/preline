;;; preline: adds careful logging to your program run
;;; preline 'echo hi ; echo error >/dev/stderr ; echo there'
;;; preline is (unsurprisingly) heavly line-based (and thus text-based)
;;;
;;; Copyright Adellica ® 2015
(use posix srfi-13)

;; process*'s input-ports don't support port->fileno se we need to do
;; this ourselves.
;;
;; returns 3 values:
;; - pid
;; - child's stdou
;; - child's stderr
(define (spawn* cmd #!optional (args '()) env)
  (let*-values
      (;;((in-in   in-out) (create-pipe))
       ((out-in out-out) (create-pipe))
       ((err-in err-out) (create-pipe))
       ((pid) (process-fork
               (lambda ()
                 ;;(duplicate-fileno in-in fileno/stdin)
                 (duplicate-fileno out-out fileno/stdout)
                 (duplicate-fileno err-out fileno/stderr)
                 ;;(file-close  in-in) (file-close in-out)
                 (file-close out-in) (file-close out-out)
                 (file-close err-in) (file-close err-out)
                 (process-execute cmd args env)) #t)))

    ;;(file-close in-in)
    (file-close out-out)
    (file-close err-out)

    (values pid out-in err-in)))


(define prefix (make-parameter " "))
(define time-format (make-parameter "%FT%T")) ;; TODO: <-- argv

(cond ((= 0 (length (command-line-arguments)))
       (print "usage: " (car (argv)) " [+prefix] <command>")
       (exit -1)))

(let ((option (car (command-line-arguments))))
  (cond ((string-prefix? "+" option)
         (time-format (substring option 1))
         (command-line-arguments (cdr (command-line-arguments))))))

(define (fd-read fd)
  (let* ((read (file-read fd 1024))
         (buffer (car read))
         (bytes (cadr read)))
    (substring buffer 0 bytes)))

(define (fmt-line line #!optional (tag ""))
  (print (time->string (seconds->utc-time) (time-format))
         (prefix) tag
         line))

(define pipe-fd    car)
(define pipe-buff cadr)
(define pipe-tag caddr)

(define (process-buffer buff tag)
  (cond ((string-index buff #\newline) =>
         (lambda (index)
           (fmt-line (substring buff 0 index) tag)
           (process-buffer (substring buff (add1 index)) tag)))
        (else buff)))

;; (process-buffer "a\nb\nc" "testing ")


;; fill pipe buffer as much as possible (nonblocking), process/print
;; all lines, return new pipe object.
(define (process-pipe pipe)
  (list (pipe-fd pipe)
        (process-buffer (string-append (pipe-buff pipe)
                                       (fd-read (pipe-fd pipe)))
                        (pipe-tag pipe))
        (pipe-tag pipe)))

(fmt-line "start")

(begin

  (define-values (pid cout cerr)
    (spawn* "/bin/sh"
            `("-c" ,(string-intersperse (command-line-arguments)))))

  (##sys#file-nonblocking! cout)
  (##sys#file-nonblocking! cerr))

(define-values
  (pipes exit-status)
  (let loop ((pipes `((,cerr "" "! ")
                      (,cout "" "> "))))
    (let ((fds (file-select (map pipe-fd pipes) #f)))
      (let ((pipes (map (lambda (pipe)
                          (if (member (pipe-fd pipe) fds)
                              (process-pipe pipe)
                              pipe))
                        pipes)))
        (let-values ( ( (pid reason exit-status)
                        (process-wait pid #t)))
          (if (= 0 pid) ;; still running
              (loop pipes)
              (values pipes exit-status)))))))

(define (pipe-add-newline pipe)
  (list (pipe-fd pipe)
        (if (not (string-null? (pipe-buff pipe)))
            (string-append (pipe-buff pipe) "\n")
            (pipe-buff pipe))
        (pipe-tag pipe)))

;; run through any newline-missing output. NOTE: we can't tell if last
;; line was missing \n or not
(for-each process-pipe
          (map pipe-add-newline
               ;; suck pipes dry:
               (map process-pipe pipes)))

;; close all pipes
(for-each file-close (map pipe-fd pipes))

(fmt-line (number->string exit-status) "exit ")
