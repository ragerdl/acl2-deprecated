#|$ACL2s-Preamble$;
(begin-book);$ACL2s-Preamble$|#


;; Parses a descirption in the AND/IF_1.0 format (see http_//edis.win.tue.nl/and-if/index.html)
;; Assumptions:
;;   1.) Symbols have the following format c_x, where:
;;       c is the name of a channel
;;       x is either R or A (for request or acknowledge)
;;   2.) The description does not contain the colon (the symbol ":")
;;       This is actually a problem, so to use this parser, replace all semi-columns with underscores.
;;
;; See for examples of usage below

(in-package "ACL2")

(include-book "ordinals/lexicographic-ordering" :dir :system)


;; Returns the index of a in x.
;; Assumes a is in x.
(defun index-of (a x)
  (cond ((endp x)
         0)
        ((equal (car x) a)
         0)
        (t
         (1+ (index-of a (cdr x))))))
;; Generates a label (c R/A IN/EX) from a symbol c_x
(defun generate_trans_label (and/if_1.0 symbol)
  (let* ((NFA (cdadr and/if_1.0))
         (SYMBOLS (cdr (assoc 'SYMBOLS NFA)))
         (in/ex (equal (cadr (assoc symbol SYMBOLS)) 'output))
         (var-chars (coerce (symbol-name symbol) 'list))
         (pos_of_underscore (index-of #\_ var-chars))
         (channel-name (packn (firstn pos_of_underscore var-chars)))
         (read/ack (nth (1+ pos_of_underscore) var-chars)))
    (list channel-name (packn (list read/ack)) (if in/ex 'in 'ex))))
;; Generates a list of transitions for the given state-number 
(defun generate-transitions (and/if_1.0 state-number transition-number)
  (if (zp transition-number)
    nil
    (let* ((NFA (cdadr and/if_1.0))
           (TRANSITIONS (cdr (assoc 'TRANSITIONS NFA)))
           (TRANSITION (nth (1- transition-number) TRANSITIONS))
           (TRANS_SRC (nth 0 TRANSITION))
           (TRANS_END (nth 1 TRANSITION))
           (TRANS_LABEL (nth 2 TRANSITION))
           (trans_label (generate_trans_label and/if_1.0 TRANS_LABEL))
           (trans_end_state (packn `(s ,TRANS_END))))
      (if (equal TRANS_SRC state-number)
        (cons (list trans_label trans_end_state)
              (generate-transitions and/if_1.0 state-number (1- transition-number)))
        (generate-transitions and/if_1.0 state-number (1- transition-number)))
      )))
;; Generates the xdi-sm state machine in ACL2 for each state < state-number
(defun generate-xdi-sm (and/if_1.0 state-number)
  (if (zp state-number)
    nil
    (let* ((NFA (cdadr and/if_1.0))
           (STATES (cdr (assoc 'STATES NFA)))
           (STATE (nth (1- state-number) STATES))
           (INITIAL (equal (nth 2 STATE) 'INITIAL))
           (TYPE (nth 1 STATE))
           (TRANSITIONS (cdr (assoc 'TRANSITIONS NFA)))
           (state-name (car STATE))
           (num_of_transitions (len TRANSITIONS))
           (transitions (generate-transitions and/if_1.0 (1- state-number) num_of_transitions)))
      (cons (list (packn `(s ,state-name)) INITIAL TYPE transitions)
            (generate-xdi-sm and/if_1.0 (1- state-number))))))
;; Wrapper function.
;; Given an AND/IF_1.0 description of the state machine, parese it and return an ACL2 object.
(defun parse (and/if_1.0)
  (let* ((NFA (cdadr and/if_1.0))
         (STATES (cdr (assoc 'STATES NFA)))
         (num_of_states (len STATES)))
    (generate-xdi-sm and/if_1.0 num_of_states)))
    
;; Example usage:
;; The AND/IF_1.0 description of a Join, with each semi-colon replaced with and underscore. And off course, a quote before it_
(defconst *xdi-sm-join* (parse
                         '(AND/IF_1.0
                           (NFA 
                            (NAME JOIN)
                            (INTERPRETATION Mallon/STF)
                            (NOTE Generated by digg v1.0)
                            (SYMBOLS 
                             (in0_R INPUT )
                             (in1_R INPUT )
                             (out_A INPUT )
                             (in0_A OUTPUT )
                             (in1_A OUTPUT )
                             (out_R OUTPUT )
                             )
                            (STATES 
                             (0 BOX INITIAL DIST_0 PLACE_-60_-150 ) 
                             (1 BOX DIST_1 PLACE_90_-90 ) 
                             (2 BOX DIST_1 PLACE_180_-150 ) 
                             (3 TRANSIENT DIST_2 PLACE_300_-90 ) 
                             (4 BOX DIST_3 PLACE_210_210 ) 
                             (5 TRANSIENT DIST_4 PLACE_-360_120 ) 
                             (6 TRANSIENT DIST_5 PLACE_-120_0 ) 
                             (7 TRANSIENT DIST_5 PLACE_-270_-60 ) 
                             (8 TRANSIENT DIST_6 PLACE_-150_-330 ) 
                             (9 TRANSIENT DIST_6 PLACE_30_60 ) 
                             )
                            (TRANSITIONS
                             (0 1 in0_R SYMBOLPOS_2519_-2204 )
                             (0 2 in1_R SYMBOLPOS_2596_1009 )
                             (1 3 in1_R SYMBOLPOS_2365_-1021 )
                             (2 3 in0_R SYMBOLPOS_4885_-229 )
                             (3 4 out_R SYMBOLPOS_5510_-408 )
                             (4 5 out_A SYMBOLPOS_5185_-123 )
                             (5 6 in0_A SYMBOLPOS_5468_0 )
                             (5 7 in1_A SYMBOLPOS_4962_37 )
                             (6 9 in0_R SYMBOLPOS_5116_232 )
                             (6 0 in1_A SYMBOLPOS_2283_2913 )
                             (7 8 in1_R SYMBOLPOS_1380_1641 )
                             (7 0 in0_A SYMBOLPOS_5069_-69 )
                             (8 2 in0_A SYMBOLPOS_1149_-1120 )
                             (9 1 in1_A SYMBOLPOS_4932_0 )
                             )))))


(defconst *xdi-sm-fork* (parse
                         '(AND/IF_1.0
                           (NFA 
                            (NAME fork)
                            (INTERPRETATION Mallon/STF)
                            (NOTE Generated by digg v1.0)
                            (SYMBOLS 
                             (in_R INPUT )
                             (out0_A INPUT )
                             (out1_A INPUT )
                             (in_A OUTPUT )
                             (out0_R OUTPUT )
                             (out1_R OUTPUT )
                             )
                            (STATES 
                             (0 BOX INITIAL DIST_0 PLACE_330_90 ) 
                             (1 TRANSIENT DIST_1 PLACE_240_-330 ) 
                             (2 TRANSIENT DIST_2 PLACE_150_-180 ) 
                             (3 TRANSIENT DIST_2 PLACE_60_-330 ) 
                             (4 TRANSIENT DIST_3 PLACE_-60_-330 ) 
                             (5 BOX DIST_3 PLACE_-60_-180 ) 
                             (6 BOX DIST_4 PLACE_-60_-60 ) 
                             (7 BOX DIST_4 PLACE_-210_-180 ) 
                             (8 TRANSIENT DIST_5 PLACE_-210_-60 ) 
                             (9 TRANSIENT DIST_3 PLACE_150_-60 ) 
                             )
                            (TRANSITIONS
                             (0 1 in_R SYMBOLPOS_4193_-645 )
                             (1 2 out0_R SYMBOLPOS_5151_-606 )
                             (1 3 out1_R SYMBOLPOS_5073_147 )
                             (2 9 out0_A SYMBOLPOS_5510_-408 )
                             (2 5 out1_R SYMBOLPOS_5055_73 )
                             (3 4 out1_A SYMBOLPOS_4857_-71 )
                             (3 5 out0_R SYMBOLPOS_5250_83 )
                             (4 7 out0_R SYMBOLPOS_5000_238 )
                             (5 6 out0_A SYMBOLPOS_5000_-62 )
                             (5 7 out1_A SYMBOLPOS_4837_0 )
                             (6 8 out1_A SYMBOLPOS_5396_158 )
                             (7 8 out0_A SYMBOLPOS_5038_-38 )
                             (8 0 in_A SYMBOLPOS_4927_72 )
                             (9 6 out1_R SYMBOLPOS_5340_-113 )
                             ))))
)


(defconst *xdi-sm-merge* (parse
                          '(AND/IF_1.0
                            (NFA 
                             (NAME merge)
                             (INTERPRETATION Mallon/STF)
                             (NOTE Generated by digg v1.0)
                             (SYMBOLS 
                              (in0_R INPUT )
                              (in1_R INPUT )
                              (out_A INPUT )
                              (in0_A OUTPUT )
                              (in1_A OUTPUT )
                              (out_R OUTPUT )
                              )
                             (STATES 
                              (0 BOX INITIAL DIST_0 PLACE_210_360 ) 
                              (1 TRANSIENT DIST_1 PLACE_60_360 ) 
                              (2 TRANSIENT DIST_1 PLACE_90_240 ) 
                              (3 BOX DIST_2 PLACE_210_120 ) 
                              (4 BOX DIST_3 PLACE_420_120 ) 
                              (5 TRANSIENT DIST_3 PLACE_330_240 ) 
                              (6 TRANSIENT DIST_4 PLACE_540_240 ) 
                              (7 TRANSIENT DIST_5 PLACE_630_360 ) 
                              (8 TRANSIENT DIST_6 PLACE_450_360 ) 
                              (9 BOX DIST_2 PLACE_180_480 ) 
                              (10 BOX DIST_3 PLACE_270_600 ) 
                              (11 TRANSIENT DIST_3 PLACE_330_480 ) 
                              (12 TRANSIENT DIST_4 PLACE_420_600 ) 
                              (13 TRANSIENT DIST_5 PLACE_570_480 ) 
                              (Stfinternal2 DUMMY_1 TRANSIENT PLACE_660_120 ) 
                              (Stfinternal3 DUMMY_2 TRANSIENT PLACE_540_720 ) 
                              (Stfinternal4 DUMMY_9 BOX PLACE_750_240 ) 
                              (Stfinternal5 DUMMY_3 BOX PLACE_690_600 ) 
                              )
                             (TRANSITIONS
                              (0 1 in0_R SYMBOLPOS_4193_-645 )
                              (0 2 in1_R SYMBOLPOS_5200_800 )
                              (1 9 out_R SYMBOLPOS_5185_-740 )
                              (2 3 out_R SYMBOLPOS_4800_1200 )
                              (3 4 in0_R SYMBOLPOS_4473_263 )
                              (3 5 out_A SYMBOLPOS_4867_-52 )
                              (4 6 out_A SYMBOLPOS_4772_113 )
                              (5 6 in0_R SYMBOLPOS_5000_129 )
                              (5 0 in1_A SYMBOLPOS_5193_77 )
                              (6 Stfinternal2 in1_A SYMBOLPOS_5019_-77 )
                              (6 7 out_R SYMBOLPOS_4531_0 )
                              (7 8 out_A SYMBOLPOS_5025_-16 )
                              (7 Stfinternal4 in1_A SYMBOLPOS_5042_-57 )
                              (8 5 in0_A SYMBOLPOS_4234_-2012 )
                              (8 11 in1_A SYMBOLPOS_5638_527 )
                              (9 10 in1_R SYMBOLPOS_5789_-526 )
                              (9 11 out_A SYMBOLPOS_5084_56 )
                              (10 12 out_A SYMBOLPOS_5185_-123 )
                              (11 12 in1_R SYMBOLPOS_5000_-86 )
                              (11 0 in0_A SYMBOLPOS_4758_0 )
                              (12 Stfinternal3 in0_A SYMBOLPOS_4942_115 )
                              (12 13 out_R SYMBOLPOS_5468_0 )
                              (13 8 out_A SYMBOLPOS_5116_232 )
                              (13 Stfinternal5 in0_A SYMBOLPOS_4941_58 )
                              )))))


(defconst *xdi-sm-distributor-acks*
  '((select00 select);;A 'select00 is acknowledged by a 'select
    (select01 select)
    (select10 select)
    ));(select11 select)))
(defconst *xdi-sm-distributor* (parse
                                '(AND/IF_1.0 
                                  (NFA 
                                   (NAME distributor)
                                   (INTERPRETATION Verhoeff/XDI)
                                   (NOTE Generated by digg v1.0)
  
                                   (SYMBOLS 
                                    (in_R INPUT)
                                    (select00_R INPUT)
                                    (select01_R INPUT)
                                    (select10_R INPUT)
                                    ;(select11_R INPUT)
                                    (out0_A INPUT)
                                    (out1_A INPUT)
                                    (out0_R OUTPUT)
                                    (out1_R OUTPUT)
                                    (in_A OUTPUT)
                                    (select_A OUTPUT)
                                    )
                                   (STATES 
                                    (0 BOX INITIAL)
                                    (1 BOX)
                                    (2 BOX)
                                    (3 BOX)
                                    (4 BOX)
                                    (5 BOX)
                                    (6 TRANSIENT)
                                    (7 TRANSIENT)
                                    (8 TRANSIENT)
                                    (9 TRANSIENT)
                                    (10 BOX)
                                    (11 BOX)
                                    (12 BOX)
                                    (13 TRANSIENT)
                                    (14 TRANSIENT)
                                    (15 TRANSIENT)
                                    (16 TRANSIENT)
                                    (17 TRANSIENT)
                                    (18 TRANSIENT)
                                    (19 TRANSIENT)
                                    (20 TRANSIENT)
                                    (21 TRANSIENT)
                                    )
                                   (TRANSITIONS
                                    (0 1 in_R)
                                    (0 2 select00_R)
                                    (0 3 select01_R)
                                    (0 4 select10_R)
                                    ;(0 5 select11_R)
                                    (1 13 select00_R)
                                    (1 21 select01_R)
                                    (1 9 select10_R)
                                    ;(1 6 select11_R)
                                    (2 13 in_R)
                                    (3 21 in_R)
                                    (4 9 in_R)
                                    (5 6 in_R)
                                    (6 7 out0_R)
                                    (6 8 out1_R)
                                    (7 21 out0_A)
                                    (7 10 out1_R)
                                    (8 9 out1_A)
                                    (8 10 out0_R)
                                    (9 12 out0_R)
                                    (10 11 out0_A)
                                    (10 12 out1_A)
                                    (11 13 out1_A)
                                    (12 13 out0_A)
                                    (13 14 in_A)
                                    (13 15 select_A)
                                    (14 20 in_R)
                                    (14 0 select_A)
                                    (15 16 select00_R)
                                    (15 17 select01_R)
                                    (15 18 select10_R)
                                    ;(15 19 select11_R)
                                    (15 0 in_A)
                                    (16 2 in_A)
                                    (17 3 in_A)
                                    (18 4 in_A)
                                    (19 5 in_A)
                                    (20 1 select_A)
                                    (21 11 out1_R)
                                    )
                                   ))
                                
                                ))



(defconst *xdi-sm-storage* (parse '(AND/IF_1.0
  (NFA 
     (NAME storage)
     (INTERPRETATION Mallon/STF)
     (NOTE Generated by digg v1.0)
     (SYMBOLS 
               (in_R INPUT )
               (out_A INPUT )
               (in_A OUTPUT )
               (out_R OUTPUT )
)
      (STATES 
               (0 BOX INITIAL DIST_0 PLACE_330_60 ) 
               (1 TRANSIENT DIST_1 PLACE_540_360 ) 
               (2 TRANSIENT DIST_2 PLACE_-30_330 ) 
               (3 TRANSIENT DIST_2 PLACE_150_150 ) 
               (4 TRANSIENT DIST_3 PLACE_330_180 ) 
               (5 BOX DIST_3 PLACE_150_30 ) 
               (6 BOX DIST_4 PLACE_600_30 ) 
               (7 TRANSIENT DIST_3 PLACE_30_-60 ) 
)
      (TRANSITIONS
               (0 1 in_R SYMBOLPOS_4193_-645 )
               (1 2 in_A SYMBOLPOS_5151_-606 )
               (1 3 out_R SYMBOLPOS_5073_147 )
               (2 7 in_R SYMBOLPOS_5510_-408 )
               (2 5 out_R SYMBOLPOS_5055_73 )
               (3 4 out_A SYMBOLPOS_4857_-71 )
               (3 5 in_A SYMBOLPOS_5250_83 )
               (4 0 in_A SYMBOLPOS_5193_-77 )
               (5 6 in_R SYMBOLPOS_5000_-62 )
               (5 0 out_A SYMBOLPOS_4792_-118 )
               (6 1 out_A SYMBOLPOS_4951_48 )
               (7 6 out_R SYMBOLPOS_5340_-113 )
)))
 ))


(defconst *xdi-sm-fullstorage* (parse '(AND/IF_1.0
  (NFA 
     (NAME fullstorage)
     (INTERPRETATION Mallon/STF)
     (NOTE Generated by digg v1.0)
     (SYMBOLS 
               (in_R INPUT )
               (out_A INPUT )
               (in_A OUTPUT )
               (out_R OUTPUT )
)
      (STATES 
               (0 TRANSIENT INITIAL DIST_0 PLACE_0_360 ) 
               (1 TRANSIENT DIST_1 PLACE_30_-60 ) 
               (2 BOX DIST_1 PLACE_150_30 ) 
               (3 BOX DIST_2 PLACE_510_0 ) 
               (4 BOX DIST_2 PLACE_330_60 ) 
               (5 TRANSIENT DIST_3 PLACE_450_360 ) 
               (6 TRANSIENT DIST_4 PLACE_150_180 ) 
               (7 TRANSIENT DIST_5 PLACE_330_210 ) 
)
      (TRANSITIONS
               (0 1 in_R SYMBOLPOS_4571_-571 )
               (0 2 out_R SYMBOLPOS_5161_645 )
               (1 3 out_R SYMBOLPOS_5185_-740 )
               (2 3 in_R SYMBOLPOS_4918_-163 )
               (2 4 out_A SYMBOLPOS_4210_1578 )
               (3 5 out_A SYMBOLPOS_5789_-526 )
               (4 5 in_R SYMBOLPOS_5000_-87 )
               (5 0 in_A SYMBOLPOS_4892_215 )
               (5 6 out_R SYMBOLPOS_5340_-113 )
               (6 7 out_A SYMBOLPOS_5468_0 )
               (6 2 in_A SYMBOLPOS_4960_80 )
               (7 4 in_A SYMBOLPOS_4941_58 )
)))))#|ACL2s-ToDo-Line|#

