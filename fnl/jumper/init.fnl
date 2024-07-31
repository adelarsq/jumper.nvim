; ()(when vim.g.loaded_neovcs (lua "return "))
;
; (local M {})

;; Inicializa a lista de arquivos
(local files (or vim.g.file_list {}))

;; Função para adicionar o arquivo atual à lista
(fn add-current-file []
  (local current-file (vim.fn.expand "%:p"))
  (when (not (vim.tbl_contains files current-file))
    (table.insert files current-file)
    ; (vim.api.nvim_echo {{"Added " .. current-file .. " to the list."}})
    (set vim.g.file_list files)))

;; Função para obter a lista atual de arquivos
(fn get-file-list []
  ; (vim.api.nvim_echo {{"Current file list:", "None"}} false {})
  (each [i file (ipairs files)]
    ; (vim.api.nvim_echo {{(i .. ": " .. file), "None"}} false {})))

    (vim.api.nvim_echo "Test" false {})))

;; Função para navegar até um arquivo na lista pelo índice
(fn navigate-to-file [index]
  (local file (nth files index))
  (if file
      (vim.cmd (.. "edit " file))))
      ; (vim.api.nvim_echo {{"Invalid index: " .. index, "ErrorMsg"}} false {})))

;; Comando para adicionar o arquivo atual
(vim.api.nvim_create_user_command "AddCurrentFile" add-current-file {})

;; Comando para listar os arquivos
(vim.api.nvim_create_user_command "GetFileList" get-file-list {})

;; Comando para navegar até um arquivo pelo índice
(vim.api.nvim_create_user_command "NavigateToFile" (fn [opts]
  (navigate-to-file (tonumber (vim.fn.input "Enter file index: "))))
  {})

; M)
