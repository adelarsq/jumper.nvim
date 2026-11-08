(when vim.g.loaded_jumper (lua "return "))

(local M {})

;; ============================================================================
;; SQLite persistence
;; ============================================================================

(local sqlite (require :sqlite.db))

;; Cache de conexões por caminho de banco (evita abrir/fechar toda hora)
(local db-connections {})

;; Retorna o caminho do banco global (usado quando não é repositório Git)
(fn get-global-db-path []
  (let [data-dir (vim.fn.stdpath :data)
        jumper-dir (.. data-dir :/jumper)]
    (vim.fn.mkdir jumper-dir :p)
    (.. jumper-dir :/global.db)))

;; Verifica se um diretório é (ou está dentro de) um repositório Git.
;; Retorna o caminho da raiz do repositório ou nil.
(fn find-git-root [start-dir]
  (var dir start-dir)
  (var found nil)
  (while (and dir (not found) (not= dir ""))
    (let [git-dir (.. dir :/.git)]
      (when (= 1 (vim.fn.isdirectory git-dir))
        (set found dir)))
    (let [parent (vim.fn.fnamemodify dir ":h")]
      (if (= parent dir)
          (set dir nil)
          (set dir parent))))
  found)

;; Retorna o caminho do banco para o diretório atual.
(fn get-db-path-for-cwd []
  (let [cwd (vim.fn.getcwd)
        git-root (find-git-root cwd)]
    (if git-root
        (let [data-dir (vim.fn.stdpath :data)
              jumper-dir (.. data-dir :/jumper)
              hash (vim.fn.sha256 git-root)
              short-hash (string.sub hash 1 16)]
          (vim.fn.mkdir jumper-dir :p)
          (.. jumper-dir :/repo- short-hash :.db))
        (get-global-db-path))))

;; Abre (ou reutiliza) a conexão com o banco no caminho dado.
(fn get-db [path]
  (or (. db-connections path)
      (let [db (sqlite:open path)]
        (tset db-connections path db)
        db)))

;; Garante que as tabelas `files` e `bookmarks` existem no banco.
(fn ensure-table [db]
  (db:eval "CREATE TABLE IF NOT EXISTS files (
    file text not null,
    path text not null
  )")
  (db:eval "CREATE TABLE IF NOT EXISTS bookmarks (
    file text not null,
    path text not null,
    lnum integer not null,
    note text not null
  )"))

;; Retorna a lista de arquivos persistida para um diretório.
(fn load-files-for-dir [dir]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (let [rows (db:eval "select file from files where path = :path order by rowid" {:path dir})]
      (if (= (type rows) :table)
          (icollect [_ row (ipairs rows)] row.file)
          []))))

;; Retorna os bookmarks persistidos para um diretório.
(fn load-bookmarks-for-dir [dir]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (let [rows (db:eval "select file, lnum, note from bookmarks where path = :path order by file, lnum" {:path dir})]
      (if (= (type rows) :table)
          (icollect [_ row (ipairs rows)]
            {:file row.file :lnum row.lnum :note row.note})
          []))))

;; Substitui a lista de arquivos persistida para um diretório.
(fn save-files-for-dir [dir file-list]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (db:eval "delete from files where path = :path" {:path dir})
    (each [_ file (ipairs file-list)]
      (db:eval "insert into files (path, file) values (:path, :file)"
               {:path dir :file file}))))

;; Persiste um bookmark (adiciona ou atualiza).
(fn save-bookmark [dir file lnum note]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (db:eval "delete from bookmarks where path = :path and file = :file and lnum = :lnum"
             {:path dir :file file :lnum lnum})
    (db:eval "insert into bookmarks (path, file, lnum, note) values (:path, :file, :lnum, :note)"
             {:path dir :file file :lnum lnum :note note})))

;; Remove todos os bookmarks de um arquivo.
(fn remove-bookmarks-for-file [dir file]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (db:eval "delete from bookmarks where path = :path and file = :file"
             {:path dir :file file})))

;; Remove um bookmark específico (file, lnum) do banco.
(fn remove-bookmark-from-db [dir file lnum]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (db:eval "delete from bookmarks where path = :path and file = :file and lnum = :lnum"
             {:path dir :file file :lnum lnum})))

;; ============================================================================
;; Estado em memória (cache) — mantido em sincronia com o banco
;; ============================================================================

(local files [])

;; bookmarks: lista de {:file :lnum :note}
(local bookmarks [])

(var current-dir (vim.fn.getcwd))

;; Limpa a tabela `files` em memória (sem reatribuir o binding)
(fn clear-files-table []
  (while (> (length files) 0)
    (table.remove files)))

;; Limpa a tabela `bookmarks` em memória.
(fn clear-bookmarks-table []
  (while (> (length bookmarks) 0)
    (table.remove bookmarks)))

;; ============================================================================
;; Signs (bandeirinha de bookmark) — declarados APÓS `bookmarks` existir
;; ============================================================================

;; Define o sign "JumperBookmark" (bandeirinha) uma única vez.
(fn define-sign []
  (vim.fn.sign_define "JumperBookmark"
    {:text "⚑"
     :texthl "DiagnosticWarn"
     :numhl "DiagnosticWarn"}))

(define-sign)

;; Retorna os bookmarks de um arquivo (do cache em memória).
(fn bookmarks-for-file [file]
  (icollect [_ b (ipairs bookmarks)]
    (when (= b.file file) b)))

;; Remove todos os signs de bookmark de um buffer.
(fn clear-signs-in-buffer [bufnr]
  (vim.fn.sign_unplace "jumper" {:buffer bufnr}))

;; Coloca signs em todas as linhas bookmarkadas do buffer.
(fn refresh-signs-in-buffer [bufnr file]
  (when (vim.api.nvim_buf_is_valid bufnr)
    (clear-signs-in-buffer bufnr)
    (each [_ b (ipairs (bookmarks-for-file file))]
      (when (and (>= b.lnum 1) (<= b.lnum (vim.api.nvim_buf_line_count bufnr)))
        (vim.fn.sign_place 0 "jumper" "JumperBookmark" bufnr
          {:lnum b.lnum :priority 10})))))

;; Atualiza signs no buffer atual (se ele corresponde ao arquivo).
(fn refresh-signs-current-buffer []
  (let [bufnr (vim.api.nvim_get_current_buf)
        file (vim.fn.expand "%:p")]
    (when (not= file "")
      (refresh-signs-in-buffer bufnr file))))

;; Reaplica signs em todos os buffers abertos (após reload de bookmarks).
(fn refresh-all-signs []
  (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
    (when (vim.api.nvim_buf_is_loaded bufnr)
      (let [name (vim.api.nvim_buf_get_name bufnr)]
        (when (not= name "")
          (refresh-signs-in-buffer bufnr name))))))

;; ============================================================================
;; Reload / persist (agora podem usar refresh-all-signs)
;; ============================================================================

;; Carrega a lista persistida do diretório atual para `files` e `bookmarks`.
(fn reload-files []
  (let [dir (vim.fn.getcwd)
        persisted-files (load-files-for-dir dir)
        persisted-bookmarks (load-bookmarks-for-dir dir)]
    (set current-dir dir)
    (clear-files-table)
    (each [_ f (ipairs persisted-files)]
      (table.insert files f))
    (clear-bookmarks-table)
    (each [_ b (ipairs persisted-bookmarks)]
      (table.insert bookmarks b))
    (set vim.g.file_list files)
    (refresh-all-signs)))

;; Sincroniza a lista em memória com o banco para o diretório atual.
(fn persist-files []
  (save-files-for-dir current-dir files)
  (set vim.g.file_list files))

;; Carrega ao iniciar.
(reload-files)

;; ============================================================================
;; Funções originais (adaptadas para persistência)
;; ============================================================================

(fn get-oil-file-path []
  (let [(use imported) (pcall require :oil)]
    (when use
      (local entry (imported.get_cursor_entry))
      (when (= (. entry :type) :file)
        (local dir (imported.get_current_dir))
        (local file-name (. entry :name))
        (.. dir file-name)))
    ""))

(fn get-nvim-tree-file-path []
  (let [(use imported) (pcall require :nvim-tree.lib)]
    (when use
      (local entry (imported.get_node_at_cursor))
      entry.absolute_path)
    ""))

;; Obtém o caminho do arquivo atual, considerando plugins de file manager.
(fn get-current-file-path []
  (var current-file "")
  (local filetype vim.bo.filetype)
  (if (= filetype :oil)
        (set current-file (get-oil-file-path))
      (= filetype :NvimTree)
        (set current-file (get-nvim-tree-file-path))
      (set current-file (vim.fn.expand "%:p")))
  current-file)

(fn add-current-file []
  (let [current-file (get-current-file-path)]
    (when (and current-file (not= current-file "")
               (not (vim.tbl_contains files current-file)))
      (table.insert files current-file)
      (persist-files)
      (vim.api.nvim_echo [[(.. "Added " current-file " to the list.")]] false {}))))

;; Retorna true se um bookmark (file, lnum) já existe.
(fn bookmark-exists? [file lnum]
  (var found false)
  (each [_ b (ipairs bookmarks)]
    (when (and (= b.file file) (= b.lnum lnum))
      (set found true)))
  found)

;; Remove um bookmark (file, lnum) da memória.
(fn remove-bookmark-from-memory [file lnum]
  (var new-list [])
  (each [_ b (ipairs bookmarks)]
    (when (not (and (= b.file file) (= b.lnum lnum)))
      (table.insert new-list b)))
  (clear-bookmarks-table)
  (each [_ b (ipairs new-list)]
    (table.insert bookmarks b)))

;; Adiciona um bookmark na linha atual (com comentário).
;; Também executa JumperAdd sobre o arquivo.
(fn add-bookmark []
  (let [current-file (get-current-file-path)]
    (if (or (= current-file "") (not vim.bo.modifiable) (= vim.bo.buftype :terminal))
        (vim.api.nvim_echo [["Cannot bookmark this buffer." "WarningMsg"]] false {})
        (do
          ;; Garante que o arquivo está na lista (JumperAdd)
          (when (not (vim.tbl_contains files current-file))
            (table.insert files current-file)
            (persist-files))
          ;; Pede o comentário
          (let [lnum (vim.fn.line ".")
                default (.. "line " lnum)
                note (vim.fn.input (.. "Bookmark comment for line " lnum ": ") default)]
            (if (= note "")
                (vim.api.nvim_echo [["Bookmark cancelled." "WarningMsg"]] false {})
                (do
                  (save-bookmark current-dir current-file lnum note)
                  (remove-bookmark-from-memory current-file lnum)
                  (table.insert bookmarks {:file current-file :lnum lnum :note note})
                  (refresh-signs-current-buffer)
                  (vim.api.nvim_echo
                    [[(.. "Bookmarked " (vim.fn.fnamemodify current-file ":t")
                          ":" lnum " -> " note)]]
                    false {}))))))))

;; Remove o bookmark da linha atual (com confirmação).
(fn remove-current-bookmark []
  (let [current-file (get-current-file-path)
        lnum (vim.fn.line ".")]
    (if (or (= current-file "") (not (bookmark-exists? current-file lnum)))
        (vim.api.nvim_echo
          [["No bookmark on the current line." "WarningMsg"]] false {})
        (let [confirm (vim.fn.confirm
                        (.. "Remove bookmark at "
                            (vim.fn.fnamemodify current-file ":t") ":" lnum "?")
                        "&Yes\n&No" 2)]
          (when (= confirm 1)
            (remove-bookmark-from-memory current-file lnum)
            (remove-bookmark-from-db current-dir current-file lnum)
            (refresh-signs-current-buffer)
            (vim.api.nvim_echo
              [[(.. "Bookmark removed from "
                    (vim.fn.fnamemodify current-file ":t") ":" lnum ".")]]
              false {}))))))

;; Retorna a lista de linhas (ordenadas) dos bookmarks do arquivo atual.
(fn get-bookmark-lines-for-current-file []
  (let [file (vim.fn.expand "%:p")
        lines []]
    (each [_ b (ipairs bookmarks)]
      (when (= b.file file)
        (table.insert lines b.lnum)))
    (table.sort lines)
    lines))

;; Vai para o próximo bookmark no arquivo atual (com wrap-around).
(fn navigate-to-next-bookmark []
  (let [file (vim.fn.expand "%:p")]
    (if (= file "")
        (vim.api.nvim_echo [["No file in the current buffer." "WarningMsg"]] false {})
        (let [lines (get-bookmark-lines-for-current-file)]
          (if (= (length lines) 0)
              (vim.api.nvim_echo
                [["No bookmarks in the current file." "WarningMsg"]] false {})
              (let [cur (vim.fn.line ".")]
                (var target nil)
                ;; Procura o primeiro bookmark com lnum > cur
                (each [_ l (ipairs lines)]
                  (when (and (not target) (> l cur))
                    (set target l)))
                ;; Se não achou, dá a volta para o primeiro
                (if target
                    (do
                      (vim.api.nvim_win_set_cursor 0 [target 0])
                      (vim.cmd "normal! zz"))
                    (do
                      (vim.api.nvim_win_set_cursor 0 [(. lines 1) 0])
                      (vim.cmd "normal! zz")))))))))

;; Vai para o bookmark anterior no arquivo atual (com wrap-around).
(fn navigate-to-previous-bookmark []
  (let [file (vim.fn.expand "%:p")]
    (if (= file "")
        (vim.api.nvim_echo [["No file in the current buffer." "WarningMsg"]] false {})
        (let [lines (get-bookmark-lines-for-current-file)]
          (if (= (length lines) 0)
              (vim.api.nvim_echo
                [["No bookmarks in the current file." "WarningMsg"]] false {})
              (let [cur (vim.fn.line ".")]
                (var target nil)
                ;; Percorre de trás para frente procurando o primeiro com lnum < cur
                (for [i (length lines) 1 -1]
                  (when (and (not target) (< (. lines i) cur))
                    (set target (. lines i))))
                ;; Se não achou, dá a volta para o último
                (if target
                    (do
                      (vim.api.nvim_win_set_cursor 0 [target 0])
                      (vim.cmd "normal! zz"))
                    (do
                      (vim.api.nvim_win_set_cursor 0 [(. lines (length lines)) 0])
                      (vim.cmd "normal! zz")))))))))

(fn get-file-list []
  (if (and (= (length files) 0) (= (length bookmarks) 0))
      (vim.api.nvim_echo [["No files or bookmarks in the list." "WarningMsg"]] false {})
      (let [items []]
        ;; Para cada arquivo, insere o cabeçalho e logo abaixo os seus bookmarks
        (each [_ file (ipairs files)]
          (table.insert items
            {:kind :file
             :filename file
             :text (vim.fn.fnamemodify file ":~")})
          (each [_ b (ipairs bookmarks)]
            (when (= b.file file)
              (table.insert items
                {:kind :bookmark
                 :filename file
                 :lnum b.lnum
                 :note b.note
                 :text (.. "  └─ " b.lnum ": " b.note)}))))
        ;; Bookmarks de arquivos que não estão em `files` (segurança) — no final
        (each [_ b (ipairs bookmarks)]
          (when (not (vim.tbl_contains files b.file))
            (table.insert items
              {:kind :bookmark
               :filename b.file
               :lnum b.lnum
               :note b.note
               :text (.. (vim.fn.fnamemodify b.file ":~") " └─ " b.lnum ": " b.note)})))
        (vim.ui.select items
          {:prompt "Select file or bookmark:"
           :format_item (fn [item] item.text)
           :kind "jumper"}
          (fn [choice]
            (when choice
              (if (= choice.kind :file)
                  (vim.cmd (.. "edit " (vim.fn.fnameescape choice.filename)))
                  (do
                    (vim.cmd (.. "edit " (vim.fn.fnameescape choice.filename)))
                    (vim.api.nvim_win_set_cursor 0 [choice.lnum 0])
                    (vim.cmd "normal! zz")))))))))

(fn get-file-list-quickfix []
  (local list [])
  (each [_ file (ipairs files)]
    (table.insert list {:filename file
                        :text (vim.fn.fnamemodify file ":~")}))
  (each [_ b (ipairs bookmarks)]
    (table.insert list {:filename b.file
                        :lnum b.lnum
                        :text (.. "  └─ " b.lnum ": " b.note)}))
  (vim.fn.setqflist list)
  (vim.cmd "bel copen 10"))

;; Remove o arquivo atual da lista (com confirmação)
(fn remove-current-file []
  (let [current-file (get-current-file-path)]
    (if (or (= current-file "") (not (vim.tbl_contains files current-file)))
        (vim.api.nvim_echo [["Current file is not in the list." "WarningMsg"]] false {})
        (let [confirm (vim.fn.confirm
                        (.. "Remove \"" (vim.fn.fnamemodify current-file ":~")
                            "\" (and its bookmarks) from the list?")
                        "&Yes\n&No" 2)]
          (when (= confirm 1)
            (var new-list [])
            (each [_ file (ipairs files)]
              (when (not= file current-file)
                (table.insert new-list file)))
            (clear-files-table)
            (each [_ file (ipairs new-list)]
              (table.insert files file))
            ;; Remove bookmarks do arquivo (memória e banco)
            (var new-bms [])
            (each [_ b (ipairs bookmarks)]
              (when (not= b.file current-file)
                (table.insert new-bms b)))
            (clear-bookmarks-table)
            (each [_ b (ipairs new-bms)]
              (table.insert bookmarks b))
            (persist-files)
            (remove-bookmarks-for-file current-dir current-file)
            (refresh-signs-current-buffer)
            (vim.api.nvim_echo
              [[(.. "Removed " (vim.fn.fnamemodify current-file ":~") " from the list.")]]
              false {}))))))

;; Limpa toda a lista (com confirmação)
(fn clear-file-list []
  (if (= (length files) 0)
      (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
      (let [confirm (vim.fn.confirm
                      (.. "Clear all " (length files) " file(s) and their bookmarks from the list?")
                      "&Yes\n&No" 2)]
        (when (= confirm 1)
          (clear-files-table)
          (clear-bookmarks-table)
          (persist-files)
          ;; Limpa bookmarks do diretório no banco
          (let [db (get-db (get-db-path-for-cwd))]
            (ensure-table db)
            (db:eval "delete from bookmarks where path = :path" {:path current-dir}))
          ;; Remove todos os signs de todos os buffers
          (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
            (when (vim.api.nvim_buf_is_loaded bufnr)
              (clear-signs-in-buffer bufnr)))
          (vim.api.nvim_echo [["File list cleared." "WarningMsg"]] false {})))))

(fn navigate-to-file [index]
  (let [len (length files)]
    (if (and index (>= index 1) (<= index len))
        (let [file (. files index)]
          (vim.cmd (.. "edit " (vim.fn.fnameescape file))))
        (vim.api.nvim_echo [[(.. "Invalid index: " (or index "nil") ". Valid range: 1-" len) "ErrorMsg"]] false {}))))

(fn get-current-file-index []
  (let [current-file (vim.fn.expand "%:p")
        len (length files)]
    (var found-index -1)
    (for [i 1 len]
      (when (= (. files i) current-file)
        (set found-index i)))
    found-index))

(fn get-file-dir [path]
  (vim.fn.fnamemodify path ":h"))

(fn navigate-to-next-file []
  (let [len (length files)]
    (if (= len 0)
        (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
        (let [current-index (get-current-file-index)]
          (if (< current-index 1)
              (navigate-to-file 1)
              (let [current-dir (get-file-dir (. files current-index))]
                (var next-index nil)
                (for [offset 1 len]
                  (when (not next-index)
                    (let [candidate-index (if (> (+ current-index offset) len)
                                               (- (+ current-index offset) len)
                                               (+ current-index offset))]
                      (when (= (get-file-dir (. files candidate-index)) current-dir)
                        (set next-index candidate-index)))))
                (if next-index
                    (navigate-to-file next-index)
                    (vim.api.nvim_echo
                      [["No other file from the same directory in the list." "WarningMsg"]]
                      false {}))))))))

(fn navigate-to-next-file-global []
  (let [len (length files)]
    (if (= len 0)
        (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
        (let [current-index (get-current-file-index)]
          (if (>= current-index 1)
              (let [next-index (if (= current-index len) 1 (+ current-index 1))]
                (navigate-to-file next-index))
              (navigate-to-file 1))))))

(fn navigate-to-previous-file []
  (let [len (length files)]
    (if (= len 0)
        (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
        (let [current-index (get-current-file-index)]
          (if (< current-index 1)
              (navigate-to-file len)
              (let [current-dir (get-file-dir (. files current-index))]
                (var prev-index nil)
                (for [offset 1 len]
                  (when (not prev-index)
                    (let [candidate-index (if (<= (- current-index offset) 0)
                                               (+ (- current-index offset) len)
                                               (- current-index offset))]
                      (when (= (get-file-dir (. files candidate-index)) current-dir)
                        (set prev-index candidate-index)))))
                (if prev-index
                    (navigate-to-file prev-index)
                    (vim.api.nvim_echo
                      [["No other file from the same directory in the list." "WarningMsg"]]
                      false {}))))))))

(fn navigate-to-previous-file-global []
  (let [len (length files)]
    (if (= len 0)
        (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
        (let [current-index (get-current-file-index)]
          (if (>= current-index 1)
              (let [prev-index (if (= current-index 1) len (- current-index 1))]
                (navigate-to-file prev-index))
              (navigate-to-file len))))))

;; ============================================================================
;; Autocmds: signs ao abrir buffers + reload ao mudar de diretório
;; ============================================================================

;; Ao carregar/abrir um buffer, aplica os signs dos bookmarks daquele arquivo.
(vim.api.nvim_create_autocmd "BufReadPost"
  {:callback (fn [args]
               (let [bufnr args.buf
                     file (vim.api.nvim_buf_get_name bufnr)]
                 (when (not= file "")
                   (refresh-signs-in-buffer bufnr file))))})

;; Ao fechar um buffer, remove os signs dele.
(vim.api.nvim_create_autocmd "BufWipeout"
  {:callback (fn [args]
               (clear-signs-in-buffer args.buf))})

(vim.api.nvim_create_autocmd "DirChanged"
  {:callback (fn []
               (reload-files)
               (vim.api.nvim_echo
                 [[(.. "Jumper: carregada lista para " (vim.fn.getcwd))]]
                 false {}))})

;; ============================================================================
;; Comandos
;; ============================================================================

(vim.api.nvim_create_user_command "JumperAdd" add-current-file {})
(vim.api.nvim_create_user_command "JumperAddBookmark" add-bookmark {})
(vim.api.nvim_create_user_command "JumperRemoveBookmark" remove-current-bookmark {})
(vim.api.nvim_create_user_command "JumperNextBookmark" navigate-to-next-bookmark {})
(vim.api.nvim_create_user_command "JumperPreviousBookmark" navigate-to-previous-bookmark {})
(vim.api.nvim_create_user_command "JumperList" get-file-list {})
(vim.api.nvim_create_user_command "JumperListQF" get-file-list-quickfix {})
(vim.api.nvim_create_user_command "JumperClear" clear-file-list {})
(vim.api.nvim_create_user_command "JumperRemove" remove-current-file {})
(vim.api.nvim_create_user_command "JumperNext" navigate-to-next-file {})
(vim.api.nvim_create_user_command "JumperNextGlobal" navigate-to-next-file-global {})
(vim.api.nvim_create_user_command "JumperPrevious" navigate-to-previous-file {})
(vim.api.nvim_create_user_command "JumperPreviousGlobal" navigate-to-previous-file-global {})

(fn M.setup []
  (set vim.g.loaded_jumper 1))

M
