;; -*-mode: Emacs-Lisp; tab-width: 4;-*- .

;; Information: <bookmark-buffers.el>
;;
;; bookmark buffer-list
;;
;; Last Modified: <2015/03/22 07:07:27>
;; Auther: <kobapan>
;;

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
;;

;; Installation
;;
;; Add bookmark-buffers.el to your load path
;; add your .emacs
;;
;; (autoload 'bookmark-buffers-save "bookmark-buffers" nil t)
;; (autoload 'bookmark-buffers-call "bookmark-buffers" nil t)
;; (global-set-key (kbd "C-c b s") 'bookmark-buffers-save)
;; (global-set-key (kbd "C-c b c") 'bookmark-buffers-call)
;;

;; Usage
;;
;; Ctrl+c b s to save buffers list with a key name
;;
;; Ctrl+c b c to call bookmark list
;; type ENTER or double left click on a bookmark name in the list, and files and directories which are listed in the bookmark will be open.
;;
;;

;; TODO
;; - save with default , last visited blist-key
;; - edit bookmark list
;; - edit file list in a bookmark

; (setq debug-on-error t)
; M-x edebug-defun


;;;;;; private variables

(defvar blist-file "~/.emacs.d/.blist")

(defcustom blist-save-append nil
"custom variable used in bookmark-buffers.el
t : save buffers list appending current buffers
nil : overwite buffers list with current buffers")


;;;;;; interactive functions

(defun bookmark-buffers-save ()
  "「現在バッファに開いているファイルとディレクトリのパス」のリストをブックマークする"
  (interactive)
  (ini-let
   (blist-key
    (completion-ignore-case t))
   (setq blist-key (read-something-with bookmark-list))
   (if (setq this-blist (assoc blist-key bookmark-list))
       (progn
         (setf (cadr this-blist)
               (if blist-save-append
                   (delete-dups (append (buffer-list-real) (cadr this-blist))) ;; バッファリストにバッファ追加
                 (buffer-list-real)))                                               ;; カレントなバッファリストを先頭に並べ替えして、ブックマークリストを上書き
         (setq bookmark-list (sort-bookmark-list this-blist bookmark-list)))
     (setq this-blist (list blist-key (buffer-list-real)))
     (setq bookmark-list (cons this-blist bookmark-list))) ;; 新規バッファリストを先頭に追加
   (save-bookmark-list buffer-blist-file bookmark-list)))

(defun bookmark-buffers-call ()
  "ブックマーク一覧モード
 一覧の中のブックマークをひとつポイントし、
 [enter]: 現在開いているファイルを全て閉じて、選択したブックマークに登録してあったファイルをすべて開く。
 [d]: ブックマークを削除。y or n。
 [q]: ブックマーク一覧モード終了
 [e]: ブックマーク編集。ブックマークの中に登録してあるファイルを [d] で削除。 y or n。 [q] でブックマーク一覧に戻る。"
  (interactive)
  (ini-let
   (blist-key
    (blist-buffer "*blist*")
    (map (make-sparse-keymap)))
   (switch-to-buffer blist-buffer)
   (setq buffer-read-only nil) ; unlock
   (erase-buffer)
   (insert (mapconcat 'identity
                      (mapcar 
                       (lambda (x)
                         (car x))
                       bookmark-list)
                      "\n"))
   (setq buffer-read-only t)   ; lock
   (goto-char (point-min))
   (setq mode-name "blist-mode")
   (define-key map [double-mouse-1] 'bookmark-buffers-open)
   (define-key map [return] 'bookmark-buffers-open)
   (define-key map "d" 'bookmark-buffers-delete)
   (define-key map "q" 'bookmark-buffers-quit)
   (use-local-map map)))

(defun bookmark-buffers-open ()
  "open files and directories in a bookmark"
  (interactive)
  (ini-let
   ((blist-key (load-blist-key)))
   (save-bookmark-list buffer-blist-file
                       ;; カレントなバッファリストを先頭に並べ替え
                       (sort-bookmark-list this-blist bookmark-list)) 
   (kill-all-buffers)
   (mapcar '(lambda (file) (find-file file))
           (reverse (cadr this-blist)))))

(defun bookmark-buffers-delete ()
  "delete a bookmark on the point"
  (interactive)
  (ini-let
   ((blist-key (load-blist-key)))
   (when (y-or-n-p (concat "delete " blist-key " ? "))
     (save-bookmark-list buffer-blist-file (delq this-blist bookmark-list))
     (bookmark-buffers-call))))

(defun bookmark-buffers-quit ()
  "kill blist buffer"
  (interactive)
  (kill-buffer (current-buffer)))


;;;;;; private functions

(defmacro ini-let (binds &rest body)
  "init bookmark-buffers private values"
  `(let* (,@binds
          (buffer-blist-file (set-buffer (find-file-noselect blist-file)))
          (bookmark-list (get-bookmark-list))
          (this-blist (assoc blist-key bookmark-list)))
     ,@body))

(defun load-blist-key ()
  "*blist*で現在ポイントされている行を読み込む"
  (buffer-substring
   (progn (beginning-of-line) (point))
   (progn (end-of-line) (point))))

(defun read-something-with (alist)
  "dont save with 0byte key name"
  (let ((res (completing-read
              "bookmark buffers list with Key Name: "
              (mapcar (lambda (slot) (car slot)) alist))))
    (or (if (string< "" res) res)
        (read-something-with alist))))

(defun sort-bookmark-list (this src)
  "this を先頭に"
  (cons this (delq this src)))

(defun buffer-list-real ()
  "list up files and directories with `full path` from buffer list"
  (delq nil (mapcar
             (lambda (x)
               (set-buffer x)
               (unless (string= (file-name-nondirectory blist-file) (buffer-name)) ;exclude .blist
                 (or (buffer-file-name) list-buffers-directory)))
             (buffer-list))))

(defun kill-all-buffers ()
  "kill all buffers"
  (let ((exclude '("*scratch*" "*Messages*")))
    (mapcar '(lambda (b)
               (let ((buf (buffer-name b)))
                 (unless (member buf exclude)
                   (kill-buffer buf))))
            (buffer-list))))

(defun get-bookmark-list ()
  ".blistからバッファリストのリストを読み込む"
  (widen)
  (goto-char (point-min))
  (condition-case err
      (read (current-buffer))
    (error (message "init .blist"))))

(defun save-bookmark-list (buf blist)
  ".blistにバッファリストのリストを保存する"
    (erase-buffer)
    (prin1 blist buf)
    (save-buffer)
    (kill-buffer buf))



(provide 'bookmark-buffers)
