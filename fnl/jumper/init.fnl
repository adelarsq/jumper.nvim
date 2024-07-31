
(when vim.g.loaded_jumper (lua "return "))

(local M {})

;; Inicializa a lista de arquivos
(local files (or vim.g.file_list {}))

;; Função para adicionar o arquivo atual à lista
(fn add-current-file []
  (local current-file (vim.fn.expand "%:p"))
  (when (not (vim.tbl_contains files current-file))
    (table.insert files current-file)
    (vim.api.nvim_echo [[(.. "Added " current-file " to the list.")]] false {})
    (set vim.g.file_list files)))

;; Função para obter a lista atual de arquivos
(fn get-file-list []
  (vim.api.nvim_echo [["Current file list:" "None"]] false {})
  (local list {})
  (each [i file (ipairs files)]
    (vim.api.nvim_echo [[(.. i ": " file) "None"]] false {})
    (local dic {:filename file :text ""})
    (table.insert list dic))
  (vim.fn.setqflist list)
  (vim.cmd "bel copen 10"))

;; Função para navegar até um arquivo na lista pelo índice
(fn navigate-to-file [index]
  (local file (nth files index))
  (if file
      (vim.cmd (.. "edit " file))
      (vim.api.nvim_echo [[(.. "Invalid index: " index) "ErrorMsg"]] false {})))

;; Comando para adicionar o arquivo atual
(vim.api.nvim_create_user_command "JumperAdd" add-current-file {})

;; Comando para listar os arquivos
(vim.api.nvim_create_user_command "JumperList" get-file-list {})

;; Comando para navegar até um arquivo pelo índice
(vim.api.nvim_create_user_command "JumperJump" (fn [opts]
  (navigate-to-file (tonumber (vim.fn.input "Enter file index: "))))
  {})

(fn M.setup []
  (set vim.g.loaded_jumper 1))

M
