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

;; Garante que a tabela `files` existe no banco (usando SQL direto com IF NOT EXISTS)
(fn ensure-table [db]
  (db:eval "CREATE TABLE IF NOT EXISTS files (
    file text not null,
    path text not null
  )"))

;; Retorna a lista de arquivos persistida para um diretório.
(fn load-files-for-dir [dir]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (let [rows (db:eval "select file from files where path = :path order by rowid" {:path dir})]
      (if (= (type rows) :table)
          (icollect [_ row (ipairs rows)] row.file)
          []))))

;; Substitui a lista de arquivos persistida para um diretório.
(fn save-files-for-dir [dir file-list]
  (let [db (get-db (get-db-path-for-cwd))]
    (ensure-table db)
    (db:eval "delete from files where path = :path" {:path dir})
    (each [_ file (ipairs file-list)]
      (db:eval "insert into files (path, file) values (:path, :file)"
               {:path dir :file file}))))

;; ============================================================================
;; Estado em memória (cache) — mantido em sincronia com o banco
;; ============================================================================

(local files [])

(var current-dir (vim.fn.getcwd))

;; Limpa a tabela `files` em memória (sem reatribuir o binding)
(fn clear-files-table []
  (while (> (length files) 0)
    (table.remove files)))

;; Carrega a lista persistida do diretório atual para `files`.
(fn reload-files []
  (let [dir (vim.fn.getcwd)
        persisted (load-files-for-dir dir)]
    (set current-dir dir)
    (clear-files-table)
    (each [_ f (ipairs persisted)]
      (table.insert files f))
    (set vim.g.file_list files)))

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

(fn get-file-list []
  (if (= (length files) 0)
      (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
      (let [items []]
        (each [i file (ipairs files)]
          (table.insert items {:index i :filename file :text file}))
        (vim.ui.select items
          {:prompt "Select file to open:"
           :format_item (fn [item]
                          (.. item.index ": " (vim.fn.fnamemodify item.filename ":~")))
           :kind "file"}
          (fn [choice]
            (when choice
              (vim.cmd (.. "edit " choice.filename))))))))

(fn get-file-list-quickfix []
  (local list [])
  (each [i file (ipairs files)]
    (local dic {:filename file :text (.. i ": " (vim.fn.fnamemodify file ":~"))})
    (table.insert list dic))
  (vim.fn.setqflist list)
  (vim.cmd "bel copen 10"))

;; Remove o arquivo atual da lista (com confirmação)
(fn remove-current-file []
  (let [current-file (get-current-file-path)]
    (if (or (= current-file "") (not (vim.tbl_contains files current-file)))
        (vim.api.nvim_echo [["Current file is not in the list." "WarningMsg"]] false {})
        (let [confirm (vim.fn.confirm
                        (.. "Remove \"" (vim.fn.fnamemodify current-file ":~")
                            "\" from the list?")
                        "&Yes\n&No" 2)]
          (when (= confirm 1)
            (var new-list [])
            (each [_ file (ipairs files)]
              (when (not= file current-file)
                (table.insert new-list file)))
            (clear-files-table)
            (each [_ file (ipairs new-list)]
              (table.insert files file))
            (persist-files)
            (vim.api.nvim_echo
              [[(.. "Removed " (vim.fn.fnamemodify current-file ":~") " from the list.")]]
              false {}))))))

;; Limpa toda a lista (com confirmação)
(fn clear-file-list []
  (if (= (length files) 0)
      (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
      (let [confirm (vim.fn.confirm
                      (.. "Clear all " (length files) " file(s) from the list?")
                      "&Yes\n&No" 2)]
        (when (= confirm 1)
          (clear-files-table)
          (persist-files)
          (vim.api.nvim_echo [["File list cleared." "WarningMsg"]] false {})))))

(fn navigate-to-file [index]
  (let [len (length files)]
    (if (and index (>= index 1) (<= index len))
        (let [file (. files index)]
          (vim.cmd (.. "edit " file)))
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
          (if (>= current-index 1)
              (let [prev-index (if (= current-index 1) len (- current-index 1))]
                (navigate-to-file prev-index))
              (navigate-to-file len))))))

;; ============================================================================
;; Auto-reload quando o diretório de trabalho muda
;; ============================================================================

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
(vim.api.nvim_create_user_command "JumperList" get-file-list {})
(vim.api.nvim_create_user_command "JumperListQF" get-file-list-quickfix {})
(vim.api.nvim_create_user_command "JumperClear" clear-file-list {})
(vim.api.nvim_create_user_command "JumperRemove" remove-current-file {})
(vim.api.nvim_create_user_command "JumperNext" navigate-to-next-file {})
(vim.api.nvim_create_user_command "JumperNextGlobal" navigate-to-next-file-global {})
(vim.api.nvim_create_user_command "JumperPrevious" navigate-to-previous-file {})

(fn M.setup []
  (set vim.g.loaded_jumper 1))

M
